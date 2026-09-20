from datetime import datetime
from typing import Literal

from pydantic import BaseModel

HotspotLevel = Literal["green", "yellow", "red"]


class FeedItemResponse(BaseModel):
    id: str
    title: str
    category: str
    summary: str
    country: str | None
    region: str | None
    created_at: datetime


class TrendingCategory(BaseModel):
    category: str
    label: str
    score: float
    report_count: int


class RegionHotspot(BaseModel):
    region: str
    level: HotspotLevel
    report_count: int
    top_category: str | None


class CountryHotspot(BaseModel):
    """Country-level rollup, so the map still means something before a single
    market has enough reports to fill its own regions."""

    country: str
    country_name: str
    level: HotspotLevel
    report_count: int
    top_category: str | None


class TrendingFeedResponse(BaseModel):
    generated_at: datetime
    window_days: int
    country: str | None
    region_label: str | None
    trending_categories: list[TrendingCategory]
    hotspots: list[RegionHotspot]
    country_hotspots: list[CountryHotspot]
    method_note: str = (
        "Computed with weighted rules (report count x recency x reporter trust). "
        "Not an AI/ML model."
    )
