from fastapi import APIRouter, Depends, HTTPException

from app.messaging.sms import send_report_confirmation
from app.schemas.reputation import NumberReputationResponse, ReportCreate, ReportResponse
from app.services.reputation import ValidationError, lookup_number, submit_report
from app.services.store import Store, get_store

router = APIRouter(tags=["numbers"])


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
