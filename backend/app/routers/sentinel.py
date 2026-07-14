from fastapi import APIRouter, Depends, HTTPException, UploadFile

from app.models.domain import SentinelJob
from app.schemas.sentinel import FlaggedTransaction, SentinelAnalyzeResponse, SentinelJobSummary
from app.services.sentinel import InvalidTransactionFile, analyze_transactions
from app.services.store import Store, get_store

router = APIRouter(prefix="/sentinel", tags=["sentinel"])

ANOMALY_SCORE_THRESHOLD = 0.55


@router.get("/jobs", response_model=list[SentinelJobSummary])
def list_jobs(store: Store = Depends(get_store)) -> list[SentinelJobSummary]:
    """Past analysis runs, newest first. Used by the admin dashboard's Sentinel job history."""
    return [
        SentinelJobSummary(
            id=j.id, filename=j.filename, n_transactions=j.n_transactions,
            n_flagged=j.n_flagged, created_at=j.created_at,
        )
        for j in store.list_sentinel_jobs()
    ]


@router.post("/analyze", response_model=SentinelAnalyzeResponse)
async def analyze(file: UploadFile, store: Store = Depends(get_store)) -> SentinelAnalyzeResponse:
    raw_bytes = await file.read()
    try:
        df, scores, rule_reasons = analyze_transactions(raw_bytes)
    except InvalidTransactionFile as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    flagged: list[FlaggedTransaction] = []
    summary_by_reason: dict[str, int] = {}

    for pos, (idx, row) in enumerate(df.iterrows()):
        reasons = list(rule_reasons.get(idx, []))
        score = float(scores[pos])
        if score >= ANOMALY_SCORE_THRESHOLD and not reasons:
            reasons.append("Statistically unusual combination of amount, time, and transaction type.")
        if not reasons:
            continue

        flagged.append(FlaggedTransaction(
            transaction_id=str(row["transaction_id"]),
            timestamp=row["timestamp"],
            agent_id=str(row["agent_id"]),
            customer_msisdn=str(row["customer_msisdn"]),
            type=str(row["type"]),
            amount=float(row["amount"]),
            anomaly_score=round(score, 3),
            reasons=reasons,
        ))
        for r in reasons:
            key = r.split(",")[0][:60]
            summary_by_reason[key] = summary_by_reason.get(key, 0) + 1

    job = store.save_sentinel_job(SentinelJob(
        filename=file.filename or "upload.csv", n_transactions=len(df), n_flagged=len(flagged),
    ))

    return SentinelAnalyzeResponse(
        job_id=job.id, n_transactions=len(df), n_flagged=len(flagged),
        flagged=flagged, summary_by_reason=summary_by_reason,
    )
