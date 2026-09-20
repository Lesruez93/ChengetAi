from typing import Literal

from pydantic import BaseModel, Field

Verdict = Literal["scam", "suspicious", "safe"]


class ClassifyRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=4000)
    country: str | None = Field(
        default=None,
        description="ISO 3166-1 alpha-2 code. Grounds the classifier in the right "
                    "wallets and currency; falls back to DEFAULT_COUNTRY.",
    )
    strategy: Literal["baseline", "llm"] | None = Field(
        default=None, description="Override the default classifier strategy for this request."
    )


class RiskPhrase(BaseModel):
    phrase: str
    reason: str


class ClassifyResponse(BaseModel):
    verdict: Verdict
    confidence: float = Field(..., ge=0.0, le=1.0)
    risk_phrases: list[RiskPhrase] = Field(default_factory=list)
    explanation: str
    matched_category: str | None = None
    strategy_used: Literal["baseline", "llm"]
    country: str = Field(..., description="The market the verdict was grounded in.")
    next_steps: list[str] = Field(
        default_factory=list,
        description="What to do now. Always populated for a scam or suspicious verdict, "
                    "so a verdict never leaves the user without a pathway.",
    )
