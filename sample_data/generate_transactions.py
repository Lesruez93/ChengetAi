"""Generate a synthetic mobile-money agent transaction log with injected anomalies.

Produces sample_data/transactions_sample.csv: a day-in-the-life of a mobile
money agent's till, with normal cash-in/cash-out/transfer activity plus a
small number of deliberately injected anomalous patterns (rapid reversals,
structuring just under reporting thresholds, unusual hours, outlier amounts)
used to demo and test the Sentinel anomaly detector. Entirely synthetic.

Usage:
    python generate_transactions.py [--out transactions_sample.csv] [--seed 7]
"""

from __future__ import annotations

import argparse
import csv
import random
from datetime import datetime, timedelta
from pathlib import Path

TX_TYPES = ["cash_in", "cash_out", "transfer", "airtime", "bill_pay"]
AGENTS = ["AGT-2201", "AGT-2202", "AGT-2203"]


def rand_msisdn() -> str:
    return f"07{random.randint(1,8)}{random.randint(1000000,9999999)}"


def normal_transaction(base_time: datetime, idx: int) -> dict:
    hour = random.randint(7, 19)  # normal agent trading hours
    ts = base_time.replace(hour=hour, minute=random.randint(0, 59))
    return {
        "transaction_id": f"TX{idx:05d}",
        "timestamp": ts.isoformat(),
        "agent_id": random.choice(AGENTS),
        "customer_msisdn": rand_msisdn(),
        "type": random.choice(TX_TYPES),
        "amount": round(random.uniform(5, 250), 2),
        "is_reversal": False,
        "label": "normal",
    }


def structuring_burst(base_time: datetime, start_idx: int) -> list[dict]:
    """Several just-under-threshold transfers from the same customer in quick succession."""
    customer = rand_msisdn()
    agent = random.choice(AGENTS)
    rows = []
    ts = base_time.replace(hour=random.randint(9, 16), minute=random.randint(0, 30))
    for i in range(5):
        rows.append({
            "transaction_id": f"TX{start_idx + i:05d}",
            "timestamp": (ts + timedelta(minutes=3 * i)).isoformat(),
            "agent_id": agent,
            "customer_msisdn": customer,
            "type": "cash_out",
            "amount": round(random.uniform(490, 499), 2),
            "is_reversal": False,
            "label": "anomaly_structuring",
        })
    return rows


def rapid_reversal(base_time: datetime, start_idx: int) -> list[dict]:
    """A large cash-out immediately reversed then re-drawn, a common agent-fraud pattern."""
    customer = rand_msisdn()
    agent = random.choice(AGENTS)
    ts = base_time.replace(hour=random.randint(9, 16), minute=random.randint(0, 30))
    amount = round(random.uniform(800, 1500), 2)
    return [
        {"transaction_id": f"TX{start_idx:05d}", "timestamp": ts.isoformat(), "agent_id": agent,
         "customer_msisdn": customer, "type": "cash_out", "amount": amount, "is_reversal": False,
         "label": "anomaly_rapid_reversal"},
        {"transaction_id": f"TX{start_idx + 1:05d}", "timestamp": (ts + timedelta(minutes=2)).isoformat(),
         "agent_id": agent, "customer_msisdn": customer, "type": "cash_out", "amount": -amount,
         "is_reversal": True, "label": "anomaly_rapid_reversal"},
        {"transaction_id": f"TX{start_idx + 2:05d}", "timestamp": (ts + timedelta(minutes=4)).isoformat(),
         "agent_id": agent, "customer_msisdn": customer, "type": "cash_out", "amount": amount,
         "is_reversal": False, "label": "anomaly_rapid_reversal"},
    ]


def unusual_hour_outlier(base_time: datetime, idx: int) -> dict:
    """A very large transaction at 2-4am, outside normal trading hours."""
    ts = base_time.replace(hour=random.randint(1, 4), minute=random.randint(0, 59))
    return {
        "transaction_id": f"TX{idx:05d}",
        "timestamp": ts.isoformat(),
        "agent_id": random.choice(AGENTS),
        "customer_msisdn": rand_msisdn(),
        "type": "cash_out",
        "amount": round(random.uniform(1200, 3000), 2),
        "is_reversal": False,
        "label": "anomaly_unusual_hour",
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default=str(Path(__file__).parent / "transactions_sample.csv"))
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--n-normal", type=int, default=180)
    args = parser.parse_args()

    random.seed(args.seed)
    base_time = datetime(2026, 7, 1)

    rows: list[dict] = []
    idx = 1
    for _ in range(args.n_normal):
        rows.append(normal_transaction(base_time, idx))
        idx += 1

    rows.extend(structuring_burst(base_time, idx)); idx += 5
    rows.extend(structuring_burst(base_time, idx)); idx += 5
    rows.extend(rapid_reversal(base_time, idx)); idx += 3
    rows.extend(rapid_reversal(base_time, idx)); idx += 3
    for _ in range(4):
        rows.append(unusual_hour_outlier(base_time, idx))
        idx += 1

    rows.sort(key=lambda r: r["timestamp"])

    fieldnames = ["transaction_id", "timestamp", "agent_id", "customer_msisdn", "type", "amount", "is_reversal", "label"]
    with open(args.out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    n_anomaly = sum(1 for r in rows if r["label"] != "normal")
    print(f"Wrote {len(rows)} transactions to {args.out} ({n_anomaly} injected anomalies)")


if __name__ == "__main__":
    main()
