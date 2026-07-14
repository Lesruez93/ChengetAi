from typing import Literal

from pydantic import BaseModel, Field

Verdict = Literal["scam", "suspicious", "safe"]


class ClassifyRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=4000)
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
