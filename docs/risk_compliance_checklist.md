# Risk & Compliance Checklist

Standalone checklist artifact per AI4I Product Readiness ToR §13 (required deliverable) and §10.1
(minimum safeguards). Narrative reasoning for each item is in `docs/dataset_statement.md`; this
page is the checklist form judges expect as a separate artifact.

## Risk level (self-assessed)

**Medium risk** — per ToR §10.2: the product handles user accounts, real operational data
(once piloted), citizen reports, and quasi-personal data (phone numbers), but not health, finance,
identity, or biometric data. Expected controls at this level: access control, consent where
relevant, logs, testing, and clear disclaimers — all addressed below.

## Minimum safeguards

| Safeguard | Status | Evidence |
|---|---|---|
| **Data minimisation** | Yes | Full message bodies are never persisted — only a short `message_excerpt` for report context (`docs/dataset_statement.md` → "Privacy notes"). Live call/SMS screening matches on the handset against a downloaded blocklist, so incoming numbers and message bodies never reach the backend at all; the on-device detection log records the sender and the reason, never the message text (`docs/architecture.md` → "Live call & SMS screening"). |
| **Consent** | Yes | Signup requires an explicit consent checkbox before any report is attributed to a user, timestamped in `profiles.consent_given_at` (`sample_data/seed.sql`). |
| **Access control** | Yes | Row Level Security on every Supabase table: self-scoped access for `profiles`/`sentinel_jobs`, reporter-scoped inserts for `reports`, service-role-only writes to `numbers` (`docs/architecture.md` → database schema table, proposal §2.4). |
| **Authentication** | Yes | Supabase Auth backs all user identity; the backend never stores or manages raw credentials (proposal §4.5). |
| **Secrets management** | Yes | No passwords, API keys, or tokens committed to the repo; `.env.example` files ship without secrets in `backend/` and `web/`. |
| **Encryption** | Yes | Supabase provides encryption in transit (TLS) and at rest by default on its managed Postgres; verified against the live "chengetAI" project (region eu-west-2), which is now connected and serving the backend. |
| **Auditability** | Partial | `sentinel_jobs` acts as an audit log for Sentinel analyses; general action logging (who changed what, when) beyond this is a roadmap item (see `docs/deployment_plan.md` → Monitoring). |
| **Human oversight** | Yes | Classifier returns a confidence score and explanation rather than a bare verdict; number-flagging requires multiple corroborating reports before going public, and a dispute/human-review path is roadmap (proposal §2.6, §4.2, §4.3). |
| **Misuse risk** | Yes | Addressed explicitly below (§ "Misuse risks and mitigations"). |
| **Permission minimisation (mobile)** | Yes | Call screening uses `ROLE_CALL_SCREENING`, which requires no permission; `READ_CALL_LOG` and `READ_PHONE_STATE` are never requested. SMS screening requests `RECEIVE_SMS` only — `READ_SMS` is not requested, so the existing inbox is never read, and the app is not the default SMS handler. |
| **Bias and fairness** | Partial | Classifier is trained on a synthetic corpus covering six named local scam categories in Shona-English code-switched text (`docs/dataset_statement.md`); no formal bias/fairness audit against demographic subgroups has been run yet, since all training data is synthetic rather than drawn from a real, demographically-labeled population. |

## Misuse risks and mitigations

| Misuse scenario | Mitigation |
|---|---|
| A malicious user floods reports against an innocent number to get it publicly flagged (defamation risk). | Rate limiting (`REPORT_RATE_LIMIT_PER_HOUR`), duplicate collapse within 24h, and a public-flag threshold requiring multiple distinct corroborating reports (`NUMBER_PUBLIC_FLAG_THRESHOLD`, default 3). Proposal §2.6, §4.3. |
| A user over-trusts an AI "safe" verdict on a genuinely dangerous message (false negative). | Confidence score is always shown, not a bare label; risk phrases are surfaced with explanations so the user can evaluate reasoning rather than trust a black-box verdict (proposal §4.2). |
| Sentinel flags a legitimate agent transaction as fraud, harming a real agent's standing. | Explicit rule layer alongside the unsupervised model gives a human-readable reason for every flag, not just an opaque anomaly score, so a flagged agent's manager can review the specific reason (proposal §2.2, §4.2). |
| Screening every incoming call server-side would give the backend a live record of who contacts each user and when — a contact-graph surveillance dataset the project has no need for. | Avoided by design: `GET /numbers/flagged/sync` pulls the flagged set down in bulk and matching happens on the device, so an incoming number is never sent to the API. The blocklist download carries no information about the user. |
| A number is auto-rejected during a live call on the strength of crowd-sourced reports, with no human reviewing the decision. | Only publicly-flagged numbers (past `NUMBER_PUBLIC_FLAG_THRESHOLD`) are synced to handsets at all. Warning is the default; auto-rejection is opt-in, applies only to the highest-risk band, and blocked calls are still written to the call log so the user can see and second-guess the decision. |
| A user reads a clean-looking link verdict as proof the site is safe. | The link checker never fetches a URL (also an SSRF-avoidance decision), so a clean address returns `unknown`, kept distinct from `low`, and is rendered as "NOT CHECKED" with an explicit "this does not make it safe" note rather than a green tick. |
| Scraping or bulk-querying the number-lookup endpoint to build a shadow database of phone numbers. | Roadmap item — not yet rate-limited or access-controlled separately from the report-submission endpoint. **Flagged here as an open gap**, to be addressed before wider pilot rollout. |

## Data Protection Act (Zimbabwe) compliance

| Control | Status | Evidence |
|---|---|---|
| Lawful basis for collection | Yes | Consent-first signup; synthetic-only training data today (no real personal data collected yet). |
| Fair processing / contestability | Partial | Public-flag threshold protects against single-report harm; formal dispute/human-review workflow is roadmap, not yet built. |
| Data minimisation | Yes | See above. |
| Anonymisation plan for future real data | Yes (planned) | Any transition to real reported messages or agent transaction data will pseudonymize MSISDNs/agent identities before reaching the Sentinel service, under a data-sharing agreement with the pilot partner (proposal §4.1). |

## Known open gaps (disclosed, not hidden)

1. Formal bias/fairness audit against real (non-synthetic) demographic data has not been run.
2. Number-lookup endpoint has no dedicated rate limit or scraping protection yet. `GET /numbers/flagged/sync` widens this: it returns the whole publicly-flagged set in one unauthenticated call, which is what makes on-device matching possible but also makes the list trivially copyable. Auth/rate-limiting on this endpoint is required before wider rollout.
3. Automatic SMS screening uses a short on-device keyword list rather than the trained classifier, to avoid uploading message bodies. It will miss scams worded in new ways; this is disclosed in-app on the Protection screen rather than presented as full coverage.
3. Dispute/human-review flow for flagged numbers is designed (proposal §2.6) but not implemented.
4. The `numbers` denormalized report-count cache is not yet confirmed to update synchronously on
   every new report write against the live Supabase project — worth a regression test before pilot.

Disclosing these openly is intentional — the ToR's weak-submission flags (§15.1) penalize teams who
ignore privacy/security/consent risks, not teams who name real, unresolved gaps with a stated plan.
