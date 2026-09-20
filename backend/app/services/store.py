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
        """Seed every supported market, not one.

        A demo seeded only with Zimbabwean reports would make every
        cross-country view look broken — the country hotspot map would show one
        row with data and six empty, and a reviewer opening the Kenyan view
        would see an empty product. Spreading the seed shows the regional shape
        the product is actually for, and exercises the country-scoping paths
        that a single-country seed never touches.

        Every code in `services/countries.py` gets reports here, and
        `tests/test_store_seed.py` enforces that: a market that ships with a
        country registry entry, support contacts and a picker entry but no data
        behind them reads, to anyone opening it, as a broken product rather
        than a quiet one.

        Volume still varies by market deliberately. A flat seed would imply
        seven equally-mature markets, which is not the deployment story
        (docs/deployment_plan.md sequences markets rather than launching them
        together); the gradient also gives the hotspot map something other than
        a uniform block to render.

        Two properties here are load-bearing for paths nothing else exercises:
        at least one number per major market clears
        NUMBER_PUBLIC_FLAG_THRESHOLD, and one number is reported from two
        countries, so `upsert_number_reputation`'s cross-border `countries`
        tally and "home market" pick are covered by seeded data.
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
            Report(msisdn="+263733445566", country="ZW", category="otp_phishing", region="Midlands",
                   message_excerpt="EcoCash security check: confirm the code sent to you",
                   reporter_trust=1.2, created_at=now - timedelta(hours=26)),
            # Zimbabwe — the fixture the call-screening flow is demoed against.
            # Three distinct categories, so `risk_level_for` returns "high" on
            # category diversity rather than volume, and four reports clears
            # NUMBER_PUBLIC_FLAG_THRESHOLD. Both matter: the incoming-call
            # banner only warns on a publicly flagged number, so a fixture
            # sitting one report below the threshold would show nothing and
            # look like a broken integration.
            Report(msisdn="+263710423555", country="ZW", category="mobile_money_reversal",
                   region="Harare", message_excerpt="Wrong deposit, reverse to [number] urgently",
                   reporter_trust=1.4, created_at=now - timedelta(hours=3)),
            Report(msisdn="+263710423555", country="ZW", category="otp_phishing", region="Harare",
                   message_excerpt="EcoCash agent here, read me the code to reverse it",
                   reporter_trust=1.3, created_at=now - timedelta(hours=11)),
            Report(msisdn="+263710423555", country="ZW", category="impersonation",
                   region="Bulawayo", message_excerpt="Calling from the EcoCash fraud desk",
                   reporter_trust=1.2, created_at=now - timedelta(hours=19)),
            Report(msisdn="+263710423555", country="ZW", category="mobile_money_reversal",
                   region="Harare", message_excerpt="I will send police if you don't reverse it",
                   reporter_trust=1.0, created_at=now - timedelta(days=1)),
            # Kenya — M-PESA reversal spreading beyond Nairobi, plus a SIM swap wave
            Report(msisdn="+254712345678", country="KE", category="mobile_money_reversal",
                   region="Nairobi", message_excerpt="I sent you money by mistake, please send it back",
                   reporter_trust=1.3, created_at=now - timedelta(hours=4)),
            Report(msisdn="+254712345678", country="KE", category="mobile_money_reversal",
                   region="Nairobi", message_excerpt="Please return the M-PESA sent in error",
                   reporter_trust=1.0, created_at=now - timedelta(hours=9)),
            Report(msisdn="+254712345678", country="KE", category="mobile_money_reversal",
                   region="Coast", message_excerpt="Reverse the M-PESA to [number], wrong recipient",
                   reporter_trust=1.1, created_at=now - timedelta(hours=16)),
            Report(msisdn="+254733221100", country="KE", category="sim_swap", region="Central",
                   message_excerpt="Your line will be deactivated, confirm your ID to re-register",
                   reporter_trust=1.0, created_at=now - timedelta(days=2)),
            Report(msisdn="+254110998877", country="KE", category="fake_investment",
                   region="Nairobi", message_excerpt="Guaranteed 40% weekly returns, slots closing",
                   reporter_trust=0.9, created_at=now - timedelta(hours=21)),
            # Nigeria — BVN phishing from a number that is also working Ghana
            Report(msisdn="+2348031234567", country="NG", category="otp_phishing", region="Lagos",
                   message_excerpt="Your BVN is due for revalidation, click [link]",
                   reporter_trust=1.5, created_at=now - timedelta(hours=3)),
            Report(msisdn="+2348031234567", country="NG", category="impersonation", region="Lagos",
                   message_excerpt="This is your bank's fraud desk, call [number]",
                   reporter_trust=1.2, created_at=now - timedelta(hours=8)),
            Report(msisdn="+2348031234567", country="NG", category="fake_investment",
                   region="FCT Abuja", message_excerpt="Double your capital in 24hrs, last slots",
                   reporter_trust=0.9, created_at=now - timedelta(days=1)),
            Report(msisdn="+2349021112233", country="NG", category="fake_loan_aid",
                   region="South West", message_excerpt="Loan approved, pay [redacted] insurance fee",
                   reporter_trust=1.0, created_at=now - timedelta(hours=33)),
            # South Africa — grant scams, the dominant local pattern, plus SIM swap
            Report(msisdn="+27821234567", country="ZA", category="fake_loan_aid", region="Gauteng",
                   message_excerpt="Your grant application is approved, pay [redacted] to release",
                   reporter_trust=1.1, created_at=now - timedelta(hours=14)),
            Report(msisdn="+27821234567", country="ZA", category="fake_loan_aid",
                   region="KwaZulu-Natal", message_excerpt="Grant pending, activation fee required",
                   reporter_trust=1.0, created_at=now - timedelta(days=2)),
            Report(msisdn="+27821234567", country="ZA", category="fake_loan_aid",
                   region="Eastern Cape", message_excerpt="Final notice: clearance fee to release grant",
                   reporter_trust=1.0, created_at=now - timedelta(hours=40)),
            Report(msisdn="+27761122334", country="ZA", category="sim_swap", region="Western Cape",
                   message_excerpt="SIM upgrade required, reply with the code to keep your line",
                   reporter_trust=1.1, created_at=now - timedelta(hours=29)),
            # Uganda — MoMo reversal and recruitment fees
            Report(msisdn="+256772345678", country="UG", category="fake_job", region="Central",
                   message_excerpt="Pay processing fee to confirm your placement",
                   reporter_trust=1.0, created_at=now - timedelta(hours=30)),
            Report(msisdn="+256701234567", country="UG", category="mobile_money_reversal",
                   region="Western", message_excerpt="MTN MoMo sent to you in error, please send back",
                   reporter_trust=1.0, created_at=now - timedelta(hours=35)),
            Report(msisdn="+256752233445", country="UG", category="otp_phishing", region="Eastern",
                   message_excerpt="Airtel Money verification: share the PIN sent to [number]",
                   reporter_trust=1.1, created_at=now - timedelta(hours=44)),
            # Ghana — MoMo reversal, and the Nigerian number reported here too
            Report(msisdn="+233241234567", country="GH", category="mobile_money_reversal",
                   region="Greater Accra", message_excerpt="MoMo sent by mistake, kindly reverse",
                   reporter_trust=1.0, created_at=now - timedelta(hours=18)),
            Report(msisdn="+233241234567", country="GH", category="mobile_money_reversal",
                   region="Ashanti", message_excerpt="Please return the MoMo, it was the wrong number",
                   reporter_trust=1.0, created_at=now - timedelta(hours=38)),
            Report(msisdn="+233501122334", country="GH", category="impersonation",
                   region="Greater Accra",
                   message_excerpt="MTN support here, your wallet is locked, call [number]",
                   reporter_trust=1.2, created_at=now - timedelta(hours=27)),
            # The same Nigerian line, worked across the border — the only seeded
            # number whose reputation spans two markets.
            Report(msisdn="+2348031234567", country="GH", category="otp_phishing",
                   region="Greater Accra",
                   message_excerpt="Bank verification required, click [link] to confirm",
                   reporter_trust=1.0, created_at=now - timedelta(hours=12)),
            # Tanzania — reversal script in Dar, spreading up the coast
            Report(msisdn="+255754112233", country="TZ", category="mobile_money_reversal",
                   region="Dar es Salaam",
                   message_excerpt="M-Pesa sent to you by accident, please reverse to [number]",
                   reporter_trust=1.2, created_at=now - timedelta(hours=7)),
            Report(msisdn="+255754112233", country="TZ", category="mobile_money_reversal",
                   region="Coastal", message_excerpt="Wrong transfer, kindly send it back today",
                   reporter_trust=1.0, created_at=now - timedelta(hours=23)),
            Report(msisdn="+255682233445", country="TZ", category="fake_investment",
                   region="Northern", message_excerpt="Forex platform, capital doubled in 48hrs",
                   reporter_trust=0.9, created_at=now - timedelta(hours=31)),
            Report(msisdn="+255715566778", country="TZ", category="sim_swap", region="Lake",
                   message_excerpt="Line registration expiring, confirm your ID to avoid blocking",
                   reporter_trust=1.0, created_at=now - timedelta(days=2)),
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
            FeedItem(title="Reversal requests spreading from Dar es Salaam along the coast",
                     category="mobile_money_reversal",
                     summary="Reports describe an M-Pesa or Mixx notice followed by a call "
                              "pressuring you to send the money back. Check the balance in the "
                              "wallet menu before returning anything.",
                     country="TZ", region="Dar es Salaam", created_at=now - timedelta(hours=11)),
            FeedItem(title="Callers posing as MoMo support in Greater Accra",
                     category="impersonation",
                     summary="Callers claiming to be MTN or Telecel support say your wallet is "
                              "locked and ask you to call back on a number they supply. Use the "
                              "short code printed by your provider instead.",
                     country="GH", region="Greater Accra", created_at=now - timedelta(hours=16)),
            FeedItem(title="Placement-fee job scams reported across Uganda",
                     category="fake_job",
                     summary="Messages offering a confirmed placement ask for a processing fee by "
                              "MoMo before any interview. A fee charged before work is the scam, "
                              "whatever employer is named.",
                     country="UG", created_at=now - timedelta(hours=34)),
            FeedItem(title="Callers posing as the EcoCash fraud desk in Harare",
                     category="impersonation",
                     summary="Callers claiming to be an EcoCash agent or fraud desk press you to "
                              "read back a code to 'reverse' a deposit you never received. No "
                              "agent ever needs your code or PIN.",
                     country="ZW", region="Harare", created_at=now - timedelta(hours=9)),
            FeedItem(title="SIM re-registration and upgrade pretexts in South Africa",
                     category="sim_swap",
                     summary="A 'SIM upgrade' or re-registration request that asks for a code is "
                              "an attempt to take over the number your banking OTPs arrive on. "
                              "If your line goes dead, treat it as urgent.",
                     country="ZA", region="Western Cape", created_at=now - timedelta(hours=30)),
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
