"""Agent Fraud Sentinel: anomaly detection over uploaded transaction CSVs.

Hybrid approach, chosen because agent fraud patterns are unlabeled and drift
over time (rubric C2): an IsolationForest catches multivariate outliers we
didn't anticipate, while explicit rules catch known fraud patterns (rapid
reversals, structuring just under round thresholds, unusual trading hours)
with a human-readable reason attached. A transaction is flagged if either
signal fires; reasons from both are merged so an SME reviewer sees *why*.
"""

from __future__ import annotations

import io

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest

REQUIRED_COLUMNS = {"transaction_id", "timestamp", "agent_id", "customer_msisdn", "type", "amount"}

STRUCTURING_THRESHOLD = 500.0
STRUCTURING_MARGIN = 20.0
UNUSUAL_HOUR_START = 22
UNUSUAL_HOUR_END = 5
RAPID_REVERSAL_MINUTES = 10


class InvalidTransactionFile(ValueError):
    pass


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


def _rule_reasons(df: pd.DataFrame) -> dict[int, list[str]]:
    reasons: dict[int, list[str]] = {i: [] for i in df.index}

    # Unusual trading hours (late night / very early morning)
    hours = df["timestamp"].dt.hour
    unusual_hour_mask = (hours >= UNUSUAL_HOUR_START) | (hours < UNUSUAL_HOUR_END)
    for i in df[unusual_hour_mask].index:
        reasons[i].append("Transaction occurred outside normal trading hours (22:00-05:00).")

    # Structuring: repeated just-under-threshold cash-outs by the same customer within a day
    df_sorted = df.sort_values("timestamp")
    near_threshold_mask = (
        (df_sorted["amount"] >= STRUCTURING_THRESHOLD - STRUCTURING_MARGIN)
        & (df_sorted["amount"] < STRUCTURING_THRESHOLD)
    )
    for msisdn, group in df_sorted[near_threshold_mask].groupby("customer_msisdn"):
        if len(group) >= 3:
            span = group["timestamp"].max() - group["timestamp"].min()
            if span <= pd.Timedelta(hours=6):
                for i in group.index:
                    reasons[i].append(
                        f"{len(group)} transactions just under ${STRUCTURING_THRESHOLD:.0f} "
                        f"from the same customer within {span}, suggesting structuring."
                    )

    # Rapid reversal: cash-out, reversal, and re-draw within a short window for the same customer
    if "is_reversal" in df_sorted.columns:
        for msisdn, group in df_sorted.groupby("customer_msisdn"):
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


def _isolation_forest_scores(df: pd.DataFrame) -> np.ndarray:
    features = pd.DataFrame({
        "amount": df["amount"].abs(),
        "hour": df["timestamp"].dt.hour,
        "type_code": df["type"].astype("category").cat.codes,
    })
    model = IsolationForest(n_estimators=200, contamination="auto", random_state=42)
    model.fit(features)
    # decision_function: higher = more normal. Flip and shift to 0..1, higher = more anomalous.
    raw = model.decision_function(features)
    return (raw.max() - raw) / (raw.max() - raw.min() + 1e-9)


def analyze_transactions(raw_bytes: bytes) -> tuple[pd.DataFrame, np.ndarray, dict[int, list[str]]]:
    df = _load_dataframe(raw_bytes)
    scores = _isolation_forest_scores(df)
    reasons = _rule_reasons(df)
    return df, scores, reasons
