from fastapi import APIRouter, Depends

from app.schemas.analyze import AnalyzeRequest, AnalyzeResponse
from app.services.analyze import analyze
from app.services.store import Store, get_store

router = APIRouter(prefix="/analyze", tags=["analyze"])


@router.post("", response_model=AnalyzeResponse)
def analyze_anything(payload: AnalyzeRequest, store: Store = Depends(get_store)) -> AnalyzeResponse:
    """Check a mixed paste — message text, links, phone numbers, or all three.

    `POST /classify` remains the endpoint for judging message wording alone; this
    one wraps it, adds link and number checks, and reduces everything to a single
    verdict so the caller doesn't have to decide which endpoint a paste belongs
    to before it can be checked.
    """
    return analyze(store, payload.text, payload.strategy)
