from app.services.redaction import redact_excerpt


def test_phone_numbers_are_masked_in_both_formats():
    assert "[number]" in redact_excerpt("Send it to 0771234567 now")
    assert "0771234567" not in redact_excerpt("Send it to 0771234567 now")
    assert "[number]" in redact_excerpt("Call +254 712 345 678 today")


def test_otps_and_identity_numbers_are_masked():
    out = redact_excerpt("Your OTP is 483920 and your BVN 22334455667")
    assert "483920" not in out
    assert "22334455667" not in out


def test_emails_and_links_are_masked():
    out = redact_excerpt("Mail me at scam@example.com or visit http://phish.example/go")
    assert "[email]" in out
    assert "[link]" in out
    assert "phish.example" not in out


def test_scam_wording_survives_redaction():
    """Redaction must not destroy the signal the classifier and moderators need."""
    out = redact_excerpt("URGENT: reverse the wrong deposit of $80 to 0771234567 immediately")
    assert "reverse the wrong deposit" in out
    assert "URGENT" in out


def test_redaction_is_idempotent():
    once = redact_excerpt("Send to 0771234567 and mail scam@example.com")
    assert redact_excerpt(once) == once


def test_long_excerpts_are_truncated():
    out = redact_excerpt("word " * 400)
    assert len(out) <= 501
    assert out.endswith("…")


def test_empty_input_is_handled():
    assert redact_excerpt("") == ""
