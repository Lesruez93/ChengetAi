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
    def list_number_reputations(self) -> list[PhoneNumber]: ...
    def list_feed_items(self) -> list[FeedItem]: ...
    def save_sentinel_job(self, job: SentinelJob) -> SentinelJob: ...
    def list_sentinel_jobs(self) -> list[SentinelJob]: ...


class InMemoryStore:
    def __init__(self, seed: bool = True) -> None:
        self._reports: list[Report] = []
        self._feed_items: list[FeedItem] = []
        self._sentinel_jobs: list[SentinelJob] = []
        if seed:
            self._seed()

    def _seed(self) -> None:
        """Seed across several markets, not one.

        A demo seeded only with Zimbabwean reports would make every
        cross-country view look broken — the country hotspot map would show one
        row with data and six empty, and a reviewer opening the Kenyan view
        would see an empty product. Spreading the seed shows the regional shape
        the product is actually for, and exercises the country-scoping paths
        that a single-country seed never touches.
        """
        now = datetime.now(timezone.utc)
        seed_reports = [
            # Zimbabwe — the wrong-deposit pattern, repeated from one number
            Report(msisdn="+263771234567", country="ZW", category="mobile_money_reversal",
                   region="Harare", message_excerpt="Wrong deposit, please reverse to [number]",
                   reporter_trust=1.4, created_at=now - timedelta(days=1)),
            Report(msisdn="+263771234567", country="ZW", category="mobile_money_reversal",
                   region="Harare", message_excerpt="Confirmed. You have received [redacted]...",
                   reporter_trust=1.0, created_at=now - timedelta(hours=6)),
            Report(msisdn="+263771234567", country="ZW", category="mobile_money_reversal",
                   region="Harare", message_excerpt="I sent money to your number by accident...",
                   reporter_trust=1.0, created_at=now - timedelta(hours=2)),
            Report(msisdn="+263782345678", country="ZW", category="fake_job", region="Bulawayo",
                   message_excerpt="Congratulations! Shortlisted for remote job...",
                   reporter_trust=1.2, created_at=now - timedelta(hours=10)),
            Report(msisdn="+263714567890", country="ZW", category="faith_seed", region="Manicaland",
                   message_excerpt="Sow a seed today...", reporter_trust=1.1,
                   created_at=now - timedelta(hours=20)),
            # Kenya — M-PESA reversal and a SIM swap wave
            Report(msisdn="+254712345678", country="KE", category="mobile_money_reversal",
                   region="Nairobi", message_excerpt="I sent you money by mistake, please send it back",
                   reporter_trust=1.3, created_at=now - timedelta(hours=4)),
            Report(msisdn="+254712345678", country="KE", category="mobile_money_reversal",
                   region="Nairobi", message_excerpt="Please return the M-PESA sent in error",
                   reporter_trust=1.0, created_at=now - timedelta(hours=9)),
            Report(msisdn="+254733221100", country="KE", category="sim_swap", region="Central",
                   message_excerpt="Your line will be deactivated, confirm your ID to re-register",
                   reporter_trust=1.0, created_at=now - timedelta(days=2)),
            # Nigeria — BVN phishing, and a number also active in Ghana
            Report(msisdn="+2348031234567", country="NG", category="otp_phishing", region="Lagos",
                   message_excerpt="Your BVN is due for revalidation, click [link]",
                   reporter_trust=1.5, created_at=now - timedelta(hours=3)),
            Report(msisdn="+2348031234567", country="NG", category="impersonation", region="Lagos",
                   message_excerpt="This is your bank's fraud desk, call [number]",
                   reporter_trust=1.2, created_at=now - timedelta(hours=8)),
            Report(msisdn="+2348031234567", country="NG", category="fake_investment",
                   region="FCT Abuja", message_excerpt="Double your capital in 24hrs, last slots",
                   reporter_trust=0.9, created_at=now - timedelta(days=1)),
            # South Africa — grant scam, the dominant local pattern
            Report(msisdn="+27821234567", country="ZA", category="fake_loan_aid", region="Gauteng",
                   message_excerpt="Your grant application is approved, pay [redacted] to release",
                   reporter_trust=1.1, created_at=now - timedelta(hours=14)),
            Report(msisdn="+27821234567", country="ZA", category="fake_loan_aid",
                   region="KwaZulu-Natal", message_excerpt="Grant pending, activation fee required",
                   reporter_trust=1.0, created_at=now - timedelta(days=2)),
            # Uganda and Ghana — thinner, so the map shows a realistic gradient
            Report(msisdn="+256772345678", country="UG", category="fake_job", region="Central",
                   message_excerpt="Pay processing fee to confirm your placement",
                   reporter_trust=1.0, created_at=now - timedelta(hours=30)),
            Report(msisdn="+233241234567", country="GH", category="mobile_money_reversal",
                   region="Greater Accra", message_excerpt="MoMo sent by mistake, kindly reverse",
                   reporter_trust=1.0, created_at=now - timedelta(hours=18)),
        ]
        self._reports.extend(seed_reports)

        self._feed_items.extend([
            FeedItem(title="Wrong-deposit reversal scams surge across East and Southern Africa",
                     category="mobile_money_reversal",
                     summary="Reports from four markets describe the same script: a small or fake "
                              "deposit notice, then pressure to 'reverse' money to a different "
                              "number. Check your real balance in the wallet app, not the SMS.",
                     country=None, created_at=now - timedelta(hours=5)),
            FeedItem(title="BVN revalidation phishing targeting Nigerian bank customers",
                     category="otp_phishing",
                     summary="SMS impersonating major banks asks customers to revalidate their BVN "
                              "through a link within 24 hours. No Nigerian bank revalidates a BVN "
                              "by SMS link.",
                     country="NG", region="Lagos", created_at=now - timedelta(hours=7)),
            FeedItem(title="SIM re-registration scams reported in Kenya",
                     category="sim_swap",
                     summary="Messages claiming your line will be deactivated unless you confirm "
                              "your ID are a pretext for SIM swap. Confirm any re-registration "
                              "requirement with your operator directly.",
                     country="KE", created_at=now - timedelta(days=1)),
            FeedItem(title="Grant approval scams asking for a release fee in South Africa",
                     category="fake_loan_aid",
                     summary="Messages announce an approved grant and request an activation or "
                              "release fee. No genuine grant requires payment to be released.",
                     country="ZA", region="Gauteng", created_at=now - timedelta(days=2)),
            FeedItem(title="Fake remote job offers targeting job seekers",
                     category="fake_job",
                     summary="Scammers posing as well-known employers request 'registration fees' "
                              "for remote jobs that do not exist. No legitimate employer charges "
                              "you to be hired.",
                     country=None, created_at=now - timedelta(days=3)),
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
        countries: dict[str, int] = {}
        for r in reports:
            categories[r.category] = categories.get(r.category, 0) + 1
            countries[r.country] = countries.get(r.country, 0) + 1
        last = max((r.created_at for r in reports), default=None)
        # The number's home country is the one it was most reported from, which
        # is not always the one it is registered in — a number dialling into
        # three markets belongs, for our purposes, to the market it harms most.
        home = max(countries, key=lambda c: countries[c]) if countries else ""
        return PhoneNumber(
            msisdn=msisdn,
            country=home,
            report_count=len(reports),
            categories=categories,
            countries=countries,
            last_reported_at=last,
            is_publicly_flagged=len(reports) >= get_settings().number_public_flag_threshold,
        )

    def list_number_reputations(self) -> list[PhoneNumber]:
        msisdns = {r.msisdn for r in self._reports}
        numbers = [self.upsert_number_reputation(m) for m in msisdns]
        return sorted(numbers, key=lambda n: n.report_count, reverse=True)

    # -- feed --
    def list_feed_items(self) -> list[FeedItem]:
        return sorted(self._feed_items, key=lambda f: f.created_at, reverse=True)

    # -- sentinel --
    def save_sentinel_job(self, job: SentinelJob) -> SentinelJob:
        self._sentinel_jobs.append(job)
        return job

    def list_sentinel_jobs(self) -> list[SentinelJob]:
        return sorted(self._sentinel_jobs, key=lambda j: j.created_at, reverse=True)


@lru_cache
def get_store() -> Store:
    settings = get_settings()
    if settings.use_supabase and settings.supabase_url:
        from app.services.supabase_store import SupabaseStore  # local import: optional dependency path

        return SupabaseStore(settings.supabase_url, settings.supabase_service_role_key)
    return InMemoryStore()
