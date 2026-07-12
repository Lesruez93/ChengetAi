"""Number reputation: report intake with abuse controls, plus lookup.

This module is deliberately *not* AI — it is plain CRUD and weighted-rules
aggregation. Risk level and the "publicly flagged" bit are both a function
of report volume, category diversity, and reporter trust, not a model.

Abuse controls, since a reputation system that anyone can spam is a
defamation and reliability risk (see docs/architecture.md):
- rate limiting: a reporter is capped at REPORT_RATE_LIMIT_PER_HOUR reports/hour
- duplicate collapse: the same reporter re-reporting the same number for the
  same category within the window is recorded but does not add extra weight
- public flagging threshold: a number is only surfaced as "publicly flagged"
  once it clears NUMBER_PUBLIC_FLAG_THRESHOLD reports, so a single hostile
  report can't brand a number a scammer.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

from app.config import get_settings
from app.models.domain import PhoneNumber, Report
from app.schemas.reputation import NumberReputationResponse, ReportCreate, ReportResponse
from app.services.store import Store

MSISDN_RE = re.compile(r"^0\d{9}$")


class ValidationError(ValueError):
    pass


def normalize_msisdn(raw: str) -> str:
    digits = re.sub(r"\D", "", raw)
    if digits.startswith("263"):
        digits = "0" + digits[3:]
    if not MSISDN_RE.match(digits):
        raise ValidationError(f"'{raw}' is not a valid Zimbabwean mobile number.")
    return digits


def submit_report(store: Store, payload: ReportCreate) -> ReportResponse:
    settings = get_settings()
    msisdn = normalize_msisdn(payload.msisdn)
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(hours=1)

    if payload.reporter_id:
        recent = store.reports_by_reporter_since(payload.reporter_id, window_start)
        if len(recent) >= settings.report_rate_limit_per_hour:
            report = Report(msisdn=msisdn, category=payload.category, province=payload.province,
                             message_excerpt=payload.message_excerpt, reporter_id=payload.reporter_id,
                             created_at=now)
            return ReportResponse(id=report.id, msisdn=msisdn, category=report.category,
                                   province=report.province, created_at=report.created_at,
                                   status="rate_limited")

        duplicate_window = now - timedelta(hours=24)
        duplicates = [
            r for r in store.reports_by_reporter_since(payload.reporter_id, duplicate_window)
            if r.msisdn == msisdn and r.category == payload.category
        ]
        if duplicates:
            report = store.add_report(Report(
                msisdn=msisdn, category=payload.category, province=payload.province,
                message_excerpt=payload.message_excerpt, reporter_id=payload.reporter_id,
                reporter_trust=0.0, created_at=now,
            ))
            return ReportResponse(id=report.id, msisdn=msisdn, category=report.category,
                                   province=report.province, created_at=report.created_at,
                                   status="duplicate_collapsed")

    report = store.add_report(Report(
        msisdn=msisdn, category=payload.category, province=payload.province,
        message_excerpt=payload.message_excerpt, reporter_id=payload.reporter_id,
        created_at=now,
    ))
    return ReportResponse(id=report.id, msisdn=msisdn, category=report.category,
                           province=report.province, created_at=report.created_at, status="recorded")


def _risk_level(number: PhoneNumber) -> str:
    if number.report_count == 0:
        return "unknown"
    if number.report_count >= 6 or len(number.categories) >= 3:
        return "high"
    if number.report_count >= 3:
        return "medium"
    return "low"


def lookup_number(store: Store, raw_msisdn: str) -> NumberReputationResponse:
    msisdn = normalize_msisdn(raw_msisdn)
    number = store.upsert_number_reputation(msisdn)
    return NumberReputationResponse(
        msisdn=number.msisdn,
        report_count=number.report_count,
        categories=number.categories,
        last_reported_at=number.last_reported_at,
        is_publicly_flagged=number.is_publicly_flagged,
        risk_level=_risk_level(number),
    )
