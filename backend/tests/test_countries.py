import pytest

from app.services.countries import (
    COUNTRIES,
    SUPPORTED_COUNTRY_CODES,
    UnknownCountryError,
    country_for_dial_code,
    get_country,
)
from app.services.reputation import normalize_msisdn


def test_get_country_is_case_insensitive():
    assert get_country("ke").code == "KE"
    assert get_country(" zw ").code == "ZW"


def test_get_country_rejects_unsupported():
    with pytest.raises(UnknownCountryError):
        get_country("FR")


def test_longer_dial_codes_win_over_shorter_prefixes():
    """263 (Zimbabwe) starts with 26, and 27 is South Africa — a naive shortest-first
    match would file Zimbabwean numbers under the wrong country."""
    assert country_for_dial_code("263771234567").code == "ZW"
    assert country_for_dial_code("27821234567").code == "ZA"
    assert country_for_dial_code("255712345678").code == "TZ"
    assert country_for_dial_code("256772345678").code == "UG"


def test_dial_codes_are_unique():
    dial_codes = [c.dial_code for c in COUNTRIES.values()]
    assert len(dial_codes) == len(set(dial_codes))


def test_every_country_declares_the_data_the_product_depends_on():
    for code in SUPPORTED_COUNTRY_CODES:
        c = get_country(code)
        assert c.regions, f"{code} has no regions — the hotspot map would be empty"
        assert c.providers, f"{code} names no wallets — classifier grounding would be empty"
        assert c.region_label
        assert c.mobile_prefixes


def test_every_countrys_example_number_round_trips():
    """The example number is shown as placeholder text in the apps. If it does not
    itself validate, we are telling users to type an invalid number."""
    for code in SUPPORTED_COUNTRY_CODES:
        country = get_country(code)
        e164, resolved = normalize_msisdn(country.example_msisdn, code)
        assert resolved == code
        assert e164.startswith(f"+{country.dial_code}")
