# Risk & Compliance Checklist

Standalone privacy, security, bias and misuse checklist for ChengetAI. Narrative reasoning for each
item is in `docs/dataset_statement.md` and `docs/architecture.md`; this page is the checklist form.

## Risk level (self-assessed)

**Medium risk**: the product handles user accounts, real operational data
(once piloted), citizen reports, and quasi-personal data (phone numbers), but not health, finance,
identity, or biometric data. Expected controls at this level: access control, consent where
relevant, logs, testing, and clear disclaimers — all addressed below.

## Minimum safeguards

| Safeguard | Status | Evidence |
|---|---|---|
| **Data minimisation** | Yes | Full message bodies are never persisted — only a short `message_excerpt`, **redacted at intake** (`backend/app/services/redaction.py`) so phone numbers, emails, links, OTPs and identity numbers never reach any store. Redaction happens before the record leaves the request handler, not at render time. |
| **Consent** | Yes | Signup requires an explicit consent checkbox before any report is attributed to a user, timestamped in `profiles.consent_given_at` (`sample_data/seed.sql`). Reporting itself needs no account at all — anonymous reports carry no reporter identifier, so there is nothing to consent to. |
| **Access control** | Yes | Row Level Security on every Supabase table: self-scoped access for `profiles`/`sentinel_jobs`, reporter-scoped inserts for `reports`, service-role-only writes to `numbers` (`docs/architecture.md` → database schema table). Anonymous reports are inserted via the backend's service-role key rather than an anon client, so the intake path still applies validation, redaction and rate limiting. |
| **Authentication** | Yes | Supabase Auth backs all user identity; the backend never stores or manages raw credentials. |
| **Secrets management** | Yes | No passwords, API keys, or tokens committed to the repo; `.env.example` files ship without secrets in `backend/` and `web/`. |
| **Encryption** | Yes | Supabase provides encryption in transit (TLS) and at rest by default on its managed Postgres; verified against the live "chengetAI" project (region eu-west-2), which is now connected and serving the backend. |
| **Auditability** | Partial | `sentinel_jobs` acts as an audit log for Sentinel analyses; general action logging (who changed what, when) beyond this is a roadmap item (see `docs/deployment_plan.md` → Monitoring). |
| **Human oversight** | Yes | Classifier returns a confidence score and explanation rather than a bare verdict; number-flagging requires multiple corroborating reports before going public, and a dispute/human-review path is roadmap. **Support contacts are never model-generated** — they are a curated registry with a per-entry `verified` flag, and unverified entries are surfaced to the user as unverified rather than hidden. |
| **Misuse risk** | Yes | Addressed explicitly below (§ "Misuse risks and mitigations"). |
| **Bias and fairness** | Partial | Classifier is trained on a synthetic corpus covering eight scam mechanisms across seven markets (`docs/dataset_statement.md`). The corpus is **English-only**, so the product systematically under-serves users who do not read English comfortably — who, across these markets, overlap heavily with those most exposed to mobile-money fraud. That is a fairness limitation stated plainly rather than a gap in the data (`docs/accessibility.md`). No formal bias/fairness audit against demographic subgroups has been run, since all training data is synthetic rather than drawn from a real, demographically-labeled population. |

## Misuse risks and mitigations

| Misuse scenario | Mitigation |
|---|---|
| A malicious user floods reports against an innocent number to get it publicly flagged (defamation risk). | Rate limiting (`REPORT_RATE_LIMIT_PER_HOUR`), duplicate collapse within 24h, and a public-flag threshold requiring multiple distinct corroborating reports (`NUMBER_PUBLIC_FLAG_THRESHOLD`, default 3). Note the deliberate trade-off: anonymous reports bypass per-reporter rate limiting and duplicate collapse, so the public-flag threshold carries more of the load for them. |
| A user over-trusts an AI "safe" verdict on a genuinely dangerous message (false negative). | Confidence score is always shown, not a bare label; risk phrases are surfaced with explanations so the user can evaluate reasoning rather than trust a black-box verdict. |
| Sentinel flags a legitimate agent transaction as fraud, harming a real agent's standing. | Explicit rule layer alongside the unsupervised model gives a human-readable reason for every flag, not just an opaque anomaly score, so a flagged agent's manager can review the specific reason. |
| Scraping or bulk-querying the number-lookup endpoint to build a shadow database of phone numbers. | Roadmap item — not yet rate-limited or access-controlled separately from the report-submission endpoint. **Flagged here as an open gap**, to be addressed before wider pilot rollout. |
| A user acts on a support contact that turns out to be wrong, losing time in the window where a transfer was still recoverable. | Every channel carries a `verified` flag; unverified contacts are shown with an explicit "confirm this before relying on it" caveat rather than presented as fact, and the universal steps lead with the actions that need no phone number at all. Verifying every contact in a market is a **blocking prerequisite** for piloting there (`docs/deployment_plan.md`). |
| A flag raised in one market follows a number into every other, amplifying a wrongful report across borders. | The public-flag threshold applies globally, and cross-border reports escalate risk — which cuts both ways. The dispute/human-review path (roadmap) matters more here, not less; **disclosed as an unresolved gap**, not a solved problem. |

## Data-protection compliance (multi-jurisdiction)

The markets covered have overlapping but non-identical regimes: Zimbabwe's Data Protection Act,
Kenya's Data Protection Act 2019, Nigeria's NDPA 2023, Uganda's Data Protection and Privacy Act
2019, South Africa's POPIA, Ghana's Data Protection Act 2012, and Tanzania's Personal Data
Protection Act 2022. The controls below target the **common floor** of all of them. A
per-jurisdiction review — including data residency and whether a local representative must be
registered — is required before any pilot with real user data and is **not** claimed as done.

| Control | Status | Evidence |
|---|---|---|
| Lawful basis for collection | Yes | Consent-first signup; synthetic-only training data today (no real personal data collected yet). |
| Fair processing / contestability | Partial | Public-flag threshold protects against single-report harm; formal dispute/human-review workflow is roadmap, not yet built. |
| Data minimisation | Yes | See above. |
| Anonymisation plan for future real data | Yes (planned) | Any transition to real reported messages or agent transaction data will pseudonymize MSISDNs/agent identities before reaching the Sentinel service, under a data-sharing agreement with the pilot partner. |

## Known open gaps (disclosed, not hidden)

1. Formal bias/fairness audit against real (non-synthetic) demographic data has not been run.
2. Number-lookup endpoint has no dedicated rate limit or scraping protection yet.
3. Dispute/human-review flow for flagged numbers is designed but not implemented.
4. The `numbers` denormalized report-count cache is not yet confirmed to update synchronously on
   every new report write against the live Supabase project — worth a regression test before pilot.
5. **Support contacts are largely unverified.** Most entries in `services/support.py` name the right
   organisation but carry an unconfirmed contact string, flagged as such in the API and the UI.
   Verifying a market's contacts blocks piloting in that market.
6. **No per-jurisdiction data-protection review** has been done for any of the seven markets.
7. **The product is English-only end to end** — interface, corpus, prompt and explanations. This is
   the largest coverage gap in the product and limits reach in every market it claims
   (`docs/accessibility.md`).

Disclosing these openly is intentional: naming real, unresolved gaps with a stated plan is more
useful to a reviewer — and to a user — than a checklist of unqualified yeses.
