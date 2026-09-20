from datetime import datetime, timedelta, timezone

from app.models.domain import Report
from app.services.feed import build_trending_feed, list_feed_items


def _report(**kwargs) -> Report:
    defaults = dict(msisdn="+263771111111", country="ZW", category="mobile_money_reversal",
                    region="Harare", reporter_trust=1.0, created_at=datetime.now(timezone.utc))
    defaults.update(kwargs)
    return Report(**defaults)


def test_trending_feed_ranks_categories_by_weighted_score(fresh_store):
    for _ in range(5):
        fresh_store.add_report(_report(category="mobile_money_reversal"))
    fresh_store.add_report(_report(msisdn="+263782222222", category="fake_job", region="Bulawayo"))

    feed = build_trending_feed(fresh_store, window_days=7)
    assert feed.trending_categories[0].category == "mobile_money_reversal"
    assert feed.trending_categories[0].report_count == 5
    assert feed.trending_categories[0].label == "Wrong deposit / reversal"
    assert "weighted rules" in feed.method_note.lower()


def test_trending_feed_excludes_reports_outside_window(fresh_store):
    fresh_store.add_report(_report(
        category="fake_investment",
        created_at=datetime.now(timezone.utc) - timedelta(days=30),
    ))
    feed = build_trending_feed(fresh_store, window_days=7)
    assert feed.trending_categories == []


def test_regional_hotspots_only_appear_when_a_country_is_named(fresh_store):
    """A 60-bucket map across seven countries answers no question a user has,
    so the regional breakdown is country-scoped by design."""
    fresh_store.add_report(_report())

    unscoped = build_trending_feed(fresh_store, window_days=7)
    assert unscoped.hotspots == []
    assert unscoped.region_label is None

    scoped = build_trending_feed(fresh_store, window_days=7, country_code="ZW")
    assert {h.region for h in scoped.hotspots} >= {"Harare", "Bulawayo"}
    assert len(scoped.hotspots) == 10
    assert scoped.region_label == "Province"


def test_regional_hotspots_use_the_countrys_own_label_and_regions(fresh_store):
    feed = build_trending_feed(fresh_store, window_days=7, country_code="KE")
    assert feed.region_label == "Region"
    regions = {h.region for h in feed.hotspots}
    assert "Nairobi" in regions
    assert "Harare" not in regions

    ng = build_trending_feed(fresh_store, window_days=7, country_code="NG")
    assert ng.region_label == "Zone"
    assert "Lagos" in {h.region for h in ng.hotspots}


def test_country_hotspots_always_cover_every_supported_market(fresh_store):
    feed = build_trending_feed(fresh_store, window_days=7, country_code="ZW")
    codes = {h.country for h in feed.country_hotspots}
    assert codes == {"ZW", "KE", "NG", "UG", "ZA", "GH", "TZ"}


def test_country_scoping_excludes_other_markets_reports(fresh_store):
    fresh_store.add_report(_report(country="ZW", category="faith_seed"))
    fresh_store.add_report(_report(msisdn="+254712345678", country="KE",
                                    category="sim_swap", region="Nairobi"))

    ke = build_trending_feed(fresh_store, window_days=7, country_code="KE")
    assert [t.category for t in ke.trending_categories] == ["sim_swap"]

    # ...but the cross-country rollup still sees both.
    counts = {h.country: h.report_count for h in ke.country_hotspots}
    assert counts["ZW"] == 1
    assert counts["KE"] == 1


def test_feed_items_scoped_to_a_country_still_include_cross_market_alerts(fresh_store):
    from app.models.domain import FeedItem

    fresh_store._feed_items.extend([
        FeedItem(title="Everywhere", category="mobile_money_reversal", country=None),
        FeedItem(title="Kenya only", category="sim_swap", country="KE"),
        FeedItem(title="Nigeria only", category="otp_phishing", country="NG"),
    ])
    titles = {i.title for i in list_feed_items(fresh_store, "KE")}
    assert titles == {"Everywhere", "Kenya only"}
