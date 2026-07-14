from app.schemas.reputation import ReportCreate
from app.services.reputation import ValidationError, lookup_number, normalize_msisdn, submit_report


def test_normalize_msisdn_accepts_local_and_international_formats():
    assert normalize_msisdn("0771234567") == "0771234567"
    assert normalize_msisdn("263771234567") == "0771234567"
    assert normalize_msisdn("+263 77 123 4567") == "0771234567"


def test_normalize_msisdn_rejects_invalid_numbers():
    try:
        normalize_msisdn("12345")
        assert False, "expected ValidationError"
    except ValidationError:
        pass


def test_submit_report_then_lookup_reflects_report_count(fresh_store):
    payload = ReportCreate(msisdn="0799999999", category="fake_job", province="Harare")
    result = submit_report(fresh_store, payload)
    assert result.status == "recorded"

    reputation = lookup_number(fresh_store, "0799999999")
    assert reputation.report_count == 1
    assert reputation.categories == {"fake_job": 1}


def test_rate_limiting_kicks_in_after_threshold(fresh_store):
    reporter = "reporter-1"
    last_status = None
    for _ in range(10):
        payload = ReportCreate(msisdn="0788888888", category="fake_forex", reporter_id=reporter)
        last_status = submit_report(fresh_store, payload).status
    assert last_status == "rate_limited"


def test_public_flag_threshold_requires_multiple_reports(fresh_store):
    for i in range(5):
        payload = ReportCreate(msisdn="0761111111", category="ecocash_reversal", reporter_id=f"r{i}")
        submit_report(fresh_store, payload)
    reputation = lookup_number(fresh_store, "0761111111")
    assert reputation.is_publicly_flagged is True
    assert reputation.risk_level == "medium"  # 5 reports but a single category, so not "high"


def test_unknown_number_has_unknown_risk_level(fresh_store):
    reputation = lookup_number(fresh_store, "0700000000")
    assert reputation.report_count == 0
    assert reputation.risk_level == "unknown"
    assert reputation.is_publicly_flagged is False


def test_list_number_reputations_ranks_by_report_count(fresh_store):
    submit_report(fresh_store, ReportCreate(msisdn="0771111111", category="fake_job"))
    submit_report(fresh_store, ReportCreate(msisdn="0782222222", category="fake_forex", reporter_id="r1"))
    submit_report(fresh_store, ReportCreate(msisdn="0782222222", category="fake_forex", reporter_id="r2"))

    numbers = fresh_store.list_number_reputations()
    assert [n.msisdn for n in numbers] == ["0782222222", "0771111111"]
    assert numbers[0].report_count == 2
