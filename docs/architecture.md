# ChengetAI Architecture

## System diagram

```
   Consumer                  SME / Agent              Public visitor      POTRAZ / internal
   (share-intent, SMS)                                (landing page)      (admin dashboard)
          │                       │                          │                    │
          ▼                       ▼                          ▼                    ▼
   ┌──────────────────────────────────────┐   ┌───────────────────────────────────────┐
   │            Flutter app                │   │           Next.js web app (web/)        │
   │  analyze / lookup / protect / feed     │   │  /        → marketing landing page       │
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
                         │   ├─ analyze.py                │  entity split + worst-of combination
                         │   ├─ entities.py / link_check  │  URL + MSISDN extraction, URL heuristics
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

## Live call & SMS screening

Incoming calls and messages are screened on the handset (Android only), so the
app answers "is this number reported?" without the user having to type anything
into the lookup screen.

**How it fits together**

```
  GET /numbers/flagged/sync ──► ProtectionStore (native SharedPreferences)
   (publicly-flagged set,              │
    content-hash versioned)            ├──► ScamCallScreeningService  (incoming call)
                                       └──► SmsScamReceiver           (incoming SMS)
```

**Matching is local, never a per-call API request.** Asking the backend "who is
calling me?" on every ring would hand the server a live log of each user's
contacts and call times — a surveillance dataset the project has no need for and
`docs/risk_compliance_checklist.md` commits to avoiding. Instead the flagged set
is pulled down in bulk and matched on the device. The blocklist download is the
only network traffic the feature generates, and it carries no information about
the user.

**Only publicly-flagged numbers sync.** A number in this payload produces an
automatic accusation on screen during a live call, with nobody reviewing it
first. `NUMBER_PUBLIC_FLAG_THRESHOLD` therefore matters more here than anywhere
else in the app, and the sync endpoint applies it rather than shipping every
number with a single report against it.

**Permissions are deliberately minimal.** Call screening uses the platform
`CallScreeningService` behind `ROLE_CALL_SCREENING`, which needs no permission
at all — the app never requests `READ_CALL_LOG` or `READ_PHONE_STATE`. SMS
screening uses `RECEIVE_SMS` only; `READ_SMS` is not requested, so the existing
inbox is never read. The app is not the default SMS handler and never hides,
alters, or replies to a message.

**SMS bodies stay on the device.** The message text is scanned against a short
local phrase list (`SmsHeuristics`), not sent to `/classify` — auto-uploading
every incoming message would turn a scam warning into message interception. The
trade is real: the local list is weaker than the trained classifier and will miss
novel phrasing, which the Protection screen states plainly, with the manual
"check this message" path as the fallback.

**Known gaps.** There is no background sync service; the blocklist refreshes when
the app is opened, and the Protection screen shows its age with a warning past a
day. iOS cannot implement this: it exposes no incoming-SMS API, and its
`CallDirectory` extension only matches against a pre-loaded list with no
callback, so no per-call explanation is possible.

## Universal analyzer

`POST /analyze` accepts an arbitrary paste — message text, links, phone numbers,
or all three — rather than requiring the user to decide which endpoint their
content belongs to. `services/entities.py` splits the text, each part goes to the
checker that can judge it (classifier / reputation store / URL heuristics), and
the verdict is the **worst** finding, not an average: bland wording carrying a
link to a lookalike banking domain is a phishing attempt, and averaging would
report it as fine.

Link assessment (`services/link_check.py`) judges the address only — nothing
fetches the URL. Resolving attacker-supplied addresses would make the backend an
SSRF vector against internal hosts and a way to have our server register clicks
on someone else's phishing page. Consequently a clean-looking address returns
`unknown`, kept distinct from `low`, and the UI never presents it as "safe".

Rules rather than a model, for the same reason as `reputation.py`: each signal
must be explainable in one sentence, and brand-impersonation detection is
exact-match logic over a list of Zimbabwean institutions, not a learned boundary.

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
