# ChengetAI API Reference

Base URL (local dev): `http://localhost:8000`

All responses are JSON. All endpoints are implemented in `backend/app/routers/`.

## Country and region conventions

ChengetAI serves several mobile-money markets, so almost every endpoint is
country-aware. Three rules hold everywhere:

- **Countries are ISO 3166-1 alpha-2 codes**: `ZW`, `KE`, `NG`, `UG`, `ZA`,
  `GH`, `TZ`. `GET /reference/countries` is the live list.
- **Numbers are stored and returned in E.164** (`+254712345678`). Input may be
  local (`0712345678`) or international. A *local* number is ambiguous across
  markets — `0771234567` is a valid Zimbabwean, Ugandan **and** Tanzanian
  number — so it is resolved against the `country` you supply, falling back to
  the server's `DEFAULT_COUNTRY`. An international number resolves from its own
  dial code and ignores any `country` you send.
- **"Region" means the country's own first-level unit**, which is a Province in
  Zimbabwe and South Africa, a Region in Kenya, Uganda and Ghana, and a Zone in
  Nigeria and Tanzania. Responses carry `region_label` so clients can use the
  right word instead of guessing.

---

## `POST /classify`

Classify a message as scam, suspicious, or safe.

**Request**
```json
{ "text": "M-PESA: KSh5,000 sent in error... please reverse...", "country": "KE", "strategy": "baseline" }
```
`country` is optional and grounds the classifier in that market's wallets,
currency and languages; an unsupported code falls back to `DEFAULT_COUNTRY`
rather than erroring. `strategy` is optional (`"baseline"` | `"llm"`) and
defaults to the `CLASSIFIER_STRATEGY` env var. If `"llm"` is requested but no
`ANTHROPIC_API_KEY` is configured, the backend silently falls back to
`"baseline"`.

**Response `200`**
```json
{
  "verdict": "scam",
  "confidence": 0.87,
  "risk_phrases": [{ "phrase": "reverse", "reason": "Asks you to 'reverse' or send back money..." }],
  "explanation": "Baseline TF-IDF/LogisticRegression model estimates an 87% probability...",
  "matched_category": "mobile_money_reversal",
  "strategy_used": "baseline",
  "country": "KE",
  "next_steps": [
    "Do not send anything back. Check your real balance in the wallet app...",
    "Stop replying. Every further message gives the sender more to work with.",
    "..."
  ]
}
```

`next_steps` is **empty for a `safe` verdict and never empty otherwise**. A
verdict without a next step is only half an answer, so the pathway ships with
the result rather than requiring a second call to `/support`.

---

## `GET /support/{country}?category=`

The ordered "what do I do now" escalation ladder for one market. This is the
Safety, Reporting & Protection half of the product, and it is deliberately a
first-class endpoint rather than a field on `/classify`: people who have
already sent money, or who were phoned rather than texted, need it without
ever having classified anything.

`category` is optional; supplying it leads the steps with that scam type's
specific first action.

**Response `200`**
```json
{
  "country": "KE",
  "country_name": "Kenya",
  "category": "mobile_money_reversal",
  "category_first_action": "Do not send anything back. Check your real balance...",
  "immediate_steps": ["Do not send anything back...", "Stop replying...", "..."],
  "channels": [
    { "kind": "wallet", "organisation": "M-PESA / Airtel Money customer care",
      "what_it_does": "Can reverse a transfer that has not yet been withdrawn...",
      "contact": null, "url": null, "verified": false },
    { "kind": "police", "organisation": "Police emergency",
      "what_it_does": "For any threat to your safety, not only financial loss.",
      "contact": "999", "url": null, "verified": true }
  ],
  "data_note": "Organisation names and websites are compiled from public sources..."
}
```

`kind` orders the ladder by urgency: `wallet` (the only rung that can still
stop a transfer) → `regulator` → `police` → `support`.

`verified` is load-bearing and **clients must render the distinction rather
than hiding it**. `true` means a long-standing, widely published national short
code. `false` means the organisation is correct but the specific contact has
not been confirmed against its own published channel — presenting an
unconfirmed emergency number as fact is its own safety failure. Confirming
every `false` entry is a pre-pilot task (`docs/deployment_plan.md`).

