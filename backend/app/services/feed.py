"""Trending scams feed, plus regional and cross-country hotspot maps.

Plain weighted-rules aggregation over community reports — explicitly NOT an
AI/ML model (see docs/architecture.md, "avoid the AI sledgehammer"). Score per
report = recency_weight x reporter_trust, where recency_weight decays linearly
to zero over `window_days`. Category, region and country scores are just the
sum of their reports' scores.

TWO LEVELS OF MAP, ON PURPOSE
-----------------------------
A single regional map across seven countries would be unreadable and, worse,
misleading: 60+ buckets split the same report volume so thinly that everything
renders green and the map says "no scams anywhere". So the feed returns both:

- `country_hotspots` is always the full cross-country picture, which is what a
  regional operator or a funder looks at.
- `hotspots` is the within-country regional breakdown, and is populated only
  when the caller names a country — because "Nyanza" and "Midlands" on one map
  answer no question a real user has.

The thresholds are absolute rather than relative for the same reason a smoke
alarm is: a level should mean the same thing in Lagos as in Gweru, so a market
with genuinely few reports shows green instead of being scaled up to look red.
Country thresholds are higher than regional ones because a country aggregates
many regions.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

from app.models.domain import Report
from app.schemas.feed import (
    CountryHotspot,
    FeedItemResponse,
    HotspotLevel,
    RegionHotspot,
    TrendingCategory,
    TrendingFeedResponse,
)
from app.services.countries import COUNTRIES, get_country
from app.services.store import Store
from app.services.taxonomy import get_category

DEFAULT_WINDOW_DAYS = 7

REGION_RED_THRESHOLD = 3.0
REGION_YELLOW_THRESHOLD = 1.0
COUNTRY_RED_THRESHOLD = 8.0
COUNTRY_YELLOW_THRESHOLD = 3.0


def _recency_weight(report: Report, now: datetime, window_days: int) -> float:
    age_days = (now - report.created_at).total_seconds() / 86400
    if age_days < 0:
        age_days = 0
    if age_days >= window_days:
        return 0.0
    return 1.0 - (age_days / window_days)


def _level(score: float, red: float, yellow: float) -> HotspotLevel:
    if score >= red:
        return "red"
    if score >= yellow:
        return "yellow"
    return "green"


def _top_key(scores: dict[str, float] | None) -> str | None:
    if not scores:
        return None
    return max(scores, key=lambda k: scores[k])


def build_trending_feed(
    store: Store,
    window_days: int = DEFAULT_WINDOW_DAYS,
    country_code: str | None = None,
) -> TrendingFeedResponse:
    """Aggregate recent reports into trending categories and hotspot maps.

    `country_code` scopes trending categories and enables the regional map.
    Omitting it gives the cross-country view.
    """
    now = datetime.now(timezone.utc)
    since = now - timedelta(days=window_days)
    reports = store.list_reports(since=since)

    country = get_country(country_code) if country_code else None
    scoped = [r for r in reports if country is None or r.country == country.code]

    category_scores: dict[str, float] = {}
    category_counts: dict[str, int] = {}
    region_scores: dict[str, float] = {}
    region_counts: dict[str, int] = {}
    region_top_category: dict[str, dict[str, float]] = {}

    for r in scoped:
        weight = _recency_weight(r, now, window_days) * max(r.reporter_trust, 0.0)
        category_scores[r.category] = category_scores.get(r.category, 0.0) + weight
        category_counts[r.category] = category_counts.get(r.category, 0) + 1

        region_scores[r.region] = region_scores.get(r.region, 0.0) + weight
        region_counts[r.region] = region_counts.get(r.region, 0) + 1
        region_top_category.setdefault(r.region, {})
        region_top_category[r.region][r.category] = (
            region_top_category[r.region].get(r.category, 0.0) + weight
        )

    trending = sorted(
        (
            TrendingCategory(
                category=c, label=get_category(c).label,
                score=round(s, 2), report_count=category_counts[c],
            )
            for c, s in category_scores.items()
        ),
        key=lambda t: t.score, reverse=True,
    )

    hotspots: list[RegionHotspot] = []
    if country is not None:
        for region in country.regions:
            hotspots.append(RegionHotspot(
                region=region,
                level=_level(region_scores.get(region, 0.0),
                             REGION_RED_THRESHOLD, REGION_YELLOW_THRESHOLD),
                report_count=region_counts.get(region, 0),
                top_category=_top_key(region_top_category.get(region)),
            ))
        hotspots.sort(key=lambda h: (h.level != "red", h.level != "yellow", -h.report_count))

    return TrendingFeedResponse(
        generated_at=now,
        window_days=window_days,
        country=country.code if country else None,
        region_label=country.region_label if country else None,
        trending_categories=trending,
        hotspots=hotspots,
        country_hotspots=_build_country_hotspots(reports, now, window_days),
    )


def _build_country_hotspots(
    reports: list[Report], now: datetime, window_days: int
) -> list[CountryHotspot]:
    """Always computed over *all* reports, not the country-scoped subset — the
    cross-country view is the point, and scoping it to one country would leave
    a single-row map."""
    scores: dict[str, float] = {}
    counts: dict[str, int] = {}
    top_category: dict[str, dict[str, float]] = {}

    for r in reports:
        weight = _recency_weight(r, now, window_days) * max(r.reporter_trust, 0.0)
        scores[r.country] = scores.get(r.country, 0.0) + weight
        counts[r.country] = counts.get(r.country, 0) + 1
        top_category.setdefault(r.country, {})
        top_category[r.country][r.category] = top_category[r.country].get(r.category, 0.0) + weight

    hotspots = [
        CountryHotspot(
            country=code,
            country_name=c.name,
            level=_level(scores.get(code, 0.0), COUNTRY_RED_THRESHOLD, COUNTRY_YELLOW_THRESHOLD),
            report_count=counts.get(code, 0),
            top_category=_top_key(top_category.get(code)),
        )
        for code, c in COUNTRIES.items()
    ]
    hotspots.sort(key=lambda h: (h.level != "red", h.level != "yellow", -h.report_count))
    return hotspots


def list_feed_items(store: Store, country_code: str | None = None) -> list[FeedItemResponse]:
    """Alerts for one market, or all of them.

    An item with `country=None` is cross-market guidance (a pattern spreading
    everywhere) and is always included, so scoping to Kenya never hides advice
    that applies to Kenya too.
    """
    items = store.list_feed_items()
    if country_code:
        code = get_country(country_code).code
        items = [i for i in items if i.country in (None, code)]
    return [
        FeedItemResponse(id=i.id, title=i.title, category=i.category, summary=i.summary,
                          country=i.country, region=i.region, created_at=i.created_at)
        for i in items
    ]
