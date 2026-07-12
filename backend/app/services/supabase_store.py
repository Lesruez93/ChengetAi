"""Supabase/Postgres-backed implementation of the Store protocol.

Only imported when USE_SUPABASE=true (see app/services/store.get_store), so
the supabase-py dependency is never required to run the API against the
in-memory store used in dev/test. Table shapes match sample_data/seed.sql.
"""

from __future__ import annotations

from datetime import datetime

from supabase import Client, create_client

from app.models.domain import FeedItem, PhoneNumber, Report, SentinelJob


def _row_to_report(row: dict) -> Report:
    return Report(
        id=row["id"],
        msisdn=row["msisdn"],
        category=row["category"],
        province=row["province"],
        message_excerpt=row.get("message_excerpt", ""),
        reporter_id=row.get("reporter_id"),
        reporter_trust=row.get("reporter_trust", 1.0),
        created_at=datetime.fromisoformat(row["created_at"]),
    )


class SupabaseStore:
    def __init__(self, url: str, service_role_key: str) -> None:
        self.client: Client = create_client(url, service_role_key)

    def add_report(self, report: Report) -> Report:
        self.client.table("reports").insert({
            "id": report.id,
            "msisdn": report.msisdn,
            "category": report.category,
            "province": report.province,
            "message_excerpt": report.message_excerpt,
            "reporter_id": report.reporter_id,
            "reporter_trust": report.reporter_trust,
            "created_at": report.created_at.isoformat(),
        }).execute()
        return report

    def list_reports(self, since: datetime | None = None) -> list[Report]:
        query = self.client.table("reports").select("*")
        if since is not None:
            query = query.gte("created_at", since.isoformat())
        rows = query.execute().data or []
        return [_row_to_report(r) for r in rows]

    def reports_for_msisdn(self, msisdn: str) -> list[Report]:
        rows = self.client.table("reports").select("*").eq("msisdn", msisdn).execute().data or []
        return [_row_to_report(r) for r in rows]

    def reports_by_reporter_since(self, reporter_id: str, since: datetime) -> list[Report]:
        rows = (
            self.client.table("reports")
            .select("*")
            .eq("reporter_id", reporter_id)
            .gte("created_at", since.isoformat())
            .execute()
            .data or []
        )
        return [_row_to_report(r) for r in rows]

    def upsert_number_reputation(self, msisdn: str) -> PhoneNumber:
        from app.config import get_settings

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

    def list_number_reputations(self) -> list[PhoneNumber]:
        # Computed live from `reports`, the same way upsert_number_reputation is, rather than
        # read from the `numbers` cache table, since nothing currently writes that table on
        # report insert (it exists in the schema for a future write-behind cache).
        all_reports = self.list_reports()
        msisdns = {r.msisdn for r in all_reports}
        numbers = [self.upsert_number_reputation(m) for m in msisdns]
        return sorted(numbers, key=lambda n: n.report_count, reverse=True)

    def list_feed_items(self) -> list[FeedItem]:
        rows = (
            self.client.table("feed_items").select("*").order("created_at", desc=True).execute().data or []
        )
        return [
            FeedItem(
                id=r["id"], title=r["title"], category=r["category"], summary=r["summary"],
                province=r.get("province"), created_at=datetime.fromisoformat(r["created_at"]),
            )
            for r in rows
        ]

    def save_sentinel_job(self, job: SentinelJob) -> SentinelJob:
        self.client.table("sentinel_jobs").insert({
            "id": job.id,
            "filename": job.filename,
            "n_transactions": job.n_transactions,
            "n_flagged": job.n_flagged,
            "created_at": job.created_at.isoformat(),
        }).execute()
        return job

    def list_sentinel_jobs(self) -> list[SentinelJob]:
        rows = (
            self.client.table("sentinel_jobs").select("*").order("created_at", desc=True).execute().data or []
        )
        return [
            SentinelJob(
                id=r["id"], filename=r["filename"], n_transactions=r.get("n_transactions", 0),
                n_flagged=r.get("n_flagged", 0), created_at=datetime.fromisoformat(r["created_at"]),
            )
            for r in rows
        ]
