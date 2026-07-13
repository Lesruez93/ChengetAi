<!--
  Formatting notes for PDF conversion:
  Font: Avenir or Arial, 11pt body, 1.15 line spacing, 1" margins.
  Target: <=10 pages excluding this cover page and appendices.
  Page breaks are marked with <!-- pagebreak -- > comments below.
-->

# ChengetAI

### AI4I 2026 Innovation Challenge — POTRAZ

**Track 3: Development**

| | |
|---|---|
| **Team Name** | ChengetAI Team |
| **Lead Innovator** | Lester Rusike *(contact: lesterrusike@gmail.com)* |
| **Frontend Developer** | Agnes Goora |
| **Submission Date** | 12 July 2026 |
| **Product** | Mobile-first AI protection app against mobile-money scams, fraud, and fake-number harassment |

*Chengeta (Shona: "to protect, to guard, to care for") — ChengetAI protects Zimbabweans' money and trust in digital financial services using AI tuned for local scam patterns.*

<!-- pagebreak -->

## Executive Summary

ChengetAI is a mobile-first AI application that helps ordinary Zimbabweans, small businesses, and mobile-money agents detect and avoid scams in real time. It combines four capabilities behind one app and one backend: (1) an AI scam-message detector tuned to Zimbabwean patterns such as EcoCash "wrong deposit" reversal scams and fake job offers; (2) a Truecaller-style, crowd-sourced phone-number reputation system; (3) an Agent Fraud Sentinel that applies anomaly detection to mobile-money agent transaction logs for SMEs and agent networks; and (4) a trending-scams feed with a province-level hotspot map. A working backend (FastAPI, 22 passing automated tests), a seeded Postgres schema with Row Level Security, and a Flutter Android-first MVP app are already implemented. This proposal sets out the problem, the technical design, the roadmap to a CCE-ready pilot, our compliance posture under Zimbabwe's Data Protection Act, and a realistic path to sustainability.