`404` for an unsupported country.

---

## `GET /reference/countries`, `GET /reference/countries/{code}`, `GET /reference/categories`

Reference data served to clients so region lists, wallet names and category
labels are not hardcoded per platform — adding a market is a backend deploy
rather than a coordinated release across three codebases.

**`GET /reference/countries` `200`**
```json
[{ "code": "KE", "name": "Kenya", "dial_code": "254", "region_label": "Region",
   "regions": ["Nairobi", "Central", "..."], "providers": ["M-PESA", "Airtel Money", "T-Kash"],
   "languages": ["English", "Swahili", "Sheng"], "currency_code": "KES",
   "currency_symbol": "KSh", "example_msisdn": "0712345678" }]
```

**`GET /reference/categories` `200`**
```json
[{ "key": "mobile_money_reversal", "label": "Wrong deposit / reversal",
   "description": "A fake or reversible deposit notice pressures you into...",
   "first_action": "Do not send anything back. Check your real balance..." }]
```

Category keys describe the *mechanism*, not the wallet brand, so one taxonomy
holds across every market: `mobile_money_reversal`, `fake_job`,
`fake_investment`, `fake_loan_aid`, `sim_swap`, `otp_phishing`,
`impersonation`, `faith_seed`, `other`.

---

## `GET /numbers/{msisdn}?country=`

Look up a phone number's reputation. `msisdn` accepts local (`0712345678`) or
international (`+254712345678`) format; `country` is needed only for the former.

**Response `200`**
```json
{
  "msisdn": "+2348031234567",
  "country": "NG",
  "report_count": 4,
  "categories": { "otp_phishing": 2, "impersonation": 2 },
  "countries": { "NG": 3, "GH": 1 },
  "last_reported_at": "2026-09-15T09:00:00Z",
  "is_publicly_flagged": true,
  "risk_level": "high"
}
```

`risk_level` is one of `unknown | low | medium | high`. A number reported from
**more than one country** escalates straight to `high` regardless of volume:
cross-border reach means an organised operation rather than a local dispute.
`422` on a malformed number or an unsupported country.

---

## `GET /numbers?country=`

All numbers with at least one report, ranked by report count descending. Used
by the admin dashboard's flagged-number review queue. `country` filters on
where the number was *reported*, not its home market, so a Nigerian number
running a scam into Ghana still appears in Ghana's queue.

**Response `200`**: array of the same shape as `GET /numbers/{msisdn}`.

---

## `POST /reports`

Report a number for a scam category.

**Request**
```json
{
  "msisdn": "0712345678",
  "country": "KE",
  "category": "mobile_money_reversal",
  "region": "Nairobi",
  "message_excerpt": "please reverse the money to 0722113344",
  "reporter_id": "optional"
}
```

**Omitting `reporter_id` entirely files an anonymous report.** Anonymous
reports are accepted and counted — requiring an identity is a barrier for
exactly the people most exposed to retaliation. The cost is that anonymous
reports carry no per-reporter rate limiting or duplicate collapse; that is
recovered downstream by the public-flag threshold, which no single reporter can
clear alone.

`message_excerpt` is **redacted server-side before storage**: phone numbers,
emails, URLs, OTPs and identity numbers are replaced with markers, while the
scam's wording — what the classifier learns from and a moderator reads — is
preserved. See `backend/app/services/redaction.py`.

An unrecognised `region` falls back to the country's first region rather than
rejecting the report: the number and category are what protect other people,
and losing a whole report to a typo is the worse outcome.

**Response `200`**
```json
{ "id": "...", "msisdn": "+254712345678", "country": "KE",
  "category": "mobile_money_reversal", "region": "Nairobi",
  "created_at": "2026-09-16T08:00:00Z", "status": "recorded" }
```
`status` is one of:
- `recorded` — new report accepted; a confirmation SMS is sent if `reporter_id` was provided
- `duplicate_collapsed` — same reporter already reported this number+category in the last 24h; recorded with zero trust weight so it doesn't inflate scores
- `rate_limited` — reporter exceeded `REPORT_RATE_LIMIT_PER_HOUR` (default 5); not persisted

