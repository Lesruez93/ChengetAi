"""Generate a synthetic mobile-money agent transaction log with injected anomalies.

Produces sample_data/transactions_sample.csv: a day-in-the-life of mobile money
agent tills across every market in `backend/app/services/countries.py`, with
normal cash-in/cash-out/transfer activity plus a small number of deliberately
injected anomalous patterns (rapid reversals, structuring just under reporting
thresholds, unusual hours, outlier amounts) used to demo and test the Sentinel
anomaly detector. Entirely synthetic.

WHY THE FIXTURE IS MULTI-COUNTRY
--------------------------------
A single-market fixture let two single-country assumptions hide in the demo:

1. Numbers were emitted in local `07XXXXXXXX` form, which is ambiguous across
   Zimbabwe, Uganda and Tanzania — the exact collision the rest of the product
   canonicalises away (see `normalize_msisdn` in
   `backend/app/services/reputation.py`). Customer numbers here are E.164,
   built from each country's dial code, mobile prefixes and NSN length.

2. Amounts were implicitly USD, so the structuring burst only looked like
   structuring in a USD market. Amounts are scaled per country against that
   market's structuring threshold, so the injected bursts land inside the
   detector's just-under-threshold window whatever the currency.

Like `generate_scam_corpus.py`, per-market detail is derived from the country
registry rather than hardcoded — here by importing the registry itself (which
is dependency-free, so this script still runs on a bare checkout), so a
regenerated fixture cannot drift from the figures the detector judges amounts
against.

Usage:
    python generate_transactions.py [--out transactions_sample.csv] [--seed 7]
"""

from __future__ import annotations

import argparse
import csv
import random
import sys
from datetime import datetime, timedelta
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1] / "backend"
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

try:
    from app.services.countries import Country, all_countries, large_amount_for
except ImportError as exc:  # pragma: no cover - developer environment guard
    raise SystemExit(
        f"Could not import the backend country registry ({exc}); expected it at "
        f"{BACKEND_ROOT}. The registry is dependency-free, so this generator needs "
        "nothing installed — only the repo checked out intact."
    ) from exc

TX_TYPES = ["cash_in", "cash_out", "transfer", "airtime", "bill_pay"]

# Amount ranges as a multiple of the market's large-amount figure
# (`LARGE_AMOUNT_BY_CURRENCY`), so a row means the same thing in every currency.
# Against Zimbabwe's USD 500 these reproduce the ranges this generator used when
# it was USD-only: normal 5-250, structuring 490-499, reversal 800-1500,
# unusual-hour 1200-3000.
NORMAL_AMOUNT_RATIO = (0.01, 0.5)
# Must stay inside the detector's just-under window — see STRUCTURING_MARGIN_RATIO
# in backend/app/services/sentinel.py, currently the top 4% below the figure.
STRUCTURING_AMOUNT_RATIO = (0.98, 0.998)
REVERSAL_AMOUNT_RATIO = (1.6, 3.0)
UNUSUAL_HOUR_AMOUNT_RATIO = (2.4, 6.0)

STRUCTURING_BURST_SIZE = 5
UNUSUAL_HOURS_PER_COUNTRY = 2


def agents_for(country: Country) -> list[str]:
    return [f"AGT-{country.code}-{n:02d}" for n in range(1, 4)]


def rand_msisdn(country: Country) -> str:
    """A syntactically valid E.164 customer number for this market."""
    prefix = random.choice(country.mobile_prefixes)
    rest = "".join(str(random.randint(0, 9)) for _ in range(country.nsn_length - len(prefix)))
    return f"+{country.dial_code}{prefix}{rest}"


