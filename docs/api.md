# ChengetAI API Reference

Base URL (local dev): `http://localhost:8000`

All responses are JSON. All endpoints are implemented in `backend/app/routers/`.

---

## `POST /classify`

Classify a message as scam, suspicious, or safe.

**Request**
```json
{ "text": "Confirmed. You have received $80... please reverse...", "strategy": "baseline" }
```
`strategy` is optional (`"baseline"` | `"llm"`); defaults to `CLASSIFIER_STRATEGY` env var. If `"llm"` is requested but no `ANTHROPIC_API_KEY` is configured, the backend silently falls back to `"baseline"`.

**Response `200`**
```json
{
  "verdict": "scam",
  "confidence": 0.87,
  "risk_phrases": [{ "phrase": "reverse", "reason": "Asks you to 'reverse' or send back money..." }],
  "explanation": "Baseline TF-IDF/LogisticRegression model estimates an 87% probability...",
  "matched_category": null,
  "strategy_used": "baseline"
}
```

---

## `GET /numbers/{msisdn}`

Look up a phone number's reputation. `msisdn` accepts local (`0771234567`) or international (`+263771234567`) formats.

**Response `200`**
```json
{
  "msisdn": "0771234567",
  "report_count": 2,
  "categories": { "ecocash_reversal": 2 },
  "last_reported_at": "2026-07-11T09:00:00Z",
  "is_publicly_flagged": false,
  "risk_level": "low"
}
```
`risk_level` is one of `unknown | low | medium | high`. `404`/`422` on malformed numbers.

---

## `GET /numbers`

All numbers with at least one report, ranked by report count descending. Used by the admin dashboard's flagged-number review queue.

**Response `200`**: array of the same shape as `GET /numbers/{msisdn}`.

---

## `POST /reports`

Report a number for a scam category.

**Request**
```json
{
  "msisdn": "0771234567",
  "category": "ecocash_reversal",
  "province": "Harare",
  "message_excerpt": "reverse the money please",
  "reporter_id": "optional-user-id"
}
```

**Response `200`**
```json
{ "id": "...", "msisdn": "0771234567", "category": "ecocash_reversal", "province": "Harare",
  "created_at": "2026-07-12T08:00:00Z", "status": "recorded" }
```
`status` is one of:
- `recorded` — new report accepted, a confirmation SMS is sent if `reporter_id` was provided
- `duplicate_collapsed` — same reporter already reported this number+category in the last 24h; recorded with zero trust weight so it doesn't inflate scores
- `rate_limited` — reporter exceeded `REPORT_RATE_LIMIT_PER_HOUR` (default 5); not persisted

---

## `GET /reports?limit=50&category=&province=`

Recent reports, newest first, optionally filtered by `category` and/or `province`. Used by the admin dashboard's moderation queue. `limit` defaults to 50, max 500.

**Response `200`**
```json
[{ "id": "...", "msisdn": "0771234567", "category": "ecocash_reversal", "province": "Harare",
   "message_excerpt": "reverse the money please", "reporter_id": null, "reporter_trust": 1.0,
   "created_at": "2026-07-12T08:00:00Z" }]
```

---

## `GET /feed`

Editorial/aggregated trending-scam entries (seeded content, not the live weighted ranking).

**Response `200`**: array of `{ id, title, category, summary, province, created_at }`.

---

## `GET /feed/trending?window_days=7`

Live "trending this week" ranking and province hotspot map, computed with **weighted rules** (report count × recency × reporter trust) over `reports` in `numbers`/`reports` tables — **not** an AI model (see `docs/architecture.md`).

**Response `200`**
```json
{
  "generated_at": "2026-07-12T08:00:00Z",
  "window_days": 7,
  "trending_categories": [{ "category": "ecocash_reversal", "score": 8.15, "report_count": 8 }],
  "hotspots": [{ "province": "Harare", "level": "red", "report_count": 8, "top_category": "ecocash_reversal" }],
  "method_note": "Computed with weighted rules (report count x recency x reporter trust). Not an AI/ML model."
}
```
`level` is one of `green | yellow | red`.

---

## `POST /sentinel/analyze`

Upload a transaction CSV (`multipart/form-data`, field name `file`) for the Agent Fraud Sentinel B2B module. Required columns: `transaction_id, timestamp, agent_id, customer_msisdn, type, amount` (optional: `is_reversal`). See `sample_data/transactions_sample.csv` for the expected shape and `sample_data/generate_transactions.py` for how it was generated.

**Response `200`**
```json
{
  "job_id": "...",
  "n_transactions": 200,
  "n_flagged": 20,
  "flagged": [
    { "transaction_id": "TX00042", "timestamp": "...", "agent_id": "AGT-2201",
      "customer_msisdn": "0771234567", "type": "cash_out", "amount": 495.0,
      "anomaly_score": 0.71, "reasons": ["3 transactions just under $500 ..."] }
  ],
  "summary_by_reason": { "3 transactions just under $500...": 5 }
}
```

---

## `GET /sentinel/jobs`

Past analysis runs, newest first. Used by the admin dashboard's Sentinel job history table.

**Response `200`**
```json
[{ "id": "...", "filename": "transactions_sample.csv", "n_transactions": 200, "n_flagged": 20,
   "created_at": "2026-07-12T08:00:00Z" }]
```

---

## `GET /health`

Liveness check: `{ "status": "ok", "env": "development" }`.
