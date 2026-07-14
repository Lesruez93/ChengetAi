from fastapi import APIRouter, Depends, Query

from app.schemas.feed import FeedItemResponse, TrendingFeedResponse
from app.services.feed import DEFAULT_WINDOW_DAYS, build_trending_feed, list_feed_items
from app.services.store import Store, get_store

router = APIRouter(prefix="/feed", tags=["feed"])


@router.get("", response_model=list[FeedItemResponse])
def get_feed(store: Store = Depends(get_store)) -> list[FeedItemResponse]:
    return list_feed_items(store)


@router.get("/trending", response_model=TrendingFeedResponse)
def get_trending_feed(
    window_days: int = Query(DEFAULT_WINDOW_DAYS, ge=1, le=90),
    store: Store = Depends(get_store),
) -> TrendingFeedResponse:
    return build_trending_feed(store, window_days=window_days)
