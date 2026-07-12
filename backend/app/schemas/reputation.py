from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ReportCreate(BaseModel):
    msisdn: str = Field(..., min_length=9, max_length=13, description="Zimbabwean MSISDN, e.g. 0771234567")
    category: str = Field(..., description="Scam category, e.g. ecocash_reversal, fake_job")
    province: str = "Harare"
    message_excerpt: str = Field("", max_length=1000)
    reporter_id: str | None = None


class ReportResponse(BaseModel):
    id: str
    msisdn: str
    category: str
    province: str
    created_at: datetime
    status: Literal["recorded", "duplicate_collapsed", "rate_limited"]


class NumberReputationResponse(BaseModel):
    msisdn: str
    report_count: int
    categories: dict[str, int]
    last_reported_at: datetime | None
    is_publicly_flagged: bool
    risk_level: Literal["unknown", "low", "medium", "high"]


class ReportListItem(BaseModel):
    """A single report, for the admin moderation queue (GET /reports)."""

    id: str
    msisdn: str
    category: str
    province: str
    message_excerpt: str
    reporter_id: str | None
    reporter_trust: float
    created_at: datetime
