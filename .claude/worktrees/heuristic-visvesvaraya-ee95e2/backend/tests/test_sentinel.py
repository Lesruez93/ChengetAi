import csv
import io
import sys
from pathlib import Path

import pytest

from app.services.countries import (
    LARGE_AMOUNT_BY_CURRENCY,
    SUPPORTED_COUNTRY_CODES,
    get_country,
)
from app.services.reputation import normalize_msisdn
from app.services.sentinel import (
    STRUCTURING_MARGIN_RATIO,
    InvalidTransactionFile,
    analyze_transactions,
    structuring_threshold_for,
)

SAMPLE_CSV = Path(__file__).resolve().parents[2] / "sample_data" / "transactions_sample.csv"


def _as_csv(rows: list[dict]) -> bytes:
    buffer = io.StringIO()
    writer = csv.DictWriter(buffer, fieldnames=list(rows[0]))
    writer.writeheader()
    writer.writerows(rows)
    return buffer.getvalue().encode("utf-8")


def _structuring_burst(amount: float, msisdn: str, n: int = 4, **extra) -> list[dict]:
    """`n` cash-outs of the same just-under-threshold amount, minutes apart."""
    return [
        {
            "transaction_id": f"TX{i:05d}",
            "timestamp": f"2026-07-01T10:{i * 3:02d}:00",
            "agent_id": "AGT-01",
            "customer_msisdn": msisdn,
            "type": "cash_out",
            "amount": amount,
            **extra,
        }
        for i in range(n)
    ]


def _reasons_text(reasons: dict[int, list[str]]) -> str:
    return " ".join(r for row in reasons.values() for r in row)


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


# --------------------------------------------------------------------------
# Per-currency structuring threshold
# --------------------------------------------------------------------------

def test_every_supported_market_has_a_structuring_threshold():
    """A market with no threshold would silently fall back to the USD one, which
    is the currency-blind bug this table exists to prevent."""
    for code in SUPPORTED_COUNTRY_CODES:
        currency = get_country(code).currency_code
        assert currency in LARGE_AMOUNT_BY_CURRENCY, (
            f"{code} uses {currency}, which has no structuring threshold"
        )


def test_zimbabwe_keeps_the_original_usd_threshold():
    assert structuring_threshold_for("ZW") == 500.0


def test_threshold_scales_with_the_markets_currency():
    """A number meaningful in USD is trivial in naira — the thresholds must differ
    by roughly the exchange rate, not be equal."""
    assert structuring_threshold_for("NG") > structuring_threshold_for("ZA")
    assert structuring_threshold_for("ZA") > structuring_threshold_for("ZW")
    assert structuring_threshold_for("ng") == structuring_threshold_for("NG")


@pytest.mark.parametrize("country", ["", None, "FR", "  "])
def test_unrecognised_country_falls_back_to_usd(country):
    """An optional label with a typo in it should not cost the operator the run."""
    assert structuring_threshold_for(country) == LARGE_AMOUNT_BY_CURRENCY["USD"]


def test_structuring_burst_is_flagged_in_a_non_usd_market():
    threshold = structuring_threshold_for("NG")
    raw = _as_csv(_structuring_burst(threshold - 5_000, msisdn="+2348012345678"))

    _, _, reasons = analyze_transactions(raw, country="NG")

    assert all(reasons[i] for i in reasons), "every row in the burst should be flagged"
    assert "structuring" in _reasons_text(reasons)
    assert "₦500,000" in _reasons_text(reasons)


def test_the_same_naira_burst_is_not_structuring_under_usd_thresholds():
    """₦495,000 is nowhere near $500, so reading the file as USD must not flag it —
    this is what proves the threshold, not the amounts, is doing the work."""
    raw = _as_csv(_structuring_burst(495_000, msisdn="+2348012345678"))

    _, _, reasons = analyze_transactions(raw, country="ZW")

    assert "structuring" not in _reasons_text(reasons)


def test_usd_burst_is_not_structuring_under_naira_thresholds():
    raw = _as_csv(_structuring_burst(495.0, msisdn="+263771234567"))

    _, _, usd_reasons = analyze_transactions(raw, country="ZW")
    _, _, ngn_reasons = analyze_transactions(raw, country="NG")

    assert "structuring" in _reasons_text(usd_reasons)
    assert "structuring" not in _reasons_text(ngn_reasons)


def test_amounts_outside_the_margin_are_not_structuring():
    """Well under the threshold is just a normal cash-out, in any currency."""
    threshold = structuring_threshold_for("KE")
    raw = _as_csv(_structuring_burst(threshold * (1 - 2 * STRUCTURING_MARGIN_RATIO),
                                     msisdn="+254712345678"))

    _, _, reasons = analyze_transactions(raw, country="KE")

    assert "structuring" not in _reasons_text(reasons)


def test_a_rows_own_country_column_beats_the_declared_upload_country():
    """An aggregator's export can span markets; each row's amount is denominated
    in the market that row states."""
    raw = _as_csv(_structuring_burst(495_000, msisdn="+2348012345678", country="NG"))

    _, _, reasons = analyze_transactions(raw, country="ZW")

    assert "structuring" in _reasons_text(reasons)


# --------------------------------------------------------------------------
# The shipped fixture
# --------------------------------------------------------------------------

def _sample_rows() -> list[dict]:
    with open(SAMPLE_CSV, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def test_sample_fixture_covers_every_supported_market():
    countries = {row["country"] for row in _sample_rows()}
    assert countries == set(SUPPORTED_COUNTRY_CODES)


def test_sample_fixture_uses_e164_numbers_that_resolve_to_their_market():
    """Local 07... form is ambiguous across ZW, UG and TZ; the fixture must not
    reintroduce the collision the rest of the product canonicalises away."""
    for row in _sample_rows():
        msisdn = row["customer_msisdn"]
        assert msisdn.startswith("+"), f"{msisdn} is not in E.164 form"
        _, resolved = normalize_msisdn(msisdn)
        assert resolved == row["country"], f"{msisdn} resolved to {resolved}, not {row['country']}"


def test_injected_structuring_is_flagged_in_every_market():
    """The point of the multi-currency fixture: no market's burst goes undetected."""
    df, _, reasons = analyze_transactions(SAMPLE_CSV.read_bytes())
    flagged = df.loc[[i for i, r in reasons.items() if r]]
    structuring = flagged[flagged["label"] == "anomaly_structuring"]

    assert set(structuring["country"]) == set(SUPPORTED_COUNTRY_CODES)


def test_generator_draws_structuring_amounts_inside_the_detectors_window():
    """The fixture and the detector are two halves of one demo: if the generator's
    band drifts outside the margin, every injected burst silently stops being an
    anomaly and only this assertion says so."""
    sys.path.insert(0, str(SAMPLE_CSV.parent))
    from generate_transactions import STRUCTURING_AMOUNT_RATIO

    low, high = STRUCTURING_AMOUNT_RATIO
    assert 1 - STRUCTURING_MARGIN_RATIO <= low < high < 1


def test_normal_rows_do_not_trip_the_structuring_rule_in_any_market():
    df, _, reasons = analyze_transactions(SAMPLE_CSV.read_bytes())
    normal_reasons = [
        reason
        for i, row_reasons in reasons.items()
        for reason in row_reasons
        if df.loc[i, "label"] == "normal"
    ]

    assert not [r for r in normal_reasons if "structuring" in r]
