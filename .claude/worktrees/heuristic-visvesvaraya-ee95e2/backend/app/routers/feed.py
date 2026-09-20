from fastapi import APIRouter, Depends, HTTPException, Query

from app.schemas.feed import FeedItemResponse, TrendingFeedResponse
from app.services.countries import UnknownCountryError
from app.services.feed import DEFAULT_WINDOW_DAYS, build_trending_feed, list_feed_items
from app.services.store import Store, get_store

router = APIRouter(prefix="/feed", tags=["feed"])

COUNTRY_QUERY = Query(
    default=None,
    description="ISO 3166-1 alpha-2 code. Omit for the cross-country view.",
)


@router.get("", response_model=list[FeedItemResponse])
def get_feed(
    country: str | None = COUNTRY_QUERY,
    store: Store = Depends(get_store),
) -> list[FeedItemResponse]:
    try:
        return list_feed_items(store, country)
    except UnknownCountryError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/trending", response_model=TrendingFeedResponse)
def get_trending_feed(
    window_days: int = Query(DEFAULT_WINDOW_DAYS, ge=1, le=90),
    country: str | None = COUNTRY_QUERY,
    store: Store = Depends(get_store),
) -> TrendingFeedResponse:
    try:
        return build_trending_feed(store, window_days=window_days, country_code=country)
    except UnknownCountryError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
