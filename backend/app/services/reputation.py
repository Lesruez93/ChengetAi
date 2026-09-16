"""Number reputation: report intake with abuse controls, plus lookup.

This module is deliberately *not* AI — it is plain CRUD and weighted-rules
aggregation. Risk level and the "publicly flagged" bit are both a function of
report volume, category diversity, and reporter trust, not a model.

Abuse controls, since a reputation system that anyone can spam is a defamation
and reliability risk (see docs/architecture.md):
- rate limiting: a reporter is capped at REPORT_RATE_LIMIT_PER_HOUR reports/hour
- duplicate collapse: the same reporter re-reporting the same number for the
  same category within the window is recorded but does not add extra weight
- public flagging threshold: a number is only surfaced as "publicly flagged"
  once it clears NUMBER_PUBLIC_FLAG_THRESHOLD reports, so a single hostile
  report can't brand a number a scammer
- evidence minimisation: excerpts are redacted at intake (services/redaction.py)

Numbers are canonicalised to E.164 on the way in. See `normalize_msisdn` for
why that matters more in a multi-country deployment than a single-country one.
"""

from __future__ import annotations

import re
from datetime import datetime, timedelta, timezone

from app.config import get_settings
from app.models.domain import PhoneNumber, Report
from app.schemas.reputation import NumberReputationResponse, ReportCreate, ReportResponse
from app.services.countries import Country, country_for_dial_code, get_country
from app.services.redaction import redact_excerpt
from app.services.store import Store


class ValidationError(ValueError):
    pass


def _digits(raw: str) -> str:
    return re.sub(r"\D", "", raw or "")


def normalize_msisdn(raw: str, country_code: str | None = None) -> tuple[str, str]:
    """Canonicalise a number to E.164 and resolve which country it belongs to.

    Returns `(e164, country_code)`, e.g. `("+254712345678", "KE")`.

    Three input shapes are accepted, in this order of confidence:

    1. International, with or without '+' ("+254712345678", "254712345678").
       The dial code identifies the country outright, so any `country_code`
       hint is ignored — the number wins over the hint.
    2. Local, trunk-prefixed ("0712345678"). This form is genuinely ambiguous
       across our markets: 0771234567 parses as Zimbabwe, Uganda *and*
       Tanzania. It resolves only against an explicit `country_code` (or the
       DEFAULT_COUNTRY setting), and is validated against that country's
       mobile prefixes and length.
    3. Bare national significant number ("712345678"), same rules as (2).

    Storing the local form instead would quietly merge unrelated people's
    reputations across borders — the failure would be invisible in a
    single-country demo and catastrophic in a regional deployment.
    """
    digits = _digits(raw)
    if not digits:
        raise ValidationError("A phone number is required.")

    explicit_international = (raw or "").strip().startswith("+")

    # (1) International form.
    country = country_for_dial_code(digits)
    if country is not None:
        nsn = digits[len(country.dial_code):]
        if explicit_international or _is_plausible_nsn(country, nsn):
            return _validate_nsn(country, nsn, raw)

    # (2)/(3) Local or bare national form, resolved against the hinted country.
    settings = get_settings()
    resolved = get_country(country_code or settings.default_country)
    nsn = digits
    if resolved.trunk_prefix and nsn.startswith(resolved.trunk_prefix):
        nsn = nsn[len(resolved.trunk_prefix):]
    return _validate_nsn(resolved, nsn, raw)


def _is_plausible_nsn(country: Country, nsn: str) -> bool:
    return len(nsn) == country.nsn_length and nsn.startswith(country.mobile_prefixes)


def _validate_nsn(country: Country, nsn: str, raw: str) -> tuple[str, str]:
    if len(nsn) != country.nsn_length:
        raise ValidationError(
            f"'{raw}' is not a valid {country.name} mobile number — expected "
            f"{country.nsn_length} digits after the country or trunk code "
            f"(for example {country.example_msisdn})."
        )
    if not nsn.startswith(country.mobile_prefixes):
        raise ValidationError(
            f"'{raw}' does not start with a {country.name} mobile prefix "
            f"({', '.join(country.mobile_prefixes)})."
        )
    return f"+{country.dial_code}{nsn}", country.code


def _resolve_region(country: Country, region: str | None) -> str:
    """Fall back to the country's first region rather than rejecting the report.

    A report with an unrecognised region is still worth keeping: the number and
    the category are the parts that protect other people, and the hotspot map
    degrades gracefully with one report in the wrong bucket. Refusing the whole
    report to enforce a dropdown value would lose real signal to a typo.
    """
    if region and region in country.regions:
        return region
    return country.regions[0]


def submit_report(store: Store, payload: ReportCreate) -> ReportResponse:
    settings = get_settings()
    msisdn, country_code = normalize_msisdn(payload.msisdn, payload.country)
    country = get_country(country_code)
    region = _resolve_region(country, payload.region)
    excerpt = redact_excerpt(payload.message_excerpt)
    now = datetime.now(timezone.utc)
    window_start = now - timedelta(hours=1)

    def _build(trust: float = 1.0) -> Report:
        return Report(
            msisdn=msisdn, country=country_code, category=payload.category, region=region,
            message_excerpt=excerpt, reporter_id=payload.reporter_id,
            reporter_trust=trust, created_at=now,
        )

    def _respond(report: Report, status: str) -> ReportResponse:
        return ReportResponse(
            id=report.id, msisdn=report.msisdn, country=report.country,
            category=report.category, region=report.region,
            created_at=report.created_at, status=status,
        )

    # Anonymous reports (reporter_id=None) skip rate limiting and duplicate
    # collapse by design: this is the Safety track's core trade-off. Requiring
    # an identity to report is a barrier exactly for the people most at risk of
    # retaliation, so anonymity is preserved and the abuse controls it costs us
    # are recovered downstream instead — via the public-flag threshold, which
    # no single reporter can clear alone.
    if payload.reporter_id:
        recent = store.reports_by_reporter_since(payload.reporter_id, window_start)
        if len(recent) >= settings.report_rate_limit_per_hour:
            return _respond(_build(), "rate_limited")

        duplicate_window = now - timedelta(hours=24)
        duplicates = [
            r for r in store.reports_by_reporter_since(payload.reporter_id, duplicate_window)
            if r.msisdn == msisdn and r.category == payload.category
        ]
        if duplicates:
            return _respond(store.add_report(_build(trust=0.0)), "duplicate_collapsed")

    return _respond(store.add_report(_build()), "recorded")


def risk_level_for(number: PhoneNumber) -> str:
    if number.report_count == 0:
        return "unknown"
    # A number reported from more than one country is a stronger signal than
    # report volume alone: cross-border reach means an organised operation
    # rather than one local dispute, so it shortcuts straight to "high".
    if number.report_count >= 6 or len(number.categories) >= 3 or len(number.countries) >= 2:
        return "high"
    if number.report_count >= 3:
        return "medium"
    return "low"


def lookup_number(store: Store, raw_msisdn: str, country_code: str | None = None) -> NumberReputationResponse:
    msisdn, resolved_country = normalize_msisdn(raw_msisdn, country_code)
    number = store.upsert_number_reputation(msisdn)
    return NumberReputationResponse(
        msisdn=number.msisdn,
        country=number.country or resolved_country,
        report_count=number.report_count,
        categories=number.categories,
        countries=number.countries,
        last_reported_at=number.last_reported_at,
        is_publicly_flagged=number.is_publicly_flagged,
        risk_level=risk_level_for(number),
    )
