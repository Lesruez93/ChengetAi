"""ChengetAI backend entrypoint.

Run locally with: uvicorn app.main:app --reload --app-dir backend
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routers import analyze, classify, feed, numbers, sentinel

settings = get_settings()

app = FastAPI(
    title="ChengetAI API",
    description="AI scam & fraud protection for Zimbabwe: message classification, "
                 "number reputation, trending scams feed, and agent fraud sentinel.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # MVP: the Flutter app talks to this API directly; tighten before production
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(analyze.router)
app.include_router(classify.router)
app.include_router(numbers.router)
app.include_router(feed.router)
app.include_router(sentinel.router)


@app.get("/health", tags=["health"])
def health() -> dict[str, str]:
    return {"status": "ok", "env": settings.app_env}
