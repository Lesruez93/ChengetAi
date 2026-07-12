from datetime import datetime, timedelta, timezone

from app.models.domain import Report
from app.services.feed import build_trending_feed


def test_trending_feed_ranks_categories_by_weighted_score(fresh_store):
    now = datetime.now(timezone.utc)
    for _ in range(5):
        fresh_store.add_report(Report(msisdn="0771111111", category="ecocash_reversal",
                                       province="Harare", reporter_trust=1.0, created_at=now))
    fresh_store.add_report(Report(msisdn="0782222222", category="fake_job",
                                   province="Bulawayo", reporter_trust=1.0, created_at=now))

    feed = build_trending_feed(fresh_store, window_days=7)
    assert feed.trending_categories[0].category == "ecocash_reversal"
    assert feed.trending_categories[0].report_count == 5
    assert "weighted rules" in feed.method_note.lower()


def test_trending_feed_excludes_reports_outside_window(fresh_store):
    now = datetime.now(timezone.utc)
    fresh_store.add_report(Report(msisdn="0771111111", category="fake_forex",
                                   province="Harare", created_at=now - timedelta(days=30)))
    feed = build_trending_feed(fresh_store, window_days=7)
    assert feed.trending_categories == []


def test_hotspots_cover_all_provinces(fresh_store):
    feed = build_trending_feed(fresh_store, window_days=7)
    provinces = {h.province for h in feed.hotspots}
    assert "Harare" in provinces
    assert "Bulawayo" in provinces
    assert len(feed.hotspots) == 10