def rand_amount(threshold: float, ratio: tuple[float, float]) -> float:
    """An amount in the market's own currency, quantised to a sane unit.

    Rounds *down* so a structuring amount drawn just under the threshold cannot
    be rounded onto or over it. High-denomination currencies lose the cents and
    then some — nobody cashes out 1,996,431.27 UGX.
    """
    raw = random.uniform(*ratio) * threshold
    if threshold >= 100_000:
        return float(int(raw // 100) * 100)
    if threshold >= 10_000:
        return float(int(raw // 10) * 10)
    return float(int(raw * 100) / 100)


def _row(idx: int, country: Country, ts: datetime, **fields) -> dict:
    return {
        "transaction_id": f"TX{idx:05d}",
        "timestamp": ts.isoformat(),
        "country": country.code,
        "is_reversal": False,
        **fields,
    }


def normal_transaction(country: Country, threshold: float, base_time: datetime, idx: int) -> dict:
    hour = random.randint(7, 19)  # normal agent trading hours
    ts = base_time.replace(hour=hour, minute=random.randint(0, 59))
    return _row(
        idx, country, ts,
        agent_id=random.choice(agents_for(country)),
        customer_msisdn=rand_msisdn(country),
        type=random.choice(TX_TYPES),
        amount=rand_amount(threshold, NORMAL_AMOUNT_RATIO),
        label="normal",
    )


def structuring_burst(country: Country, threshold: float, base_time: datetime, start_idx: int) -> list[dict]:
    """Several just-under-threshold transfers from the same customer in quick succession."""
    customer = rand_msisdn(country)
    agent = random.choice(agents_for(country))
    ts = base_time.replace(hour=random.randint(9, 16), minute=random.randint(0, 30))
    return [
        _row(
            start_idx + i, country, ts + timedelta(minutes=3 * i),
            agent_id=agent,
            customer_msisdn=customer,
            type="cash_out",
            amount=rand_amount(threshold, STRUCTURING_AMOUNT_RATIO),
            label="anomaly_structuring",
        )
        for i in range(STRUCTURING_BURST_SIZE)
    ]


def rapid_reversal(country: Country, threshold: float, base_time: datetime, start_idx: int) -> list[dict]:
    """A large cash-out immediately reversed then re-drawn, a common agent-fraud pattern."""
    customer = rand_msisdn(country)
    agent = random.choice(agents_for(country))
    ts = base_time.replace(hour=random.randint(9, 16), minute=random.randint(0, 30))
    amount = rand_amount(threshold, REVERSAL_AMOUNT_RATIO)
    common = {
        "agent_id": agent,
        "customer_msisdn": customer,
        "type": "cash_out",
        "label": "anomaly_rapid_reversal",
    }
    return [
        _row(start_idx, country, ts, amount=amount, **common),
        _row(start_idx + 1, country, ts + timedelta(minutes=2), amount=-amount,
             **{**common, "is_reversal": True}),
        _row(start_idx + 2, country, ts + timedelta(minutes=4), amount=amount, **common),
    ]


def unusual_hour_outlier(country: Country, threshold: float, base_time: datetime, idx: int) -> dict:
    """A very large transaction at 2-4am, outside normal trading hours."""
    ts = base_time.replace(hour=random.randint(1, 4), minute=random.randint(0, 59))
    return _row(
        idx, country, ts,
        agent_id=random.choice(agents_for(country)),
        customer_msisdn=rand_msisdn(country),
        type="cash_out",
        amount=rand_amount(threshold, UNUSUAL_HOUR_AMOUNT_RATIO),
        label="anomaly_unusual_hour",
    )


def build_rows(n_normal: int, base_time: datetime) -> list[dict]:
    rows: list[dict] = []
    idx = 1
    for country in all_countries():
        threshold = large_amount_for(country.code)
        for _ in range(n_normal):
            rows.append(normal_transaction(country, threshold, base_time, idx))
            idx += 1

        rows.extend(structuring_burst(country, threshold, base_time, idx))
        idx += STRUCTURING_BURST_SIZE
        rows.extend(rapid_reversal(country, threshold, base_time, idx))
        idx += 3
        for _ in range(UNUSUAL_HOURS_PER_COUNTRY):
            rows.append(unusual_hour_outlier(country, threshold, base_time, idx))
            idx += 1

    rows.sort(key=lambda r: (r["timestamp"], r["transaction_id"]))
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(Path(__file__).parent / "transactions_sample.csv"))
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--n-normal", type=int, default=40,
                        help="normal transactions per country (default: 40)")
    args = parser.parse_args()

    random.seed(args.seed)
    rows = build_rows(args.n_normal, base_time=datetime(2026, 7, 1))

    fieldnames = ["transaction_id", "timestamp", "country", "agent_id", "customer_msisdn",
                  "type", "amount", "is_reversal", "label"]
    with open(args.out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    n_anomaly = sum(1 for r in rows if r["label"] != "normal")
    n_markets = len({r["country"] for r in rows})
    print(f"Wrote {len(rows)} transactions to {args.out} "
          f"({n_anomaly} injected anomalies across {n_markets} markets)")


if __name__ == "__main__":
    main()
