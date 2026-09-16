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


def _now() -> datetime:
    return datetime.now(timezone.utc)


def _uuid() -> str:
    return str(uuid4())


@dataclass
class Report:
    """A community report against a phone number, tied to a scam category.

    `msisdn` is always stored in E.164 form (+254712345678), never in the local
    0-prefixed form. Across seven countries the local forms collide outright —
    0771234567 is a valid Zimbabwean, Ugandan and Tanzanian number — so a
    national-format key would silently merge three different people's
    reputations into one record.
    """

    id: str = field(default_factory=_uuid)
    msisdn: str = ""                 # E.164, e.g. "+263771234567"
    country: str = "ZW"              # ISO 3166-1 alpha-2, see services/countries.py
    category: str = "other"          # see services/taxonomy.py
    region: str = ""                 # first-level unit, meaning set by the country
    message_excerpt: str = ""        # redacted before storage, see services/redaction.py
    reporter_id: str | None = None   # None for an anonymous report
    reporter_trust: float = 1.0      # 0.0-2.0, higher = more weight
    created_at: datetime = field(default_factory=_now)


@dataclass
class PhoneNumber:
    """Aggregated reputation record for an MSISDN, derived from its reports."""

    msisdn: str
    country: str = ""
    report_count: int = 0
    categories: dict[str, int] = field(default_factory=dict)
    countries: dict[str, int] = field(default_factory=dict)  # where it was reported from
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
    country: str | None = None       # None = relevant across every market
    region: str | None = None
    created_at: datetime = field(default_factory=_now)


@dataclass
class SentinelJob:
    id: str = field(default_factory=_uuid)
    filename: str = ""
    country: str = ""
    n_transactions: int = 0
    n_flagged: int = 0
    created_at: datetime = field(default_factory=_now)
