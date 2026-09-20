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

    # The market's money, carried on every row so a client can render the
    # amount without knowing which country the run was for. Empty strings when
    # the upload carried no recognisable `country`: a bare "495,000.00" is
    # honest, where defaulting to a symbol would assert a currency we were
    # never told.
    currency_code: str = ""
    currency_symbol: str = ""


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
