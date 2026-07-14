"""Trending scams feed and province hotspot map.

Plain weighted-rules aggregation over community reports — explicitly NOT an
AI/ML model (see docs/architecture.md, rubric C2 "avoid the AI sledgehammer").
Score per report = recency_weight x reporter_trust, where recency_weight
decays linearly to zero over `window_days`. Category and province scores are
just the sum of their reports' scores.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.models.domain import ZIMBABWE_PROVINCES, Report
from app.schemas.feed import FeedItemResponse, HotspotLevel, ProvinceHotspot, TrendingCategory, TrendingFeedResponse
from app.services.store import Store

DEFAULT_WINDOW_DAYS = 7


def _recency_weight(report: Report, now: datetime, window_days: int) -> float:
    age_days = (now - report.created_at).total_seconds() / 86400
    if age_days < 0:
        age_days = 0
    if age_days >= window_days:
        return 0.0
    return 1.0 - (age_days / window_days)


def _hotspot_level(score: float) -> HotspotLevel:
    if score >= 3.0:
        return "red"
    if score >= 1.0:
        return "yellow"
    return "green"


def build_trending_feed(store: Store, window_days: int = DEFAULT_WINDOW_DAYS) -> TrendingFeedResponse:
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=window_days)
    reports = store.list_reports(since=since)

    category_scores: dict[str, float] = {}
    category_counts: dict[str, int] = {}
    province_scores: dict[str, float] = {}
    province_counts: dict[str, int] = {}
    province_top_category: dict[str, dict[str, float]] = {}

    for r in reports:
        weight = _recency_weight(r, now, window_days) * max(r.reporter_trust, 0.0)
        category_scores[r.category] = category_scores.get(r.category, 0.0) + weight
        category_counts[r.category] = category_counts.get(r.category, 0) + 1

        province_scores[r.province] = province_scores.get(r.province, 0.0) + weight
        province_counts[r.province] = province_counts.get(r.province, 0) + 1
        cat_map = province_top_category.setdefault(r.province, {})
        cat_map[r.category] = cat_map.get(r.category, 0.0) + weight

    trending = sorted(
        (TrendingCategory(category=c, score=round(s, 2), report_count=category_counts[c])
         for c, s in category_scores.items()),
        key=lambda t: t.score, reverse=True,
    )

    hotspots = []
    for province in ZIMBABWE_PROVINCES:
        score = province_scores.get(province, 0.0)
        top_cat = None
        cat_map = province_top_category.get(province)
        if cat_map:
            top_cat = max(cat_map, key=cat_map.get)
        hotspots.append(ProvinceHotspot(
            province=province, level=_hotspot_level(score),
            report_count=province_counts.get(province, 0), top_category=top_cat,
        ))
    hotspots.sort(key=lambda h: (h.level != "red", h.level != "yellow", -h.report_count))

    return TrendingFeedResponse(
        generated_at=now, window_days=window_days,
        trending_categories=trending, hotspots=hotspots,
    )


def list_feed_items(store: Store) -> list[FeedItemResponse]:
    return [
        FeedItemResponse(id=i.id, title=i.title, category=i.category, summary=i.summary,
                          province=i.province, created_at=i.created_at)
        for i in store.list_feed_items()
    ]
