from app.services.classifier import BaselineClassifier, _find_risk_phrases, get_classifier


def test_baseline_flags_reversal_scam():
    clf = BaselineClassifier()
    result = clf.classify(
        "Confirmed. You have received $80 from Rue. Ref:AB12CD34EF. This was sent to you in "
        "error, please reverse the money to 0771234567 immediately.",
        "ZW",
    )
    assert result.verdict in {"scam", "suspicious"}
    assert result.strategy_used == "baseline"
    assert result.country == "ZW"
    assert 0.0 <= result.confidence <= 1.0


def test_baseline_flags_the_same_scam_in_another_market():
    """The mechanism, not the wallet's name, is what the model should key on."""
    clf = BaselineClassifier()
    result = clf.classify(
        "M-PESA Alert: KSh5,000 was sent to your wallet in error by Otieno. Please reverse to "
        "0722113344 immediately or your account will be suspended.",
        "KE",
    )
    assert result.verdict in {"scam", "suspicious"}
    assert result.country == "KE"


def test_corpus_is_english_only():
    """The product classifies English only, so training on other languages would
    teach the model text no other part of the system can handle."""
    import json

    from app.services.classifier import CORPUS_PATH

    with open(CORPUS_PATH, encoding="utf-8") as f:
        rows = [json.loads(line) for line in f if line.strip()]
    assert rows, "corpus is empty — run sample_data/generate_scam_corpus.py"

    # Latin-1 plus the currency symbols and punctuation the templates use.
    allowed_extra = set("₦₵—…")
    for row in rows:
        offenders = {c for c in row["text"] if ord(c) > 0x24F and c not in allowed_extra}
        assert not offenders, f"non-English characters {offenders} in: {row['text'][:60]}"


def test_baseline_treats_bank_notice_as_safe():
    clf = BaselineClassifier()
    result = clf.classify(
        "Steward Bank: Your account ending 4821 was credited with $500 on 12/07. "
        "Available balance $80. For queries call the number on your card.",
        "ZW",
    )
    assert result.verdict == "safe"


def test_safe_verdicts_carry_no_next_steps_and_scams_always_do():
    clf = BaselineClassifier()
    safe = clf.classify("Your statement for July is ready in the mobile app.", "ZA")
    assert safe.next_steps == []

    scam = clf.classify(
        "Congratulations! You have been shortlisted. Pay R500 registration fee to 0821234567 "
        "urgently to secure your slot.",
        "ZA",
    )
    assert scam.verdict in {"scam", "suspicious"}
    assert scam.next_steps, "a non-safe verdict must always hand the user a pathway"
    assert any("South Africa" in step for step in scam.next_steps)


def test_unknown_country_falls_back_instead_of_failing():
    clf = BaselineClassifier()
    result = clf.classify("Pay a registration fee to secure your slot.", "FR")
    assert result.country == "ZW"  # DEFAULT_COUNTRY


def test_get_classifier_falls_back_to_baseline_without_api_key(monkeypatch):
    monkeypatch.setenv("ANTHROPIC_API_KEY", "")
    from app.config import get_settings

    get_settings.cache_clear()
    clf = get_classifier("llm")
    assert clf.__class__.__name__ == "BaselineClassifier"
    get_settings.cache_clear()


def test_risk_phrases_extracted_for_upfront_fee_scam():
    clf = BaselineClassifier()
    result = clf.classify(
        "Congratulations! You have been shortlisted for a job. Pay $15 registration fee to "
        "secure your slot.",
        "ZW",
    )
    phrases = {rp.phrase for rp in result.risk_phrases}
    assert "registration fee" in phrases
    assert "shortlisted" in phrases


def test_risk_phrases_cover_patterns_from_other_markets():
    phrases = {rp.phrase for rp in _find_risk_phrases(
        "Your BVN is due for revalidation. Verify your account within 24hrs or it will be "
        "suspended."
    )}
    assert "bvn" in phrases
    assert "verify your account" in phrases
    assert "suspended" in phrases


def test_risk_phrase_matching_is_word_bounded():
    """Short keys like 'nin' and 'grant' must not fire on 'morning' or 'granted'."""
    phrases = {rp.phrase for rp in _find_risk_phrases(
        "Good morning, the loan you granted us last evening has been repaid in full."
    )}
    assert "nin" not in phrases
    assert "grant" not in phrases


def test_duplicate_reasons_are_not_repeated():
    """'reverse' and 'reversal' share one reason; showing it twice reads as padding."""
    found = _find_risk_phrases("Please reverse the payment, this reversal is urgent.")
    reasons = [rp.reason for rp in found]
    assert len(reasons) == len(set(reasons))
