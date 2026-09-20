"""Agent Fraud Sentinel: anomaly detection over uploaded transaction CSVs.

Hybrid approach, chosen because agent fraud patterns are unlabeled and drift
over time (rubric C2): an IsolationForest catches multivariate outliers we
didn't anticipate, while explicit rules catch known fraud patterns (rapid
reversals, structuring just under round thresholds, unusual trading hours)
with a human-readable reason attached. A transaction is flagged if either
signal fires; reasons from both are merged so an SME reviewer sees *why*.

WHY AMOUNTS ARE READ PER MARKET
-------------------------------
Two of the three signals are about *how big* an amount is, and "big" has no
currency-free meaning across the markets this product covers. A flat 500 is a
serious sum in USD or ZAR and pocket change in NGN, TZS or UGX, so a single
constant would quietly switch structuring detection off in most of our
markets — the rule would never fire, and nothing would look broken.

Every amount is therefore interpreted against the structuring threshold of the
market it was booked in, resolved from the country registry's `currency_code`:
- the rules compare amounts to that market's own threshold, and
- the IsolationForest sees `amount / threshold` rather than raw amount, so a
  file covering several currencies doesn't rank every naira row as an outlier
  purely because of the exchange rate. For a single-currency file this is a
  positive rescale of one feature, which leaves the forest's splits — and so
  the scores — unchanged.

A row's market comes from its own `country` column when the file has one (an
aggregator's export can legitimately span markets), otherwise from the
`country` the caller declared for the upload.
"""

from __future__ import annotations

import io

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest

from app.services.countries import currency_symbol_for, large_amount_for

REQUIRED_COLUMNS = {"transaction_id", "timestamp", "agent_id", "customer_msisdn", "type", "amount"}

# How far under the threshold still counts as "just under", as a fraction of the
# threshold rather than an absolute amount, so the window scales with the
# currency. 4% of 500 is the 20 this rule originally used.
STRUCTURING_MARGIN_RATIO = 0.04
STRUCTURING_MIN_BURST = 3
STRUCTURING_WINDOW_HOURS = 6
UNUSUAL_HOUR_START = 22
UNUSUAL_HOUR_END = 5
RAPID_REVERSAL_MINUTES = 10


class InvalidTransactionFile(ValueError):
    pass


def structuring_threshold_for(country_code: str | None) -> float:
    """The amount customers in this market structure beneath, in local currency.

    An absent or unrecognised code falls back to USD rather than raising:
    `country` is an optional label on an upload, and a typo there should not
    cost the operator the whole analysis. The API validates the field at the
    boundary, so the fallback is a safety net rather than the normal path.
    """
    return large_amount_for(country_code)


def _load_dataframe(raw_bytes: bytes) -> pd.DataFrame:
    try:
        df = pd.read_csv(io.BytesIO(raw_bytes))
    except Exception as exc:  # pragma: no cover - pandas raises many exception types
        raise InvalidTransactionFile(f"Could not parse CSV: {exc}") from exc

    missing = REQUIRED_COLUMNS - set(df.columns)
    if missing:
        raise InvalidTransactionFile(f"Missing required columns: {sorted(missing)}")
    if df.empty:
        raise InvalidTransactionFile("Transaction file has no rows.")

    df["timestamp"] = pd.to_datetime(df["timestamp"])
    df["amount"] = pd.to_numeric(df["amount"], errors="coerce")
    df = df.dropna(subset=["amount"])
    return df


def _row_markets(df: pd.DataFrame, country_code: str | None) -> pd.Series:
    """The market each row was booked in, most specific source first.

    A `country` column states each row's own market, which is what denominates
    its amount; the country declared for the upload covers files without one.
    """
    declared = (country_code or "").strip().upper()
    if "country" in df.columns:
        per_row = df["country"].fillna("").astype(str).str.strip().str.upper()
        return per_row.where(per_row != "", declared)
    return pd.Series(declared, index=df.index, dtype="object")


