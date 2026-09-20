"""The seeded demo data must stay valid and must cover every supported market.

Seed data is easy to let rot: a market gets added to `services/countries.py`
with support contacts and a picker entry, and nothing fails — the country just
renders as an empty product to whoever opens it. These tests make that a test
failure instead of a silent gap, and check the seed against the same rules the
intake path enforces, so the demo can never ship numbers or regions the API
would itself reject.
"""

from __future__ import annotations

import pytest

from app.services.countries import SUPPORTED_COUNTRY_CODES, get_country
from app.services.reputation import normalize_msisdn
from app.services.store import InMemoryStore
from app.services.taxonomy import SCAM_CATEGORY_KEYS


@pytest.fixture(scope="module")
def seeded_store() -> InMemoryStore:
    return InMemoryStore()


@pytest.mark.parametrize("code", SUPPORTED_COUNTRY_CODES)
def test_every_supported_country_has_seeded_reports(seeded_store, code):
    reports = [r for r in seeded_store.list_reports() if r.country == code]
    assert reports, f"{code} is a supported market with no seeded reports"


@pytest.mark.parametrize("code", SUPPORTED_COUNTRY_CODES)
def test_every_supported_country_has_at_least_two_distinct_numbers(seeded_store, code):
    """One number per market makes the Lookup screen look like a stub."""
    msisdns = {r.msisdn for r in seeded_store.list_reports() if r.country == code}
    assert len(msisdns) >= 2, f"{code} has only {len(msisdns)} seeded number(s)"


def test_seeded_msisdns_are_valid_e164_for_their_market(seeded_store):
    """Every seeded number must survive the same normalisation intake applies."""
    for report in seeded_store.list_reports():
        normalized, resolved = normalize_msisdn(report.msisdn)
        assert normalized == report.msisdn, (
            f"{report.msisdn} is not stored in canonical E.164 form"
        )
        # A number's dial code may resolve to a market other than the one the
        # report came from — that is the cross-border case, and it is expected.
        assert resolved in SUPPORTED_COUNTRY_CODES


def test_seeded_regions_exist_in_their_country_registry(seeded_store):
    for report in seeded_store.list_reports():
        if report.region is None:
            continue
        regions = get_country(report.country).regions
        assert report.region in regions, (
            f"'{report.region}' is not a region of {report.country}"
        )


def test_seeded_categories_are_in_the_taxonomy(seeded_store):
    """Free-text categories are allowed at intake but aggregate as 'other';
    the seed should never rely on that fallback."""
    for report in seeded_store.list_reports():
        assert report.category in SCAM_CATEGORY_KEYS, (
            f"seeded category '{report.category}' is outside the taxonomy"
        )


def test_seed_includes_a_number_reported_from_two_countries(seeded_store):
    """Covers the cross-border reputation path: the `countries` tally and the
    'home market' pick in upsert_number_reputation."""
    cross_border = [
        n for n in seeded_store.list_number_reputations() if len(n.countries) > 1
    ]
    assert cross_border, "no seeded number spans two markets"


def test_seed_includes_a_publicly_flagged_number(seeded_store):
    """Without one, the flagged-number branch of Lookup is never demoed."""
    flagged = [n for n in seeded_store.list_number_reputations() if n.is_publicly_flagged]
    assert flagged, "no seeded number clears the public flag threshold"


def test_every_supported_country_is_reachable_in_the_feed(seeded_store):
    """A feed item is either country-scoped or cross-market (country=None).
    Every market must see something on Alerts, from one source or the other."""
    items = seeded_store.list_feed_items()
    cross_market = [i for i in items if i.country is None]
    assert cross_market, "no cross-market feed items"
    for code in SUPPORTED_COUNTRY_CODES:
        visible = cross_market + [i for i in items if i.country == code]
        assert visible, f"{code} has an empty Alerts screen"


def test_seeded_feed_item_regions_exist_in_their_country(seeded_store):
    for item in seeded_store.list_feed_items():
        if item.country is None or item.region is None:
            continue
        assert item.region in get_country(item.country).regions, (
            f"feed item region '{item.region}' is not in {item.country}"
        )
