from pathlib import Path

import pytest

from app.services.sentinel import InvalidTransactionFile, analyze_transactions

SAMPLE_CSV = Path(__file__).resolve().parents[2] / "sample_data" / "transactions_sample.csv"


def test_analyze_transactions_flags_injected_anomalies():
    raw = SAMPLE_CSV.read_bytes()
    df, scores, reasons = analyze_transactions(raw)

    assert len(df) == len(scores)
    flagged_indices = {i for i, r in reasons.items() if r}
    flagged_labels = set(df.loc[list(flagged_indices), "label"]) if "label" in df.columns else set()

    # every rule-based anomaly category we injected should produce at least one flagged row
    assert any("structuring" in lbl for lbl in flagged_labels)
    assert any("unusual_hour" in lbl for lbl in flagged_labels)


def test_analyze_transactions_rejects_missing_columns():
    bad_csv = b"a,b,c\n1,2,3\n"
    with pytest.raises(InvalidTransactionFile):
        analyze_transactions(bad_csv)


def test_analyze_transactions_rejects_empty_file():
    csv_with_header_only = b"transaction_id,timestamp,agent_id,customer_msisdn,type,amount\n"
    with pytest.raises(InvalidTransactionFile):
        analyze_transactions(csv_with_header_only)
