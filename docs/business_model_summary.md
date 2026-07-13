# Business Model Summary

One-page summary per AI4I Product Readiness ToR, Annex A. Full detail and reasoning is in
`proposal/ChengetAI_AI4I_Proposal_Development.md` §5; this page extracts it as a standalone
deliverable.

| Field | Response |
|---|---|
| **Problem** | Mobile-money scams (EcoCash/OneMoney reversal scams, fake jobs, fake forex, fake NGO/loan, church "seed" requests) are widely reported in Zimbabwe. Generic spam filters miss Shona-English code-switched scam text, there is no shared citizen-accessible scam-number database, and mobile-money agents/SMEs have no fraud tooling. |
| **Primary user** | Individual mobile-money users (consumer app); mobile-money agents and SME till operators (Agent Fraud Sentinel). |
| **Beneficiary** | The same primary users, plus the wider financial-inclusion goal — reduced scam losses protect trust in digital finance for previously-excluded groups (rural households, first-time smartphone owners, older adults). |
| **Customer or payer** | Consumer features are free (freemium). Paying customers are mobile-money agents/agent networks/SMEs (Sentinel licensing) and, longer-term, telcos/banks/POTRAZ (aggregated scam-signal licensing). |
| **Value proposition** | Real-time scam-message verdicts with plain-language explanations; crowd-sourced number reputation lookup before engaging an unknown number; anomaly-flagged transaction review for agents who otherwise have no fraud tooling at all. |
| **Revenue or funding model** | Freemium (consumer) + B2B per-agent/per-till Sentinel licensing + institutional licensing of aggregated, anonymized scam-signal data to telcos/banks/POTRAZ. See proposal §5.1 for full detail on each stream. |
| **Cost drivers** | LLM API calls (classifier), hosting (FastAPI + Supabase Postgres), SMS delivery (Twilio, report confirmations). Ranked by scale-sensitivity in proposal §5.2. |
| **Partnerships** | A mobile-money agent network or telco district for the initial pilot (proposal §5.3); longer-term, POTRAZ as a plausible institutional co-funder of a shared national scam-number signal (proposal §1.3, §5.1). |
| **Pilot market** | One mobile-money agent network or one telco district (bounded, measurable scope) — see `docs/deployment_plan.md` for the explicit pilot-site field and current status. |
| **Adoption risks** | Low reporter engagement on the number-reputation feature (cold-start problem for crowd-sourced data); agent networks' willingness to share transaction data under a data-sharing agreement; LLM API cost growing faster than revenue (mitigated by the zero-marginal-cost baseline classifier fallback). |
| **Success metrics** | Classifier precision/recall against real reported messages (vs. current synthetic-corpus baseline); Sentinel true-positive rate against agent-confirmed fraud cases; reporter engagement/retention on number-reputation. Measured at 30/60/90 days per proposal §3.2 and §12.2. |

**3-month and 12-month budget ranges**: see proposal §5.4 (reproduced in `docs/deployment_plan.md` is out of scope — budget stays in the proposal to avoid duplication/drift between documents).
