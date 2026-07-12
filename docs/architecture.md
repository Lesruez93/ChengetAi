# ChengetAI Architecture

## System diagram

```
   Consumer                  SME / Agent              Public visitor      POTRAZ / internal
   (share-intent, SMS)                                (landing page)      (admin dashboard)
          │                       │                          │                    │
          ▼                       ▼                          ▼                    ▼
   ┌──────────────────────────────────────┐   ┌───────────────────────────────────────┐
   │            Flutter app                │   │           Next.js web app (web/)        │
   │  check_message / lookup / feed         │   │  /        → marketing landing page       │
   │  (+hotspot map) / sentinel / auth /home│   │  /admin/* → password-gated dashboard:     │
   │                                        │   │  overview, reports, numbers, sentinel jobs│
   └──────────────────┬─────────────────────┘   └──────────────────┬────────────────────────┘
                       │                                            │
                       └───────────────────┬────────────────────────┘
                                            │ HTTPS / JSON
                                            ▼
                         ┌────────────────────────────┐
                         │     Python FastAPI backend   │
                         │                              │
                         │  routers/  → thin HTTP layer │
                         │  services/                   │
                         │   ├─ classifier.py            │
                         │   │   ├─ BaselineClassifier    │  TF-IDF + LogisticRegression
                         │   │   └─ LLMClassifier         │  Anthropic API, few-shot prompt
                         │   ├─ reputation.py             │  reports, trust weighting, abuse controls
                         │   ├─ feed.py                   │  weighted-rules trending + hotspots
                         │   ├─ sentinel.py               │  IsolationForest + rules hybrid
                         │   └─ store.py / supabase_store │  repository interface
                         │  messaging/sms.py              │  Twilio, console transport in dev
                         └──────────────┬───────────────┘
                                        │
                                        ▼
                         ┌────────────────────────────┐
                         │  Supabase (Auth, Postgres,   │
                         │  RLS, Storage)                │
                         │  tables: profiles, numbers,   │
                         │  reports, scam_samples,       │
                         │  feed_items, scam_trend_scores,│
                         │  sentinel_jobs                │
                         └────────────────────────────┘
```

The web app (`web/`) is a read-mostly consumer of the same FastAPI backend
the Flutter app talks to — it adds no new data model, just three additional
`GET` endpoints (`/numbers`, `/reports`, `/sentinel/jobs`) so the admin
dashboard can list rather than only look up/submit. See "Admin dashboard
auth" below for how `/admin/*` is gated.

The backend's persistence layer sits behind a `Store` protocol
(`backend/app/services/store.py`). In dev/test and in this challenge
environment it uses `InMemoryStore`, seeded with realistic sample data, so
the whole API runs with zero external services. Setting `USE_SUPABASE=true`
swaps in `SupabaseStore` (supabase-py against the schema in
`sample_data/seed.sql`) with no router or service code changes.

## Where AI is used, and where it deliberately isn't

Rubric C2 asks us to justify AI use and avoid the "AI sledgehammer" —
reaching for a model where simpler logic would do.

**AI is used for:**

1. **Message classification** (`services/classifier.py`) — two strategies:
   - `BaselineClassifier`: TF-IDF + logistic regression trained on
     `sample_data/scam_corpus.jsonl`. Fast, offline, fully inspectable via
     learned weights.
   - `LLMClassifier`: Anthropic API with a few-shot prompt grounded in named
     Zimbabwean scam patterns (EcoCash reversal, fake jobs, forex, wrong
     transfer, fake NGO/loan, church/prophet).

   *Why AI at all, and not a keyword blocklist?* Local scam text is
   adversarial and code-switched (Shona/English), and phrasing mutates
   constantly to dodge filters. `SCAM_KEYWORD_REASONS` in `classifier.py`
   doubles as both a UI highlight list *and* a naive-rules comparison point:
   it catches obvious cases ("reverse", "registration fee") but misses
   paraphrases, novel scripts, and messages with no trigger word at all —
   exactly the gap the trained/LLM classifiers close. The repo ships both
   strategies specifically so this trade-off is demonstrable, not asserted.

2. **Agent Fraud Sentinel** (`services/sentinel.py`) — an `IsolationForest`
   over amount/hour/transaction-type features, combined with explicit rules
   (structuring, rapid reversal, unusual hours). Fraud patterns here are
   unlabeled and drift over time, which is exactly the setting unsupervised
   anomaly detection is for; the rules exist as an honest, human-readable
   baseline and to catch known patterns the model might miss on a small
   sample.

**AI is explicitly NOT used for:**

- **Number reputation** (`services/reputation.py`) — plain CRUD with
  rate limiting, duplicate collapse, and a public-flag threshold. A report
  count and category breakdown do not need a model.
- **Trending feed / hotspot map** (`services/feed.py`) — a weighted-rules
  aggregation (`report count × recency × reporter trust`) over the same
  `reports` table the reputation system uses. The response body says so
  explicitly (`method_note` field) so this is never mistaken for an AI
  output in the UI or in review.

## Offline behaviour

The Flutter app caches the top N flagged numbers (by `report_count`) from
`/numbers` lookups locally, so a basic "is this number flagged?" check works
without connectivity — the common case for prepaid users in low-signal
areas. Message classification and CSV analysis require connectivity in the
MVP (client-side model execution is a roadmap item).

## Abuse-resistance of the reputation system

Anyone can report a number, so the system is designed to resist being
weaponized against innocent numbers:

- **Rate limiting**: `REPORT_RATE_LIMIT_PER_HOUR` caps reports per reporter.
- **Duplicate collapse**: the same reporter re-reporting the same
  number+category within 24h is recorded but contributes zero trust weight.
- **Public-flag threshold**: a number is only shown as "publicly flagged"
  after `NUMBER_PUBLIC_FLAG_THRESHOLD` distinct reports, so a single hostile
  report can't brand a number a scammer (defamation risk, see the proposal's
  Compliance & Risk Mitigation section).
- **Dispute path** (roadmap): a number owner can contest a flag; disputed
  flags are hidden pending human review.

## Admin dashboard auth

`web/src/app/admin/*` (everything except `/admin/login`) is gated by
`web/src/proxy.ts` (Next.js middleware), which checks for a signed session
cookie set by `POST /api/admin/login` after the caller supplies the
`ADMIN_PASSWORD` env var. The cookie value is a SHA-256 hash derived from
`ADMIN_SESSION_SECRET` (or `ADMIN_PASSWORD` if unset) — stateless, no
session store needed, and it fails closed if no password is configured at
all. This is a deliberate MVP simplification for a single-team demo, not a
multi-admin production auth system; the roadmap item is real Supabase Auth
with a per-admin account and an `is_admin` role claim, matching the auth
model the Flutter consumer app and `sample_data/seed.sql` already assume.
The FastAPI endpoints the dashboard reads from (`/numbers`, `/reports`,
`/sentinel/jobs`) are not themselves auth-gated in this MVP — they're
read-only aggregate/list views with no PII beyond what `/numbers/{msisdn}`
already exposes to any client; production hardening would add an API key
or service-role check on these routes too.
