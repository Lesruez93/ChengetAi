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


def _structuring_reasons(raw: bytes, currency_symbol: str = "") -> list[str]:
    _, _, reasons = analyze_transactions(raw, currency_symbol)
    return [r for rs in reasons.values() for r in rs if "structuring" in r]


def test_structuring_reason_uses_the_markets_currency_symbol():
    """The threshold in the reason text is money, so it must carry the market's
    symbol rather than the "$" that was hardcoded when this was USD-only."""
    matched = _structuring_reasons(SAMPLE_CSV.read_bytes(), "₦")

    assert matched, "sample file should contain at least one structuring flag"
    assert all("₦500" in r for r in matched)
    assert not any("$" in r for r in matched)


def test_structuring_reason_omits_a_symbol_when_the_market_is_unknown():
    """No country means no currency claim: the threshold renders bare instead of
    being attributed to a currency the caller never supplied."""
    matched = _structuring_reasons(SAMPLE_CSV.read_bytes())

    assert matched
    assert all("500" in r and "$" not in r for r in matched)
