from typing import Literal

from pydantic import BaseModel, Field

from app.schemas.classify import ClassifyResponse, Verdict

RiskLevel = Literal["unknown", "low", "medium", "high"]


class AnalyzeRequest(BaseModel):
    """Anything the user has in their clipboard. Longer than `ClassifyRequest`'s
    limit because pasted content is often a whole forwarded thread rather than a
    single SMS."""

    text: str = Field(..., min_length=1, max_length=8000)
    strategy: Literal["baseline", "llm"] | None = Field(
        default=None, description="Override the default classifier strategy for this request."
    )


class LinkFinding(BaseModel):
    url: str
    host: str
    risk_level: RiskLevel
    reasons: list[str]


class NumberFinding(BaseModel):
    msisdn: str
    risk_level: RiskLevel
    report_count: int
    is_publicly_flagged: bool
    top_category: str | None = None


class AnalyzeResponse(BaseModel):
    """The combined answer for a mixed paste.

    `verdict` is the worst finding across the message text, every link and every
    number — the user asked one question ("is this safe?") and needs one answer,
    with the component findings below it as the evidence.
    """

    verdict: Verdict
    confidence: float = Field(..., ge=0.0, le=1.0)
    summary: str

    message: ClassifyResponse | None = Field(
        default=None,
        description="Classifier result for the prose. Null when the paste is only a link or a number.",
    )
    links: list[LinkFinding] = Field(default_factory=list)
    numbers: list[NumberFinding] = Field(default_factory=list)
    unrecognized_numbers: list[str] = Field(
        default_factory=list,
        description="Phone-like text that is not a Zimbabwean mobile number, so it could not be looked up.",
    )
    method_note: str
