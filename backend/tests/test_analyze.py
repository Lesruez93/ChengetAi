from app.schemas.reputation import ReportCreate
from app.services.analyze import analyze
from app.services.entities import extract_phone_numbers, extract_urls
from app.services.link_check import assess_url
from app.services.reputation import submit_report

# -- entity extraction --


def test_extracts_explicit_and_bare_urls():
    text = "Claim now at https://ecocash-verify.tk/login or visit www.example.com today."
    urls = extract_urls(text)
    assert "https://ecocash-verify.tk/login" in urls
    assert "www.example.com" in urls


def test_ignores_prose_that_looks_like_a_domain():
    # "e.g." and an abbreviation-heavy sentence must not parse as links.
    assert extract_urls("Please reverse the money, e.g. to my other line. Thanks.") == []


def test_strips_trailing_sentence_punctuation_from_urls():
    assert extract_urls("Go to bit.ly/abc123.") == ["bit.ly/abc123"]


def test_does_not_extract_the_same_url_twice_as_bare_host():
    assert extract_urls("http://scam.xyz/a and again http://scam.xyz/a") == ["http://scam.xyz/a"]


def test_extracts_zimbabwean_numbers_in_several_formats():
    local, unrecognized = extract_phone_numbers("Call 0771234567 or +263 78 234 5678 now")
    assert local == ["0771234567", "0782345678"]
    assert unrecognized == []


def test_reports_non_zimbabwean_numbers_separately():
    local, unrecognized = extract_phone_numbers("Call +44 20 7946 0958 for details")
    assert local == []
    assert len(unrecognized) == 1


def test_digits_inside_a_link_are_not_read_as_a_phone_number():
    local, _ = extract_phone_numbers("Open http://scam.xyz/pay/0771234567 now")
    assert local == []


def test_money_amounts_are_not_phone_numbers():
    local, unrecognized = extract_phone_numbers("You have won $2000 today")
    assert local == []
    assert unrecognized == []


# -- link heuristics --


def test_brand_lookalike_domain_is_high_risk():
    assessment = assess_url("http://ecocash-verify.tk/login")
    assert assessment.risk_level == "high"
    assert any("ecocash" in r.lower() for r in assessment.reasons)


def test_real_brand_domain_is_not_flagged_as_a_lookalike():
    assessment = assess_url("https://www.ecocash.co.zw/")
    assert assessment.risk_level == "unknown"


def test_www_prefix_alone_does_not_count_as_a_deep_subdomain_chain():
    # Regression: counting dots flagged every ordinary "www.brand.co.zw".
    assert assess_url("https://www.stewardbank.co.zw/personal").risk_level == "unknown"
    assert assess_url("http://login.secure.account.stewardbank.co.zw.tk/").risk_level == "high"


def test_raw_ip_address_link_is_high_risk():
    assert assess_url("http://102.23.44.10/verify").risk_level == "high"


def test_url_shortener_is_flagged():
    assessment = assess_url("https://bit.ly/3xyzabc")
    assert assessment.risk_level == "medium"
    assert any("shortened" in r.lower() for r in assessment.reasons)


def test_clean_link_is_unknown_not_safe():
    # A clean-looking address is explicitly not called safe — nothing fetches it.
    assessment = assess_url("https://www.example.com/news")
    assert assessment.risk_level == "unknown"
    assert "does not make it safe" in assessment.reasons[0]


# -- combined analysis --


def test_analyze_takes_the_worst_finding_across_entities(fresh_store):
    # Bland wording, but the link is a brand lookalike.
    result = analyze(fresh_store, "Hi, your parcel is waiting. Details here: http://ecocash-verify.tk/login")
    assert result.verdict == "scam"
    assert result.links[0].risk_level == "high"
    assert "ecocash-verify.tk" in result.summary


def test_analyze_flags_a_reported_number_in_otherwise_plain_text(fresh_store):
    for i in range(6):
        submit_report(
            fresh_store,
            ReportCreate(msisdn="0771234567", category="ecocash_reversal", reporter_id=f"r{i}"),
        )

    result = analyze(fresh_store, "Please call me back on 0771234567 when you are free")
    assert result.verdict == "scam"
    assert result.numbers[0].risk_level == "high"
    assert result.numbers[0].report_count == 6
    assert result.confidence > 0.6


def test_analyze_skips_the_classifier_for_a_bare_number(fresh_store):
    result = analyze(fresh_store, "0771234567")
    assert result.message is None
    assert len(result.numbers) == 1


def test_analyze_of_clean_text_does_not_overclaim(fresh_store):
    result = analyze(
        fresh_store,
        "Zuva rakanaka Rutendo! Ndakuedza kukufonera, tinofanira kutaura nezve order "
        "yevhiki rino. Ndinokufonerazve manheru.",
    )
    assert result.verdict == "safe"
    assert "not a guarantee" in result.summary


def test_analyze_reports_unrecognized_numbers(fresh_store):
    result = analyze(fresh_store, "Please ring me on +44 20 7946 0958 as soon as you can")
    assert len(result.unrecognized_numbers) == 1
    assert "Could not check" in result.summary


def test_analyze_endpoint_returns_all_sections(client):
    resp = client.post(
        "/analyze",
        json={"text": "Your account is blocked. Verify now at http://102.23.44.10/verify or call 0771234567"},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert body["verdict"] == "scam"
    assert body["links"][0]["risk_level"] == "high"
    assert len(body["numbers"]) == 1
    assert body["message"] is not None
    assert body["method_note"]


def test_analyze_endpoint_rejects_empty_text(client):
    assert client.post("/analyze", json={"text": ""}).status_code == 422


def test_summary_mentions_a_number_with_a_single_report(fresh_store):
    # Regression: a number below the public-flag threshold was summarised as
    # "nothing was flagged" while its report count was displayed underneath.
    submit_report(fresh_store, ReportCreate(msisdn="0782345678", category="fake_job"))

    result = analyze(fresh_store, "0782345678")
    assert "reported 1 time" in result.summary
    assert "not yet enough to flag it publicly" in result.summary
    assert "Nothing was flagged" not in result.summary
    assert result.verdict == "safe"  # one report is not grounds for a scam verdict
