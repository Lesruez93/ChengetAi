"""ChengetAI backend entrypoint.

Run locally with: uvicorn app.main:app --reload --app-dir backend
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import classify, feed, numbers, reference, sentinel, support

settings = get_settings()

app = FastAPI(
    title="ChengetAI API",
    description="AI scam & fraud protection across African mobile-money markets: message "
                 "classification, number reputation, community reporting with support "
                 "pathways, trending scams feed, and agent fraud sentinel. "
                 "Currently covering Zimbabwe, Kenya, Nigeria, Uganda, South Africa, "
                 "Ghana and Tanzania.",
    version="0.2.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # MVP: the Flutter app talks to this API directly; tighten before production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(classify.router)
app.include_router(numbers.router)
app.include_router(feed.router)
app.include_router(sentinel.router)
app.include_router(support.router)
app.include_router(reference.router)


@app.get("/health", tags=["health"])
def health() -> dict[str, object]:
    from app.services.countries import SUPPORTED_COUNTRY_CODES

    return {
        "status": "ok",
        "env": settings.app_env,
        "countries": list(SUPPORTED_COUNTRY_CODES),
        "default_country": settings.default_country,
    }
