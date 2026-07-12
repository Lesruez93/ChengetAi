"""Persistence layer behind a small repository interface.

Two implementations exist behind the same `Store` protocol:

- `InMemoryStore`: the default in dev/test and in this challenge environment,
  since it makes the API and its test suite runnable with zero external
  services. It is seeded with a handful of realistic reports/feed items so
  the demo screens are never empty.
- `SupabaseStore`: talks to Postgres via supabase-py, using the schema in
  sample_data/seed.sql. Selected automatically when USE_SUPABASE=true and
  credentials are present (see app/config.py). Row Level Security policies
  live in sample_data/seed.sql; this class assumes they already permit the
  service-role key it is constructed with.

Swapping stores never touches router or service code above this module.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone
from functools import lru_cache
from typing import Protocol

from app.config import get_settings
from app.models.domain import FeedItem, PhoneNumber, Report, SentinelJob


class Store(Protocol):
    def add_report(self, report: Report) -> Report: ...
    def list_reports(self, since: datetime | None = None) -> list[Report]: ...
    def reports_for_msisdn(self, msisdn: str) -> list[Report]: ...
    def reports_by_reporter_since(self, reporter_id: str, since: datetime) -> list[Report]: ...
    def upsert_number_reputation(self, msisdn: str) -> PhoneNumber: ...
    def list_feed_items(self) -> list[FeedItem]: ...
    def save_sentinel_job(self, job: SentinelJob) -> SentinelJob: ...


class InMemoryStore:
    def __init__(self, seed: bool = True) -> None:
        self._reports: list[Report] = []
        self._feed_items: list[FeedItem] = []
        self._sentinel_jobs: list[SentinelJob] = []
        if seed:
            self._seed()

    def _seed(self) -> None:
        now = datetime.now(timezone.utc)
        seed_reports = [
            Report(msisdn="0771234567", category="ecocash_reversal", province="Harare",
                   message_excerpt="Wrong deposit, please reverse...", reporter_trust=1.4,
                   created_at=now - timedelta(days=1)),
            Report(msisdn="0771234567", category="ecocash_reversal", province="Harare",
                   message_excerpt="Confirmed. You have received $80...", reporter_trust=1.0,
                   created_at=now - timedelta(hours=6)),
            Report(msisdn="0782345678", category="fake_job", province="Bulawayo",
                   message_excerpt="Congratulations! Shortlisted for remote job...", reporter_trust=1.2,
                   created_at=now - timedelta(hours=10)),
            Report(msisdn="0733456789", category="fake_forex", province="Harare",
                   message_excerpt="Best USD to ZWL rate today...", reporter_trust=0.8,
                   created_at=now - timedelta(days=2)),
            Report(msisdn="0771234567", category="ecocash_reversal", province="Harare",
                   message_excerpt="Ndakutumira mari neaccident...", reporter_trust=1.0,
                   created_at=now - timedelta(hours=2)),
            Report(msisdn="0714567890", category="church_prophet", province="Manicaland",
                   message_excerpt="Sow a seed of $20 today...", reporter_trust=1.1,
                   created_at=now - timedelta(hours=20)),
            Report(msisdn="0755678901", category="fake_loan_ngo", province="Masvingo",
                   message_excerpt="You qualify for a $2000 loan...", reporter_trust=0.9,
                   created_at=now - timedelta(days=3)),
        ]
        self._reports.extend(seed_reports)

        self._feed_items.extend([
            FeedItem(title="EcoCash 'wrong transfer' scams surge in Harare",
                     category="ecocash_reversal",
                     summary="Multiple reports of scammers sending small deposits then asking victims "
                              "to 'reverse' money to a different number, keeping the original deposit.",
                     province="Harare", created_at=now - timedelta(hours=5)),
            FeedItem(title="Fake remote job offers targeting job seekers",
                     category="fake_job",
                     summary="Scammers posing as Econet/Delta HR are requesting 'registration fees' "
                              "for non-existent remote jobs.",
                     province=None, created_at=now - timedelta(days=1)),
            FeedItem(title="Forex bureau impersonation scams in the CBD",
                     category="fake_forex",
                     summary="Reports of fake forex dealers asking victims to send USD first "
                              "'for verification' before disappearing.",
                     province="Harare", created_at=now - timedelta(days=2)),
        ])

    # -- reports --
    def add_report(self, report: Report) -> Report:
        self._reports.append(report)
        return report

    def list_reports(self, since: datetime | None = None) -> list[Report]:
        if since is None:
            return list(self._reports)
        return [r for r in self._reports if r.created_at >= since]

    def reports_for_msisdn(self, msisdn: str) -> list[Report]:
        return [r for r in self._reports if r.msisdn == msisdn]

    def reports_by_reporter_since(self, reporter_id: str, since: datetime) -> list[Report]:
        return [r for r in self._reports if r.reporter_id == reporter_id and r.created_at >= since]

    # -- number reputation (derived from reports, not separately stored) --
    def upsert_number_reputation(self, msisdn: str) -> PhoneNumber:
        reports = self.reports_for_msisdn(msisdn)
        categories: dict[str, int] = {}
        for r in reports:
            categories[r.category] = categories.get(r.category, 0) + 1
        last = max((r.created_at for r in reports), default=None)
        return PhoneNumber(
            msisdn=msisdn,
            report_count=len(reports),
            categories=categories,
            last_reported_at=last,
            is_publicly_flagged=len(reports) >= get_settings().number_public_flag_threshold,
        )

    # -- feed --
    def list_feed_items(self) -> list[FeedItem]:
        return sorted(self._feed_items, key=lambda f: f.created_at, reverse=True)

    # -- sentinel --
    def save_sentinel_job(self, job: SentinelJob) -> SentinelJob:
        self._sentinel_jobs.append(job)
        return job


@lru_cache
def get_store() -> Store:
    settings = get_settings()
    if settings.use_supabase and settings.supabase_url:
        from app.services.supabase_store import SupabaseStore  # local import: optional dependency path

        return SupabaseStore(settings.supabase_url, settings.supabase_service_role_key)
    return InMemoryStore()
