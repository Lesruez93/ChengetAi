# ChengetAI Architecture

## System diagram

```
   Consumer                  SME / Agent              Public visitor      Moderator / partner
   (share-intent, SMS)                                (landing page)      (admin dashboard)
          │                       │                          │                    │
          ▼                       ▼                          ▼                    ▼
   ┌──────────────────────────────────────┐   ┌───────────────────────────────────────┐
   │            Flutter app                │   │           Next.js web app (web/)        │
   │  check_message / lookup / support      │   │  /        → marketing landing page       │
   │  feed (+hotspot maps) / sentinel /     │   │  /admin/* → password-gated dashboard:     │
   │  auth / home                           │   │  overview, reports, numbers, sentinel jobs│
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
                         │   ├─ countries.py             │  country registry: the locale source of truth
                         │   ├─ taxonomy.py              │  scam categories + per-category first action
                         │   ├─ support.py               │  per-country escalation ladder
                         │   ├─ redaction.py             │  evidence minimisation at intake
                         │   ├─ classifier.py            │
                         │   │   ├─ BaselineClassifier    │  TF-IDF + LogisticRegression
                         │   │   └─ LLMClassifier         │  Anthropic API, market-grounded prompt
                         │   ├─ reputation.py             │  E.164 normalisation, trust, abuse controls
                         │   ├─ feed.py                   │  weighted-rules trending + 2-level hotspots
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

## One codebase, several markets

ChengetAI covers Zimbabwe, Kenya, Nigeria, Uganda, South Africa, Ghana and
Tanzania. Almost every "local" detail differs between them — dial code and
number format, which wallets people use, what the first-level administrative
unit is called, which languages scam messages arrive in, and which desk you
call after a loss.

Rather than fork per country, all of that lives in one immutable registry
(`services/countries.py`) plus one support-channel table
(`services/support.py`). **Adding a market is a data change in two files.** No
service logic, no client release, no new model.

Three decisions follow from that, and they are the ones worth arguing about:

1. **Numbers are stored in E.164, never national format.** Local forms collide
   outright across our markets: `0771234567` is a valid Zimbabwean, Ugandan
   *and* Tanzanian number. A national-format key would silently merge three
   unrelated people's reputations — a failure invisible in a single-country
   demo and catastrophic in a regional deployment.

2. **One classifier, localised grounding.** The scam *mechanism* generalises
   even when its vocabulary does not — "reverse this deposit you did not
   receive" is the same attack in Harare and Lagos — so one model trained
   across all seven markets sees far more examples of each pattern than seven
   per-country models would. What is localised is the prompt's grounding
   (wallets, currency, languages) and the risk-phrase vocabulary. Correspondingly,
   the scam taxonomy names mechanisms, not brands: `mobile_money_reversal`,
   not `ecocash_reversal`.

3. **Region buckets are coarse, and there are two hotspot maps.** Region lists
   are 4-16 buckets per country, not exhaustive administrative lists: the map
   exists to answer "is this wave near me?", and a 47-county or 36-state map
   answers that worse, because each bucket holds too few reports to mean
   anything. And a single regional map across seven countries would split the
   same volume across 60+ buckets and render everything green, so the feed
   returns a cross-country rollup always, and the within-country breakdown only
   when a country is named.

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

Reaching for a model where simpler logic would do is its own failure mode,
so each choice below is justified rather than assumed.

**AI is used for:**

1. **Message classification** (`services/classifier.py`) — two strategies:
   - `BaselineClassifier`: TF-IDF + logistic regression trained on
     `sample_data/scam_corpus.jsonl`. Fast, offline, fully inspectable via
     learned weights.
   - `LLMClassifier`: Anthropic API with a few-shot prompt grounded in the
     caller's market — its wallets, currency and languages — over a taxonomy of
     mechanisms (wrong-deposit reversal, fake jobs, fake investment, fake
     loans/grants/aid, SIM swap, OTP/identity phishing, impersonation,
     faith-based seed requests).

   *Why AI at all, and not a keyword blocklist?* Scam text is adversarial and
   code-switched (Shona/English, Swahili/English, Pidgin, isiZulu), and
   phrasing mutates constantly to dodge filters. `SCAM_KEYWORD_REASONS` in `classifier.py`
   doubles as both a UI highlight list *and* a naive-rules comparison point:
   it catches obvious cases ("reverse", "registration fee") but misses
   paraphrases, novel scripts, and messages with no trigger word at all —
   exactly the gap the trained/LLM classifiers close. The repo ships both
   strategies specifically so this trade-off is demonstrable, not asserted.

   *Why a multi-country training corpus?* A corpus drawn from one market
   teaches the model that the local wallet's **name** is the signal — the exact
   overfit that makes generic spam filters useless here, reappearing one
   country over. `sample_data/generate_scam_corpus.py` emits every pattern for
   every market so the learned weight lands on the mechanism instead.

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
- **Trending feed / hotspot maps** (`services/feed.py`) — a weighted-rules
  aggregation (`report count × recency × reporter trust`) over the same
  `reports` table the reputation system uses. The response body says so
  explicitly (`method_note` field) so this is never mistaken for an AI
  output in the UI or in review.
- **Support pathways** (`services/support.py`) — a curated, human-maintained
  registry of who to contact per country. Who to call after a fraud is too
  consequential to generate: a hallucinated police hotline is worse than no
  hotline at all. Each entry carries a `verified` flag, and unverified contacts
  are surfaced to the user *as unverified* rather than hidden, because shipping
  an unconfirmed emergency number as fact is its own safety failure.
- **Evidence redaction** (`services/redaction.py`) — deterministic regex
  patterns, so what is and is not removed from a stored excerpt is auditable
  and testable rather than a model's judgement call.

## Offline behaviour

The Flutter app caches recent `/numbers` lookups locally, so a repeat "is this
number flagged?" check works without connectivity — the common case for prepaid
users in low-signal areas. The country registry and category list are also
**bundled into the app** rather than only fetched, so the report form and
country picker render instantly and work offline; `GET /reference/countries`
overlays them when the network is available, letting a newly added market
appear without an app release.

Message classification and CSV analysis require connectivity in the MVP
(client-side model execution is a roadmap item). The support pathway currently
requires connectivity too, which is the most important gap of the three —
caching it per country is the next offline item, since needing help and having
no signal frequently coincide.

## Safe reporting

The Safety, Reporting & Protection problem is not only detection. Two design
decisions carry most of the weight here:

**Anonymous reporting is the default, and it is a real trade-off — not a
checkbox.** Omitting `reporter_id` files a report that still counts toward a
number's reputation, with nothing linking it to the reporter or to their other
reports. The cost is that anonymous reports cannot be rate-limited or
duplicate-collapsed per reporter. We accept that cost deliberately: requiring
an identity to report is a barrier for exactly the people most exposed to
retaliation, and the abuse controls it would buy are recovered downstream by
the public-flag threshold, which no single reporter can clear alone. The app
also offers a non-anonymous mode backed by a random on-device id
(`ReporterIdentity`) — not a name or an account — which buys back duplicate
detection and a confirmation for users who want them.

**Excerpts are redacted at intake, not at render time.** A reporting tool
accumulates other people's messages, and those carry identifiers belonging to
people who never consented to anything: the victim's account number, a third
party's phone number, a still-live OTP. Redaction at render time protects the
screen; redaction at intake protects the database, so a future breach of it is
not also a breach of them. What survives is the scam's wording — what the
classifier learns from and a moderator reads. What does not survive is anything
identifying a person or unlocking an account.

**Every non-safe verdict carries a pathway.** `POST /classify` returns
`next_steps`, and `GET /support/{country}` gives the full ordered ladder
(wallet → regulator → police → support). A verdict that does not tell you who
to call leaves the user exactly where it found them, which is the failure mode
of most scam-detection tooling.

## Abuse-resistance of the reputation system

Anyone can report a number, so the system is designed to resist being
weaponized against innocent numbers:

- **Rate limiting**: `REPORT_RATE_LIMIT_PER_HOUR` caps reports per identified
  reporter (see the anonymity trade-off above).
- **Duplicate collapse**: the same reporter re-reporting the same
  number+category within 24h is recorded but contributes zero trust weight.
- **Public-flag threshold**: a number is only shown as "publicly flagged"
  after `NUMBER_PUBLIC_FLAG_THRESHOLD` distinct reports, so a single hostile
  report can't brand a number a scammer (defamation risk, see the proposal's
  Compliance & Risk Mitigation section).
- **Cross-border escalation**: a number reported from more than one country
  goes to `high` risk regardless of volume — cross-border reach indicates an
  organised operation rather than a local dispute between two people who know
  each other.
- **Dispute path** (roadmap): a number owner can contest a flag; disputed
  flags are hidden pending human review. This matters more in a multi-country
  deployment, not less: a flag raised in one market now follows a number into
  every other.

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
