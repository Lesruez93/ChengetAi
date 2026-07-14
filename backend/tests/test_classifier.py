from app.services.classifier import BaselineClassifier, get_classifier


def test_baseline_flags_ecocash_reversal_scam():
    clf = BaselineClassifier()
    result = clf.classify(
        "Confirmed. You have received $80 from Rue. Ref:AB12CD34EF. Kana yakanga isiri yako "
        "pindura kuti tidzorerwe (mistake transfer) tinokutumira number yekudzorera mari."
    )
    assert result.verdict in {"scam", "suspicious"}
    assert result.strategy_used == "baseline"
    assert 0.0 <= result.confidence <= 1.0


def test_baseline_treats_bank_notice_as_safe():
    clf = BaselineClassifier()
    result = clf.classify(
        "Steward Bank: Your account ending 4821 was credited with $500 on 12/07. "
        "Available balance $80. For queries call 0242 xxx xxx."
    )
    assert result.verdict == "safe"


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
        "Congratulations! You have been shortlisted for a job. Pay $15 registration fee to secure your slot."
    )
    phrases = {rp.phrase for rp in result.risk_phrases}
    assert "registration fee" in phrases
    assert "shortlisted" in phrases
