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

## `POST /analyze`

Check an arbitrary paste — message text, links, phone numbers, or any mix. Splits the text into entities, routes each to the checker that can judge it, and returns the **worst** finding as the overall verdict alongside the evidence.

**Request**
```json
{ "text": "Your account is blocked. Verify at http://secure-ecocash.co.zw.login.tk/verify or call 0771234567" }
```
`strategy` is optional and behaves exactly as on `POST /classify`. `text` accepts up to 8000 characters (longer than `/classify`, since pasted content is often a whole forwarded thread); only the first 4000 are passed to the classifier, while links and numbers are extracted from the whole text.

**Response `200`**
```json
{
  "verdict": "scam",
  "confidence": 0.85,
  "summary": "0771234567 has been reported 3 times by the community. The link to secure-ecocash.co.zw.login.tk looks unsafe. Do not send money, share an OTP, or tap any link in this.",
  "message": { "verdict": "suspicious", "confidence": 0.61, "risk_phrases": [], "explanation": "...", "matched_category": null, "strategy_used": "baseline" },
  "links": [
    {
      "url": "http://secure-ecocash.co.zw.login.tk/verify",
      "host": "secure-ecocash.co.zw.login.tk",
      "risk_level": "high",
      "reasons": ["Uses the ecocash name but is not the real ecocash.co.zw website.", "..."]
    }
  ],
  "numbers": [
    { "msisdn": "0771234567", "risk_level": "medium", "report_count": 3, "is_publicly_flagged": true, "top_category": "ecocash_reversal" }
  ],
  "unrecognized_numbers": [],
  "method_note": "Message wording is judged by the scam classifier; phone numbers by community reports; links by the shape of the web address only..."
}
```

`message` is `null` when the paste has fewer than 4 words (a bare link or number), since the classifier is trained on sentences. `unrecognized_numbers` holds phone-like text that is not a Zimbabwean mobile number and so could not be looked up — reported rather than dropped, because "cannot check" is not "fine".

Link `risk_level` is `unknown | low | medium | high`. **`unknown` means "nothing wrong with the address", not "safe"** — no URL is ever fetched (see `docs/architecture.md` → "Universal analyzer"). `422` on empty text.

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

## `GET /numbers/flagged/sync?known_version=`

Bulk download of publicly-flagged numbers, for the Android app's on-device call/SMS screening. Only numbers past `NUMBER_PUBLIC_FLAG_THRESHOLD` are included.

Pass the `known_version` currently held by the client. If the server's set still hashes to that value it replies with `unchanged: true` and an empty `numbers` array, keeping a routine sync to a few hundred bytes on a metered connection.

**Response `200`**
```json
{
  "version": "3f9a1c07b2d84e6a",
  "generated_at": "2026-08-14T09:00:00Z",
  "count": 1,
  "unchanged": false,
  "numbers": [
    { "msisdn": "0771234567", "risk_level": "medium", "report_count": 3, "top_category": "ecocash_reversal" }
  ],
  "method_note": "Crowd-sourced community reports aggregated by weighted rules, not an AI model..."
}
```

`count` always reports the true set size, including when `unchanged` is true. Screening matches on the handset against this copy; the app never sends an incoming number to the API.

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