**Live demo and evidence hub: [chengetai.vercel.app](https://chengetai.vercel.app)** — the deployed landing page is the single reference point for judges: product screenshots, demo walkthroughs, and mobile app access/download links are hosted there rather than duplicated across this document.

<!-- pagebreak -->

## Section 1: Problem Definition & Strategic Alignment

### 1.1 The problem

Zimbabwe's payments landscape runs overwhelmingly on mobile money. EcoCash, OneMoney, and agent-based cash-in/cash-out networks have become the default way most households and small businesses move money, particularly for the unbanked and underbanked. That dominance is also what makes mobile money the primary attack surface for financial fraud. Scam techniques that are now widely reported in Zimbabwean media, consumer-protection advisories, and everyday household experience include:

- **EcoCash/OneMoney "wrong deposit" reversal scams** — a scammer sends a small deposit notification (real or spoofed) and then pressures the recipient to "reverse" a *larger* amount to a different number, exploiting confusion about how mobile-money reversals actually work.
- **Fake remote job offers** requesting an upfront "registration" or "training" fee.
- **Fake forex deals** where a buyer is asked to send funds first "for verification."
- **"Wrong transfer" scams**, a close cousin of the reversal scam, targeting both individuals and small merchants.
- **Fake NGO/loan offers** preying on people seeking emergency credit or aid.
- **Church/prophet "sow a seed" scams**, which exploit religious trust networks to solicit payments.

These scams are not evenly distributed in their harm. Losses of even modest sums are proportionally devastating for low-income users, and every successful scam erodes trust in digital financial services more broadly — a second-order cost that slows the very financial-inclusion gains mobile money was supposed to deliver. This is a widely reported and growing problem across Zimbabwean media, consumer complaints to telcos and banks, and anecdotal law-enforcement caseloads; we deliberately do not cite a fabricated loss figure here, because no single authoritative, current, and public dataset exists — this gap is itself part of the problem ChengetAI addresses (Section 1.3).

Three structural gaps make this hard to fix with existing tools:

1. **Generic spam/SMS filters do not understand local context.** They are trained on English-language, Western scam corpora and miss Shona-English code-switched text, EcoCash/OneMoney-specific terminology, and Zimbabwe-specific social engineering scripts (church, prophet, "wrong transfer").
2. **There is no shared, citizen-accessible national scam-number database.** Individuals and businesses have no easy way to check "has this number scammed someone else?" before they engage with it — each victim starts from zero.
3. **Mobile-money agents and SMEs — the front line of the cash economy — have no fraud tooling.** Global platforms build fraud detection for banks and large merchants; nobody is building it for a single agent running a till in a rural growth point.

### 1.2 Why AI, specifically

Keyword and rule-based blocklists are a reasonable first line of defense, and ChengetAI ships one (`SCAM_KEYWORD_REASONS`, used both as an explainability layer and as a deliberate baseline for comparison). But scam text is adversarial: phrasing mutates to dodge filters, and messages are frequently code-switched between Shona and English in ways a fixed keyword list cannot anticipate. This is precisely the setting where a trained classifier (and, optionally, a large language model with a few-shot prompt grounded in named local scam patterns) earns its keep over a simpler alternative — and we are careful *not* to reach for AI where it isn't needed (Section 2.2).

### 1.3 Strategic alignment

**Zimbabwe's National AI Strategy.** ChengetAI is a direct, product-level expression of three of the Strategy's stated priorities:

- *Financial inclusion*: mobile money is the inclusion vehicle for the unbanked; protecting it protects the inclusion gains already made, and removing scam risk lowers the trust barrier to first-time mobile-money adoption for cautious, previously-excluded users (older adults, rural households, first-time smartphone owners).
- *Responsible, locally-grounded AI*: ChengetAI is explicit and auditable about where AI is and is not used (Section 2.2), ships a fully synthetic and disclosed training dataset (`docs/dataset_statement.md`), and builds in human-review and dispute paths rather than fully automated, unaccountable decisions (Section 4).
- *Local-language technologies*: the classifier is trained and prompted specifically on Shona-English code-switched text, not adapted from an English-only import — closing a real gap in the local AI tooling landscape.

**NDS1 (National Development Strategy 1).** ChengetAI supports NDS1's digital economy and financial-sector-development pillars by reducing transaction friction caused by fraud risk, and its B2B Agent Fraud Sentinel directly supports NDS1's SME-empowerment agenda by giving small, resource-constrained mobile-money agents a fraud-detection capability that would otherwise only be available to large institutions.

**POTRAZ's consumer-protection mandate.** A shared, crowd-sourced, POTRAZ-adjacent scam-number reputation layer is a natural extension of the regulator's existing consumer-protection role in telecommunications, and the trending-scams feed / hotspot map gives POTRAZ (and telcos, and law enforcement) an early-warning signal for scam campaigns by province and category — turning individual complaints into a national pattern view.

<!-- pagebreak -->

## Section 2: Technical Design & Product Logic

### 2.1 System architecture

```
                         +------------------------------+
                         |         Flutter app           |
   Consumer   ---------->|  Check Message / Number Lookup |
   (share-intent, SMS)   |  Feed (+hotspot map) / auth /  |
                         |  home shell                    |
   SME / Agent  -------->|  Sentinel (CSV upload)          |
                         +---------------+----------------+
                                         | HTTPS / JSON
                                         v
                         +------------------------------+
                         |     Python FastAPI backend    |
                         |                                |
                         |  routers/   -> thin HTTP layer  |
                         |  services/                      |
                         |   |- classifier.py               |  BaselineClassifier (TF-IDF + LogisticRegression)
                         |   |                              |  LLMClassifier (Anthropic API, few-shot prompt)
                         |   |- reputation.py                |  reports, trust weighting, abuse controls
                         |   |- feed.py                       |  weighted-rules trending + hotspots
                         |   |- sentinel.py                    |  IsolationForest + rules hybrid
                         |   \- store.py / supabase_store       |  repository interface
                         |  messaging/sms.py                     |  Twilio, console transport in dev
                         +---------------+----------------+
                                         |
                                         v
                         +------------------------------+
                         |  Supabase (Auth, Postgres,     |
                         |  Row Level Security, Storage)   |
                         |  tables: profiles, numbers,      |
                         |  reports, scam_samples,           |
                         |  feed_items, scam_trend_scores,    |
                         |  sentinel_jobs                      |
                         +------------------------------+
```

The persistence layer sits behind a `Store` protocol (`backend/app/services/store.py`). In development, test, and challenge-evaluation environments it runs against an `InMemoryStore` pre-seeded with realistic sample data, so the full API is runnable with zero external dependencies for judges/reviewers. Setting `USE_SUPABASE=true` swaps in `SupabaseStore` against the schema below with no router or service code changes — the same codebase that judges can run offline is the one that ships to production.

### 2.2 AI models used, and why each was chosen over a simpler alternative

We treat "justify the AI" as a design constraint, not an afterthought — every model in ChengetAI is chosen because a simpler approach was tried or considered and found insufficient for that specific job.

| Capability | Approach | Why this, not simpler |
|---|---|---|
| Message classification (baseline) | TF-IDF + Logistic Regression, trained on the synthetic scam corpus | Fast, fully offline-capable, and inspectable — its learned weights can be audited term-by-term, which matters for a consumer-safety tool judges and regulators need to trust. Outperforms the keyword blocklist on paraphrased and novel scam phrasing while remaining cheap enough to run at scale with no per-call cost. |
| Message classification (LLM strategy) | Anthropic API, few-shot prompt grounded in six named Zimbabwean scam patterns | Handles code-switched Shona-English text and social-engineering phrasing the baseline model has not seen, with natural-language explanations non-technical users can act on. Pluggable per request (`strategy: "baseline" \| "llm"`) so the product can trade off cost/latency against accuracy per use case, and falls back to baseline automatically if no API key is configured — never a hard failure. |
| Keyword blocklist (`SCAM_KEYWORD_REASONS`) | Deliberately naive, hand-written rules | Kept in the codebase on purpose as a comparison baseline and as a UI highlight source. It catches obvious trigger words ("reverse," "registration fee") but misses paraphrases and novel scripts — this gap is exactly what justifies the two classifiers above, and the repo demonstrates the trade-off rather than merely asserting it. |
| Agent Fraud Sentinel | `IsolationForest` (unsupervised anomaly detection) over amount/hour/transaction-type features, combined with explicit rules (structuring, rapid reversal, unusual hours) | Agent-level fraud patterns are unlabeled and drift over time — there is no fixed "fraud/not fraud" ground truth to train a supervised model against in a small MVP dataset, which is exactly the setting unsupervised anomaly detection is built for. The rule layer sits alongside it as an honest, human-readable baseline that catches known patterns even where the model, trained on a small sample, might miss them. |
| Number reputation | **No AI** — plain CRUD with rate limiting, duplicate collapse, and a public-flag threshold | A report count and category breakdown do not need a model; using one here would be exactly the "AI sledgehammer" this rubric warns against. |
| Trending feed / hotspot map | **No AI** — weighted-rules aggregation (report count × recency × reporter trust) over the same `reports` table the reputation system uses | Same reasoning as above. The API response includes an explicit `method_note` field stating this is not an AI/ML model, so the distinction is never blurred in the UI or in review. |

### 2.3 API layer

The backend exposes a small, typed FastAPI surface (`backend/app/routers/`), fully documented in `docs/api.md`:

- `POST /classify` — classify a message; returns verdict (`scam`/`suspicious`/`safe`), confidence, flagged risk phrases with reasons, a plain-language explanation, and which strategy was used.
- `GET /numbers/{msisdn}` — look up a number's reputation (report count, category breakdown, public-flag status, risk level); accepts local or international MSISDN formats.
- `POST /reports` — submit a report against a number; returns `recorded`, `duplicate_collapsed`, or `rate_limited`, and triggers a confirmation SMS when a reporter ID is supplied.
- `GET /feed` and `GET /feed/trending` — editorial feed and the live, weighted-rules trending/hotspot computation.
- `POST /sentinel/analyze` — multipart CSV upload for the B2B Agent Fraud Sentinel; returns flagged transactions with anomaly scores and human-readable reasons.
- `GET /health` — liveness check.

Every write endpoint validates input via Pydantic models before it reaches business logic, and rate limiting is enforced with `slowapi`.

### 2.4 Database schema

Supabase Postgres, all tables under Row Level Security (`sample_data/seed.sql`):

| Table | Purpose | Key RLS behaviour |
|---|---|---|
| `profiles` | 1:1 with `auth.users`; carries `trust_score` and `consent_given_at` | Self-read, self-update, self-insert only |
| `numbers` | Denormalized reputation cache per MSISDN | Publicly readable; writes only via backend service-role key |
| `reports` | Individual community reports against a number | Publicly readable; insert restricted to the authenticated reporter |
| `scam_samples` | Labeled corpus backing the baseline classifier | Publicly readable |
| `feed_items` | Editorial/aggregated trending-scam entries | Publicly readable |
| `scam_trend_scores` | Cached output of the trending-feed computation | Publicly readable |
| `sentinel_jobs` | Audit log of B2B Sentinel CSV analyses | Self-read/self-insert only (owner-scoped) |

### 2.5 Offline behaviour

Connectivity in Zimbabwe is not uniform, and the MVP is designed around that reality rather than assuming always-on data. The Flutter app caches the top-N flagged numbers (by `report_count`) from `/numbers` lookups locally, so the most common protective action — "is this number flagged before I call back or send money?" — works without connectivity, which matters most for prepaid users in low-signal areas. Message classification and CSV Sentinel analysis require connectivity in the current MVP; client-side (on-device) model execution for the baseline classifier is a near-term roadmap item precisely to extend offline coverage to the highest-value feature.

### 2.6 Abuse-resistance of the reputation system

A crowd-sourced number-reputation system is only trustworthy if it resists being weaponized. ChengetAI's reputation layer is deliberately conservative:

- **Rate limiting** — `REPORT_RATE_LIMIT_PER_HOUR` (default 5) caps how many reports a single reporter can submit per hour; excess reports are rejected outright (`rate_limited`, not persisted).
- **Duplicate collapse** — a reporter re-reporting the same number and category within 24 hours is recorded for audit purposes but contributes zero trust weight, so it cannot be used to artificially inflate a number's flag status.
- **Public-flag threshold** — `NUMBER_PUBLIC_FLAG_THRESHOLD` (default 3) requires multiple distinct, corroborating reports before a number is shown as "publicly flagged" to other users, so a single hostile or mistaken report cannot brand an innocent number a scammer.
- **Dispute path (roadmap)** — a number owner will be able to contest a flag, with disputed flags hidden pending human review, closing the loop on the defamation and fairness risks these controls are designed against (see Section 4.3).

<!-- pagebreak -->

## Section 3: Deliverables & CCE Implementation Roadmap

### 3.1 What is already built

- FastAPI backend with the full API surface in Section 2.3, running against either an in-memory store (zero external dependencies, used for judge/reviewer evaluation) or Supabase Postgres.
- 22 passing automated tests (`pytest`) covering classifier accuracy on known scam/legit examples, rate limiting and duplicate collapse, public-flag thresholds, trending-feed ranking and window exclusion, hotspot coverage, and Sentinel anomaly detection against injected fraud patterns.
- A seeded Supabase schema with Row Level Security across all seven tables (`sample_data/seed.sql`).
- A synthetic, fully disclosed scam-message corpus (143 labeled messages, six scam categories) and transaction dataset (200 transactions, 20 injected anomalies) with generation scripts, documented in `docs/dataset_statement.md`.
- A Flutter Android-first MVP app covering Check Message, Number Lookup, Feed (trending + hotspot), Sentinel CSV upload, minimal authentication, and a home shell.
- Version-pinned dependency manifest (`backend/requirements.txt`) — every package pinned to an exact version (e.g. `fastapi==0.115.6`, `scikit-learn==1.6.0`, `pandas==2.2.3`), so the CCE build is fully reproducible and not exposed to upstream breaking changes during evaluation.
- A deployed Next.js landing page at **[chengetai.vercel.app](https://chengetai.vercel.app)**, serving as the public demo hub (screenshots, walkthroughs, mobile app links) referenced throughout this proposal instead of duplicating evidence inline.

### 3.2 Milestones

| Phase | Timeframe | Deliverable |
|---|---|---|
| Bootcamp (current) | Weeks 0–4 | Harden existing MVP: finalize proposal, expand test coverage, package backend for ZCHPC CCE deployment, polish Flutter UX for demo day |
| Pilot readiness | Month 1–3 | Real-world data intake pipeline (in-app "Report this message" consented submissions), dispute/human-review flow for flagged numbers, pilot agreement with one agent network or telco district (Section 5.3), initial LLM-classifier cost monitoring in production |
| Scale-up | Month 4–6 | Client-side (on-device) baseline classifier for full offline coverage, multi-agent Sentinel dashboards for SME/agent-network customers, expanded scam corpus incorporating real (anonymized, consented) reports, integration exploration with telco SMS gateways for at-scale number lookups |
| Institutionalization | Month 7–12 | POTRAZ / telco / bank partnership for a shared national scam-number signal, iOS release, Ndebele-language support, formal Data Protection Act compliance audit, sustainability model live (Section 5) |

### 3.3 Compute requirements

ChengetAI's compute footprint is intentionally modest, in keeping with a lean, cost-conscious pilot:

- **Baseline classifier and Sentinel (`IsolationForest`)**: CPU-only, scikit-learn; no GPU required. Both train in seconds to low-single-digit minutes on the current dataset sizes and re-train cheaply as the corpus grows.
- **LLM classifier**: no local compute — calls the Anthropic API; the compute cost is a per-request API cost, not infrastructure to provision (see Section 5.4 for budget treatment).
- **Backend**: a single small FastAPI instance (e.g. 1–2 vCPU, 1–2GB RAM) comfortably serves MVP/pilot-scale traffic; horizontal scaling is straightforward given the stateless request handling and externalized Postgres store.
- **Database**: Supabase's managed Postgres free/starter tier is sufficient through pilot scale; upgrade triggers are storage and concurrent-connection growth, not compute-bound ML workloads.

### 3.4 ZCHPC CCE testing plan

We propose the following validation plan on the Zimbabwe Centre for High Performance Computing's Cyber Centre of Excellence (CCE) environment:

1. **Reproducible build verification** — install from the pinned `requirements.txt` in a clean CCE container and confirm all 22 automated tests pass with no version drift, demonstrating the submission is exactly what judges will run.
2. **Load and latency testing** — benchmark `/classify` (both strategies) and `/sentinel/analyze` under representative concurrent load to validate the compute sizing in Section 3.3 before committing to production infrastructure.
3. **Security testing** — run the CCE's standard security scanning against the FastAPI service (input validation via Pydantic, rate limiting via `slowapi`, dependency vulnerability scanning against the pinned manifest) and against the Supabase RLS policies (attempt cross-tenant reads/writes to confirm policy enforcement).
4. **Offline/degraded-network simulation** — validate the Flutter app's cached-number-lookup behaviour under simulated low-connectivity conditions representative of rural Zimbabwean network coverage.
5. **Model evaluation on CCE hardware** — re-run classifier and Sentinel evaluation metrics on CCE infrastructure to produce an independent, reproducible accuracy baseline judges and future partners can cite, rather than relying solely on our own reported numbers.

<!-- pagebreak -->

## Section 4: Compliance & Risk Mitigation

### 4.1 Data Protection Act (Zimbabwe) compliance

ChengetAI is designed around the Data Protection Act's core obligations rather than treating them as an afterthought:

- **Consent-first data collection.** Signup requires an explicit consent checkbox before any report submitted by that user is attributed to them, recorded as a timestamp in `profiles.consent_given_at` (`sample_data/seed.sql`). No report is silently attributed to a user who has not consented.
- **Data minimization.** Message content is not stored beyond a short `message_excerpt` used to give context on a report; full message bodies are never persisted to the database.
- **Fair processing and contestability.** Phone numbers are quasi-personal data. The public-flag threshold (Section 2.6) means no individual is publicly labeled from a single report, and the roadmap dispute/human-review path (Section 4.3) gives a flagged number's owner a route to contest an automated-adjacent decision — a right the Act is oriented around.
- **Synthetic-first training data.** Both shipped datasets (`sample_data/scam_corpus.jsonl`, `sample_data/transactions_sample.csv`) are entirely synthetic — no real user messages, phone numbers, or transaction records were used to build or evaluate the current models, fully disclosed with generation methodology in `docs/dataset_statement.md`. Any future transition to real, reported data will be consent-based (the in-app "Report this message" flow) and, for agent transaction data, pseudonymized (MSISDNs and agent identities) before it reaches the Sentinel service, under a data-sharing agreement with the pilot partner.

### 4.2 False-positive risk and human review

An AI classifier that wrongly labels a legitimate message as a scam has a real cost — eroded trust in the tool and, potentially, a missed legitimate transaction. ChengetAI mitigates this in three ways: (1) the baseline classifier returns a calibrated confidence score, not a bare label, so borderline cases are visibly uncertain to the user rather than presented as fact; (2) risk phrases are surfaced with explanations so a user can evaluate the reasoning rather than trust a black-box verdict; (3) the LLM strategy's `matched_category` and natural-language explanation give the same transparency for cases the keyword/baseline layers cannot resolve confidently. A dispute/human-review path (Section 2.6, Section 4.3) extends the same contestability principle to the number-reputation side of the product.

### 4.3 Defamation risk on number-flagging

Publicly labeling a phone number as a scam number carries real reputational and defamation risk if done carelessly — a single malicious or mistaken report could brand an innocent number a scammer. This risk is already mitigated in the implemented system, not merely planned for:

- **Rate limiting** (`REPORT_RATE_LIMIT_PER_HOUR`) prevents a single actor from flooding reports against a target number.
- **Duplicate collapse** prevents the same reporter from inflating a number's apparent report count by repeating the same complaint.
- **`NUMBER_PUBLIC_FLAG_THRESHOLD`** requires multiple distinct, corroborating reports (default 3) before a number is shown as publicly flagged — the single largest structural defense against a defamation claim, since no individual report or reporter can unilaterally brand a number.
- **Roadmap dispute path** gives a flagged number's presumed owner a route to contest the flag, with disputed flags hidden pending human review, closing the loop between "flagged" and "adjudicated."

### 4.4 Automated test coverage

The backend ships 22 passing `pytest` tests exercising exactly the risk surfaces above, not just happy-path functionality:

- `test_classifier.py` — `test_baseline_flags_ecocash_reversal_scam`, `test_baseline_treats_bank_notice_as_safe`, `test_get_classifier_falls_back_to_baseline_without_api_key` (verifies the LLM strategy degrades safely rather than failing when unconfigured), `test_risk_phrases_extracted_for_upfront_fee_scam`.
- `test_reputation.py` — `test_rate_limiting_kicks_in_after_threshold`, `test_public_flag_threshold_requires_multiple_reports`, `test_submit_report_then_lookup_reflects_report_count`, plus MSISDN normalization/validation tests.
- `test_feed.py` — `test_trending_feed_ranks_categories_by_weighted_score`, `test_trending_feed_excludes_reports_outside_window`, `test_hotspots_cover_all_provinces`.
- `test_sentinel.py` — `test_analyze_transactions_flags_injected_anomalies`, `test_analyze_transactions_rejects_missing_columns`, `test_analyze_transactions_rejects_empty_file`.
- `test_api.py` — end-to-end coverage of every endpoint, including `test_lookup_invalid_number_returns_422` for input-validation behaviour.

### 4.5 Security posture

- **Authentication**: Supabase Auth backs all user identity; the backend never stores or manages raw credentials.
- **Authorization**: Row Level Security policies on every table (Section 2.4) enforce self-scoped access for `profiles` and `sentinel_jobs`, reporter-scoped inserts for `reports`, and service-role-only writes to the derived `numbers` cache — access control is enforced at the database layer, not only in application code.
- **Rate limiting**: `slowapi`-enforced limits on report submission (Section 2.6), reducing both abuse and basic denial-of-service exposure.
- **Input validation**: every request body is validated against a Pydantic model before reaching business logic, and malformed input (e.g. invalid MSISDNs) returns structured `422` responses rather than undefined behaviour.
- **Reproducible, auditable dependencies**: every backend package is version-pinned (Section 3.1), so the security surface under review is exactly the one running in production, and a CVE affecting an unpinned transitive dependency cannot silently change what was evaluated.

<!-- pagebreak -->

## Section 5: Sustainability & Future Adoption

### 5.1 Revenue model

ChengetAI is designed as a two-sided product with distinct, complementary revenue paths:

- **Consumer (freemium)**: the Scam Message Detector, Number Lookup, and Trending Feed/Hotspot map remain free for individual consumers — this is where financial-inclusion and trust-building impact is greatest, and where willingness-to-pay is lowest. A premium consumer tier (e.g. unlimited LLM-strategy classifications, priority number-lookup, ad-free feed) is a plausible future addition once usage data justifies it, but is not assumed in the near-term budget below.
- **B2B — Agent Fraud Sentinel licensing**: mobile-money agents, agent networks, and SMEs are the primary paying customer for Sentinel — a monthly per-agent or per-till licence fee for anomaly-detection dashboards over their own transaction logs, priced to be affordable at agent-network scale rather than enterprise-SaaS scale.
- **Institutional licensing**: telcos and banks are natural licensees of an aggregated, anonymized scam-signal feed (the trending/hotspot data) for their own fraud and consumer-protection operations; POTRAZ itself is a plausible institutional partner given its consumer-protection mandate (Section 1.3), potentially as a co-funder of the shared national scam-number signal described in the Month 7–12 roadmap.

### 5.2 Cost drivers

The three material recurring costs, in descending order of scale-sensitivity:

1. **LLM API calls** (Anthropic API, `LLMClassifier` strategy) — scales with message-classification volume; the baseline TF-IDF/LogisticRegression strategy exists specifically as a zero-marginal-cost fallback the product can lean on more heavily if LLM volume costs grow faster than revenue.
2. **Hosting** — FastAPI backend compute plus Supabase managed Postgres; both modest at pilot scale (Section 3.3) and scale roughly linearly with active users.
3. **SMS delivery** (Twilio, for report confirmations and future alert notifications) — usage-based, and the backend already supports a no-cost console transport for development so this cost is incurred only in production.

### 5.3 Pilot proposal

We propose piloting with **one mobile-money agent network or one telco district** — a bounded, measurable scope that lets us validate both the consumer classifier's real-world accuracy and the Sentinel's fraud-detection value against real (consented, pseudonymized) transaction data, before any wider rollout. Success criteria for the pilot would include: classifier precision/recall against real reported messages (compared to the current synthetic-corpus baseline), Sentinel true-positive rate against agent-confirmed fraud cases, and reporter engagement/retention on the number-reputation feature.

### 5.4 Budget estimates

The figures below are **honest, order-of-magnitude estimates** for an early-stage pilot in the Zimbabwe context, not a fully costed procurement — they are offered to demonstrate financial realism, not precision, and should be revisited once real usage and partner terms are known.

**3-month bootstrap/pilot-readiness budget (approximate, USD):**

| Item | Estimate (USD) | Basis |
|---|---|---|
| Hosting (backend + Supabase) | $150–300 | Small managed Postgres tier + a 1–2 vCPU backend instance for 3 months |
| LLM API usage (classifier + limited pilot volume) | $200–500 | Low-thousands of classification calls/month at current Anthropic API pricing, biased toward the free baseline strategy for high-volume traffic |
| SMS (Twilio, report confirmations) | $50–150 | Pilot-scale confirmation volume only |
| Domain, TLS, misc. dev tooling | $50–100 | — |
| **3-month subtotal** | **≈ $450–1,050** | |

**12-month pilot-to-early-scale budget (approximate, USD):**

| Item | Estimate (USD) | Basis |
|---|---|---|
| Hosting (backend + Supabase, scaled tier) | $1,200–2,500 | Growing user base, still well within a single small managed instance |
| LLM API usage | $1,500–4,000 | Higher classification volume as consumer adoption grows; wide range reflects uncertainty in eventual mixed baseline/LLM traffic split |
| SMS delivery | $600–1,500 | Report confirmations plus early alert notifications |
| Pilot partner integration & data-sharing agreement costs (legal/admin) | $500–1,500 | Formalizing the agent-network or telco-district pilot (Section 5.3) |
| Contingency (10–15%) | ~$400–1,000 | Standard early-stage buffer |
| **12-month subtotal** | **≈ $4,200–10,500** | |

These ranges deliberately exclude personnel costs, which depend on team composition and funding structure the challenge process itself will help determine; they cover infrastructure and direct operating costs only. We consider this level of specificity — real ranges tied to named cost drivers, rather than a single unsourced total — more useful to reviewers than false precision.

<!-- pagebreak -->

## Section 6: Team Capability & Implementation Plan

### 6.1 Team roster

| Member | Role | Primary responsibility |
|---|---|---|
| **Lester Rusike** | Lead Innovator | Product strategy, backend/AI engineering (FastAPI, classifier, Sentinel), system architecture, Supabase schema and security design, compliance posture, and this proposal. |
| **Agnes Goora** | Frontend Developer | Flutter (Android-first MVP) and web (Next.js landing page / admin dashboard) UI implementation. |

### 6.2 Skills coverage and gaps

The team currently covers product/backend engineering and frontend/mobile development directly.
Two gaps are disclosed honestly rather than glossed over:

| Gap | How it will be filled |
|---|---|
| Dedicated business/legal support for the pilot data-sharing agreement and the formal Data Protection Act compliance audit (proposal §3.2, "Institutionalization" phase) | Bootcamp mentorship and partner-network introductions (POTRAZ/CCE); a legal/compliance advisor is a targeted addition ahead of the pilot-readiness phase, not the bootcamp phase. |
| Dedicated QA/security specialist | Currently covered by the automated test suite (22 `pytest` tests) and the CCE security testing plan (proposal §3.4); a broader security review is planned for the ZCHPC CCE testing pass rather than assumed to be unnecessary. |

No other external code, datasets, or paid tools beyond what is already disclosed in this proposal
(Anthropic API for the LLM classifier strategy, Supabase, Twilio) were used. The synthetic training
datasets (`sample_data/`) were generated by the team, not sourced from a third party.

### 6.3 Ownership after the challenge

**Lester Rusike (Lead Innovator)** is the named operator responsible for hosting, maintenance, and
communication after the challenge (see `docs/deployment_plan.md` → Operator), until the team roster
grows during the pilot-readiness phase.

### 6.4 30-day and 90-day plan

Reflects the milestone table in proposal §3.2 and §12.2 of the ToR, with named ownership:

| Period | Focus | Owner |
|---|---|---|
| 0–30 days | Clean codebase, harden MVP from judge feedback, confirm pilot partner (currently a target profile, not yet secured — see `docs/deployment_plan.md`), complete the security checklist (`docs/risk_compliance_checklist.md`) | Lester Rusike |
| 31–60 days | Run pilot with limited users, collect feedback (`docs/usability_testing.md`), fix defects, improve user onboarding | Lester Rusike (backend/pilot), Agnes Goora (UI fixes from feedback) |
| 61–90 days | Prepare adoption case, refine business model, finalize support plan, update technical documentation | Lester Rusike |
