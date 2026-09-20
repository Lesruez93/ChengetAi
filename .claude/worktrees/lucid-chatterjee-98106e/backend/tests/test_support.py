import pytest

from app.services.countries import SUPPORTED_COUNTRY_CODES, UnknownCountryError
from app.services.support import SUPPORT_CHANNELS, build_support_pathway


def test_every_supported_country_has_a_support_pathway():
    """A market we accept reports from but cannot route to help is worse than
    not covering it at all."""
    for code in SUPPORTED_COUNTRY_CODES:
        assert code in SUPPORT_CHANNELS, f"{code} has no support channels"
        assert SUPPORT_CHANNELS[code], f"{code} has an empty support ladder"


def test_every_country_has_a_wallet_and_a_police_channel():
    for code, channels in SUPPORT_CHANNELS.items():
        kinds = {c.kind for c in channels}
        assert "wallet" in kinds, f"{code} has no wallet channel — the first call after a loss"
        assert "police" in kinds, f"{code} has no police channel"


def test_unverified_contacts_are_flagged_rather_than_hidden():
    """Shipping an unconfirmed emergency number as fact is its own safety failure,
    so the distinction has to reach the client."""
    for channels in SUPPORT_CHANNELS.values():
        for channel in channels:
            assert isinstance(channel.verified, bool)
            if channel.verified:
                assert channel.contact, "a verified channel must actually carry a contact"


def test_pathway_leads_with_the_category_specific_action():
    pathway = build_support_pathway("KE", "otp_phishing")
    assert pathway["category"] == "otp_phishing"
    assert "one-time code" in pathway["immediate_steps"][0]
    assert pathway["category_first_action"] == pathway["immediate_steps"][0]


def test_pathway_without_a_category_still_gives_universal_steps():
    pathway = build_support_pathway("NG")
    assert pathway["category"] is None
    assert len(pathway["immediate_steps"]) >= 4
    assert pathway["country_name"] == "Nigeria"


def test_unknown_country_raises():
    with pytest.raises(UnknownCountryError):
        build_support_pathway("FR")
