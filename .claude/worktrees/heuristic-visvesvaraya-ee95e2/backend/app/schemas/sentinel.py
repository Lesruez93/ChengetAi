from datetime import datetime

from pydantic import BaseModel


class FlaggedTransaction(BaseModel):
    transaction_id: str
    timestamp: datetime
    agent_id: str
    customer_msisdn: str
    type: str
    amount: float
    anomaly_score: float
    reasons: list[str]


class SentinelAnalyzeResponse(BaseModel):
    job_id: str
    n_transactions: int
    n_flagged: int
    flagged: list[FlaggedTransaction]
    summary_by_reason: dict[str, int]


class SentinelJobSummary(BaseModel):
    """One past analysis run, for the admin Sentinel job history table."""

    id: str
    filename: str
    country: str
    n_transactions: int
    n_flagged: int
    created_at: datetime
