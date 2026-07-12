from fastapi import APIRouter, Depends, HTTPException, Query

from app.messaging.sms import send_report_confirmation
from app.schemas.reputation import (
    NumberReputationResponse,
    ReportCreate,
    ReportListItem,
    ReportResponse,
)
from app.services.reputation import ValidationError, lookup_number, risk_level_for, submit_report
from app.services.store import Store, get_store

router = APIRouter(tags=["numbers"])


@router.get("/numbers", response_model=list[NumberReputationResponse])
def list_flagged_numbers(store: Store = Depends(get_store)) -> list[NumberReputationResponse]:
    """All numbers with at least one report, ranked by report count. Used by the admin
    dashboard's flagged-number review queue."""
    return [
        NumberReputationResponse(
            msisdn=n.msisdn, report_count=n.report_count, categories=n.categories,
            last_reported_at=n.last_reported_at, is_publicly_flagged=n.is_publicly_flagged,
            risk_level=risk_level_for(n),
        )
        for n in store.list_number_reputations()
    ]


@router.get("/numbers/{msisdn}", response_model=NumberReputationResponse)
def get_number_reputation(msisdn: str, store: Store = Depends(get_store)) -> NumberReputationResponse:
    try:
        return lookup_number(store, msisdn)
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@router.post("/reports", response_model=ReportResponse)
def create_report(payload: ReportCreate, store: Store = Depends(get_store)) -> ReportResponse:
    try:
        result = submit_report(store, payload)
    except ValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    if result.status == "recorded" and payload.reporter_id:
        send_report_confirmation(payload.reporter_id, result.msisdn, result.category)
    return result


@router.get("/reports", response_model=list[ReportListItem])
def list_reports(
    limit: int = Query(50, ge=1, le=500),
    category: str | None = None,
    province: str | None = None,
    store: Store = Depends(get_store),
) -> list[ReportListItem]:
    """Recent reports, newest first. Used by the admin dashboard's moderation queue."""
    reports = sorted(store.list_reports(), key=lambda r: r.created_at, reverse=True)
    if category:
        reports = [r for r in reports if r.category == category]
    if province:
        reports = [r for r in reports if r.province == province]
    return [
        ReportListItem(
            id=r.id, msisdn=r.msisdn, category=r.category, province=r.province,
            message_excerpt=r.message_excerpt, reporter_id=r.reporter_id,
            reporter_trust=r.reporter_trust, created_at=r.created_at,
        )
        for r in reports[:limit]
    ]