---

## `GET /reports?limit=50&category=&country=&region=`

Recent reports, newest first, optionally filtered. Used by the admin
dashboard's moderation queue. `limit` defaults to 50, max 500.

**Response `200`**
```json
[{ "id": "...", "msisdn": "+254712345678", "country": "KE",
   "category": "mobile_money_reversal", "region": "Nairobi",
   "message_excerpt": "please reverse the money to [number]", "reporter_id": null,
   "reporter_trust": 1.0, "created_at": "2026-09-16T08:00:00Z" }]
```

---

## `GET /feed?country=`

Editorial/aggregated trending-scam entries (curated content, not the live
weighted ranking). An item with `"country": null` is cross-market guidance and
is **always** returned, so scoping to Kenya never hides advice that applies to
Kenya too.

**Response `200`**: array of `{ id, title, category, summary, country, region, created_at }`.

---

## `GET /feed/trending?window_days=7&country=`

Live "trending this week" ranking plus two hotspot maps, computed with
**weighted rules** (report count × recency × reporter trust) over the `reports`
table — **not** an AI model (see `docs/architecture.md`).

Two levels of map, on purpose: a single regional map across seven countries
would split the same report volume across 60+ buckets, render everything green
and claim there are no scams anywhere. So `country_hotspots` is always the
cross-country picture, while `hotspots` is the within-country regional
breakdown and is **populated only when `country` is supplied**.

**Response `200`**
```json
{
  "generated_at": "2026-09-16T08:00:00Z",
  "window_days": 7,
  "country": "NG",
  "region_label": "Zone",
  "trending_categories": [
    { "category": "otp_phishing", "label": "OTP, PIN or ID phishing", "score": 4.2, "report_count": 5 }
  ],
  "hotspots": [
    { "region": "Lagos", "level": "red", "report_count": 5, "top_category": "otp_phishing" }
  ],
  "country_hotspots": [
    { "country": "NG", "country_name": "Nigeria", "level": "red", "report_count": 5,
      "top_category": "otp_phishing" }
  ],
  "method_note": "Computed with weighted rules (report count x recency x reporter trust). Not an AI/ML model."
}
```
`level` is one of `green | yellow | red`. Thresholds are absolute rather than
relative, for the same reason a smoke alarm's are: a level should mean the same
thing in Lagos as in Gweru, so a market with genuinely few reports shows green
instead of being scaled up to look red. `404` for an unsupported country.

---

## `POST /sentinel/analyze`

Upload a transaction CSV (`multipart/form-data`, field name `file`) for the
Agent Fraud Sentinel B2B module. Optional form field `country` tags the run
with the agent network's market; the detection rules themselves are
currency-agnostic, since structuring and rapid reversals look the same in naira
as in shillings.

Required columns: `transaction_id, timestamp, agent_id, customer_msisdn, type,
amount` (optional: `is_reversal`). See `sample_data/transactions_sample.csv`
for the expected shape.

**Response `200`**
```json
{
  "job_id": "...",
  "n_transactions": 200,
  "n_flagged": 20,
  "flagged": [
    { "transaction_id": "TX00042", "timestamp": "...", "agent_id": "AGT-2201",
      "customer_msisdn": "0771234567", "type": "cash_out", "amount": 495.0,
      "anomaly_score": 0.71, "reasons": ["3 transactions just under the reporting threshold ..."] }
  ],
  "summary_by_reason": { "3 transactions just under the reporting threshold...": 5 }
}
```

---

## `GET /sentinel/jobs`

Past analysis runs, newest first. Used by the admin dashboard's Sentinel job
history table.

**Response `200`**
```json
[{ "id": "...", "filename": "transactions_sample.csv", "country": "KE",
   "n_transactions": 200, "n_flagged": 20, "created_at": "2026-09-16T08:00:00Z" }]
```

---

## `GET /health`

Liveness check, including which markets this deployment serves:
```json
{ "status": "ok", "env": "development",
  "countries": ["ZW", "KE", "NG", "UG", "ZA", "GH", "TZ"], "default_country": "ZW" }
```
