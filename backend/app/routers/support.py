"""Support pathways — the 'what do I do now' half of the product.

Separate from /classify on purpose: a person needs this endpoint whether or not
a message was ever classified. Someone who has already sent money, or who was
called rather than texted, arrives here directly.
"""

from fastapi import APIRouter, HTTPException, Query

from app.schemas.support import SupportPathwayResponse
from app.services.countries import UnknownCountryError
from app.services.support import build_support_pathway

router = APIRouter(prefix="/support", tags=["support"])


@router.get("/{country_code}", response_model=SupportPathwayResponse)
def get_support_pathway(
    country_code: str,
    category: str | None = Query(
        default=None,
        description="Optional scam category, to lead with that category's specific first action.",
    ),
) -> SupportPathwayResponse:
    try:
        return SupportPathwayResponse(**build_support_pathway(country_code, category))
    except UnknownCountryError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