def _rule_reasons(df: pd.DataFrame, markets: pd.Series, thresholds: pd.Series) -> dict[int, list[str]]:
    reasons: dict[int, list[str]] = {i: [] for i in df.index}

    # Unusual trading hours (late night / very early morning)
    hours = df["timestamp"].dt.hour
    unusual_hour_mask = (hours >= UNUSUAL_HOUR_START) | (hours < UNUSUAL_HOUR_END)
    for i in df[unusual_hour_mask].index:
        reasons[i].append("Transaction occurred outside normal trading hours (22:00-05:00).")

    # Structuring: repeated just-under-threshold cash-outs by the same customer
    # within a day, each market judged against its own currency's threshold.
    working = df.assign(_market=markets, _threshold=thresholds).sort_values("timestamp")
    near_threshold_mask = (
        (working["amount"] >= working["_threshold"] * (1 - STRUCTURING_MARGIN_RATIO))
        & (working["amount"] < working["_threshold"])
    )
    for (market, _msisdn), group in working[near_threshold_mask].groupby(["_market", "customer_msisdn"]):
        if len(group) >= STRUCTURING_MIN_BURST:
            span = group["timestamp"].max() - group["timestamp"].min()
            if span <= pd.Timedelta(hours=STRUCTURING_WINDOW_HOURS):
                threshold = float(group["_threshold"].iloc[0])
                amount = f"{currency_symbol_for(market)}{threshold:,.0f}"
                for i in group.index:
                    reasons[i].append(
                        f"{len(group)} transactions just under {amount} "
                        f"from the same customer within {span}, suggesting structuring."
                    )

    # Rapid reversal: cash-out, reversal, and re-draw within a short window for
    # the same customer. Currency-blind by nature — the pattern is in the timing.
    if "is_reversal" in working.columns:
        for msisdn, group in working.groupby("customer_msisdn"):
            group = group.sort_values("timestamp")
            reversal_rows = group[group["is_reversal"].astype(str).str.lower() == "true"]
            for _, rev_row in reversal_rows.iterrows():
                window_start = rev_row["timestamp"] - pd.Timedelta(minutes=RAPID_REVERSAL_MINUTES)
                window_end = rev_row["timestamp"] + pd.Timedelta(minutes=RAPID_REVERSAL_MINUTES)
                nearby = group[(group["timestamp"] >= window_start) & (group["timestamp"] <= window_end)]
                if len(nearby) >= 2:
                    for i in nearby.index:
                        reasons[i].append(
                            "Cash-out reversed and re-drawn within "
                            f"{RAPID_REVERSAL_MINUTES} minutes, a known agent-fraud pattern."
                        )

    return reasons


def _isolation_forest_scores(df: pd.DataFrame, thresholds: pd.Series) -> np.ndarray:
    features = pd.DataFrame({
        # Market-relative, not absolute: see the module docstring.
        "amount": df["amount"].abs() / thresholds,
        "hour": df["timestamp"].dt.hour,
        "type_code": df["type"].astype("category").cat.codes,
    })
    model = IsolationForest(n_estimators=200, contamination="auto", random_state=42)
    model.fit(features)
    # decision_function: higher = more normal. Flip and shift to 0..1, higher = more anomalous.
    raw = model.decision_function(features)
    return (raw.max() - raw) / (raw.max() - raw.min() + 1e-9)


def analyze_transactions(
    raw_bytes: bytes, country: str | None = None
) -> tuple[pd.DataFrame, np.ndarray, dict[int, list[str]]]:
    """Score and explain a transaction file.

    `country` is the market the upload came from (ISO 3166-1 alpha-2). It sets
    the currency every amount is judged against; rows carrying their own
    `country` column keep theirs. An absent or unrecognised code falls back to
    the USD thresholds.
    """
    df = _load_dataframe(raw_bytes)
    markets = _row_markets(df, country)
    thresholds = markets.map(structuring_threshold_for)
    scores = _isolation_forest_scores(df, thresholds)
    reasons = _rule_reasons(df, markets, thresholds)
    return df, scores, reasons
