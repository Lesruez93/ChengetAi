from datetime import datetime
from typing import Literal

from pydantic import BaseModel

HotspotLevel = Literal["green", "yellow", "red"]


class FeedItemResponse(BaseModel):
    id: str
    title: str
    category: str
    summary: str
    province: str | None
    created_at: datetime


class TrendingCategory(BaseModel):
    category: str
    score: float
    report_count: int


class ProvinceHotspot(BaseModel):
    province: str
    level: HotspotLevel
    report_count: int
    top_category: str | None


class TrendingFeedResponse(BaseModel):
    generated_at: datetime
    window_days: int
    trending_categories: list[TrendingCategory]
    hotspots: list[ProvinceHotspot]
    method_note: str = (
        "Computed with weighted rules (report count x recency x reporter trust). "
        "Not an AI/ML model."
    )
