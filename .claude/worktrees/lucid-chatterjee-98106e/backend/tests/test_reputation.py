import pytest

from app.schemas.reputation import ReportCreate
from app.services.countries import UnknownCountryError
from app.services.reputation import ValidationError, lookup_number, normalize_msisdn, submit_report


def test_normalize_msisdn_accepts_local_and_international_formats():
    assert normalize_msisdn("0771234567", "ZW") == ("+263771234567", "ZW")
    assert normalize_msisdn("263771234567") == ("+263771234567", "ZW")
    assert normalize_msisdn("+263 77 123 4567") == ("+263771234567", "ZW")


def test_normalize_msisdn_resolves_each_supported_market():
    cases = {
        "+254712345678": "KE",
        "+2348031234567": "NG",
        "+256772345678": "UG",
        "+27821234567": "ZA",
        "+233241234567": "GH",
        "+255712345678": "TZ",
    }
    for raw, expected in cases.items():
        e164, country = normalize_msisdn(raw)
        assert country == expected
        assert e164 == raw.replace(" ", "")


def test_identical_local_numbers_resolve_to_different_countries():
    """0771234567 is valid in Zimbabwe, Uganda and Tanzania. Without the country
    hint these would collapse into one reputation record."""
    zw, _ = normalize_msisdn("0771234567", "ZW")
    ug, _ = normalize_msisdn("0771234567", "UG")
    tz, _ = normalize_msisdn("0771234567", "TZ")
    assert zw == "+263771234567"
    assert ug == "+256771234567"
    assert tz == "+255771234567"
    assert len({zw, ug, tz}) == 3


def test_international_form_overrides_a_wrong_country_hint():
    # The dial code is authoritative; a stale picker value must not corrupt it.
    assert normalize_msisdn("+254712345678", "ZW") == ("+254712345678", "KE")


def test_normalize_msisdn_rejects_invalid_numbers():
    with pytest.raises(ValidationError):
        normalize_msisdn("12345", "ZW")


def test_normalize_msisdn_rejects_a_non_mobile_prefix():
    # 0242 is a Zimbabwean landline range, not a mobile one.
    with pytest.raises(ValidationError):
        normalize_msisdn("0242123456", "ZW")


def test_normalize_msisdn_rejects_an_unsupported_country():
    with pytest.raises(UnknownCountryError):
        normalize_msisdn("0712345678", "FR")


def test_submit_report_then_lookup_reflects_report_count(fresh_store):
    payload = ReportCreate(msisdn="0779999999", country="ZW", category="fake_job", region="Harare")
    result = submit_report(fresh_store, payload)
    assert result.status == "recorded"
    assert result.msisdn == "+263779999999"
    assert result.country == "ZW"

    reputation = lookup_number(fresh_store, "0779999999", "ZW")
    assert reputation.report_count == 1
    assert reputation.categories == {"fake_job": 1}


def test_report_excerpt_is_redacted_before_storage(fresh_store):
    submit_report(fresh_store, ReportCreate(
        msisdn="+254712345678", category="otp_phishing",
        message_excerpt="Send your OTP 483920 to 0722113344 or email me at scam@example.com",
    ))
    stored = fresh_store.list_reports()[0].message_excerpt
    assert "483920" not in stored
    assert "0722113344" not in stored
    assert "scam@example.com" not in stored
    # The scam's wording — the part the classifier and a moderator need — survives.
    assert "Send your" in stored


def test_unrecognised_region_falls_back_rather_than_rejecting(fresh_store):
    result = submit_report(fresh_store, ReportCreate(
        msisdn="+254712345678", category="fake_job", region="Nairibi",  # typo
    ))
    assert result.status == "recorded"
    assert result.region in ("Nairobi", "Central", "Coast", "Eastern",
                             "North Eastern", "Nyanza", "Rift Valley", "Western")


def test_rate_limiting_kicks_in_after_threshold(fresh_store):
    reporter = "reporter-1"
    last_status = None
    for _ in range(10):
        payload = ReportCreate(msisdn="0788888888", country="ZW",
                                category="fake_investment", reporter_id=reporter)
        last_status = submit_report(fresh_store, payload).status
    assert last_status == "rate_limited"


def test_anonymous_reports_are_never_rate_limited(fresh_store):
    """Requiring an identity to report is a barrier for exactly the people most
    at risk of retaliation, so anonymous reports bypass per-reporter limits."""
    for _ in range(10):
        result = submit_report(fresh_store, ReportCreate(
            msisdn="0788888888", country="ZW", category="fake_investment",
        ))
        assert result.status == "recorded"


def test_public_flag_threshold_requires_multiple_reports(fresh_store):
    for i in range(5):
        payload = ReportCreate(msisdn="0731111111", country="ZW",
                                category="mobile_money_reversal", reporter_id=f"r{i}")
        submit_report(fresh_store, payload)
    reputation = lookup_number(fresh_store, "0731111111", "ZW")
    assert reputation.is_publicly_flagged is True
    assert reputation.risk_level == "medium"  # 5 reports, single category, single country


def test_cross_border_reports_escalate_risk_to_high(fresh_store):
    """A number reported from two markets is an organised operation, not a
    local dispute — it goes high before it reaches the volume threshold."""
    submit_report(fresh_store, ReportCreate(
        msisdn="+2348031234567", category="fake_job", reporter_id="r1"))
    submit_report(fresh_store, ReportCreate(
        msisdn="+2348031234567", category="fake_job", reporter_id="r2"))

    # Same number reported by someone in Ghana.
    from datetime import datetime, timezone

    from app.models.domain import Report
    fresh_store.add_report(Report(msisdn="+2348031234567", country="GH", category="fake_job",
                                   region="Greater Accra", created_at=datetime.now(timezone.utc)))

    reputation = lookup_number(fresh_store, "+2348031234567")
    assert set(reputation.countries) == {"NG", "GH"}
    assert reputation.risk_level == "high"


def test_unknown_number_has_unknown_risk_level(fresh_store):
    reputation = lookup_number(fresh_store, "0730000000", "ZW")
    assert reputation.report_count == 0
    assert reputation.risk_level == "unknown"
    assert reputation.is_publicly_flagged is False


def test_list_number_reputations_ranks_by_report_count(fresh_store):
    submit_report(fresh_store, ReportCreate(msisdn="0771111111", country="ZW", category="fake_job"))
    submit_report(fresh_store, ReportCreate(msisdn="0782222222", country="ZW",
                                             category="fake_investment", reporter_id="r1"))
    submit_report(fresh_store, ReportCreate(msisdn="0782222222", country="ZW",
                                             category="fake_investment", reporter_id="r2"))

    numbers = fresh_store.list_number_reputations()
    assert [n.msisdn for n in numbers] == ["+263782222222", "+263771111111"]
    assert numbers[0].report_count == 2
