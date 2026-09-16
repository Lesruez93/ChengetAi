from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ReportCreate(BaseModel):
    msisdn: str = Field(
        ..., min_length=6, max_length=20,
        description="The reported number, in international (+254712345678) or local "
                    "(0712345678) form. Local form is resolved against `country`.",
    )
    country: str | None = Field(
        default=None,
        description="ISO 3166-1 alpha-2 country code (ZW, KE, NG, UG, ZA, GH, TZ). "
                    "Required to disambiguate a local-format number; ignored when the "
                    "number is already in international form.",
    )
    category: str = Field(..., description="Scam category, see GET /reference/categories.")
    region: str | None = Field(
        default=None,
        description="First-level administrative unit within the country (province, "
                    "county, state or zone depending on the market).",
    )
    message_excerpt: str = Field("", max_length=1000,
                                 description="Redacted server-side before storage.")
    reporter_id: str | None = Field(
        default=None,
        description="Omit entirely to report anonymously. Anonymous reports are "
                    "accepted and counted, but carry no per-reporter rate limiting.",
    )


class ReportResponse(BaseModel):
    id: str
    msisdn: str
    country: str
    category: str
    region: str
    created_at: datetime
    status: Literal["recorded", "duplicate_collapsed", "rate_limited"]


class NumberReputationResponse(BaseModel):
    msisdn: str
    country: str
    report_count: int
    categories: dict[str, int]
    countries: dict[str, int] = Field(
        default_factory=dict,
        description="Report counts per reporting country. More than one entry means "
                    "the number has cross-border reach.",
    )
    last_reported_at: datetime | None
    is_publicly_flagged: bool
    risk_level: Literal["unknown", "low", "medium", "high"]


class ReportListItem(BaseModel):
    """A single report, for the admin moderation queue (GET /reports)."""

    id: str
    msisdn: str
    country: str
    category: str
    region: str
    message_excerpt: str
    reporter_id: str | None
    reporter_trust: float
    created_at: datetime
