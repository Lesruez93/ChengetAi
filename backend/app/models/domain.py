"""Internal domain records, mirroring the Supabase Postgres schema in
sample_data/seed.sql. Kept as plain dataclasses so both the in-memory store
(app/services/store.py) and a future Supabase-backed store can share the
same shape without pulling pydantic's validation/serialization overhead
into internal storage.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone
from uuid import uuid4

ZIMBABWE_PROVINCES = [
    "Harare", "Bulawayo", "Manicaland", "Mashonaland Central",
    "Mashonaland East", "Mashonaland West", "Masvingo",
    "Matabeleland North", "Matabeleland South", "Midlands",
]


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _uuid() -> str:
    return str(uuid4())


@dataclass
class Report:
    """A community report against a phone number, tied to a scam category."""

    id: str = field(default_factory=_uuid)
    msisdn: str = ""
    category: str = "other"          # e.g. ecocash_reversal, fake_job, fake_forex...
    province: str = "Harare"
    message_excerpt: str = ""
    reporter_id: str | None = None
    reporter_trust: float = 1.0      # 0.0-2.0, higher = more weight
    created_at: datetime = field(default_factory=_now)


@dataclass
class PhoneNumber:
    """Aggregated reputation record for an MSISDN, derived from its reports."""

    msisdn: str
    report_count: int = 0
    categories: dict[str, int] = field(default_factory=dict)
    last_reported_at: datetime | None = None
    is_publicly_flagged: bool = False


@dataclass
class ScamSample:
    text: str
    label: str          # "scam" | "legit"
    category: str = "other"


@dataclass
class FeedItem:
    id: str = field(default_factory=_uuid)
    title: str = ""
    category: str = "other"
    summary: str = ""
    province: str | None = None
    created_at: datetime = field(default_factory=_now)


@dataclass
class SentinelJob:
    id: str = field(default_factory=_uuid)
    filename: str = ""
    n_transactions: int = 0
    n_flagged: int = 0
    created_at: datetime = field(default_factory=_now)
