# Deployment Plan

Explicit fields per AI4I Product Readiness ToR, Annex B. Narrative context for each item is in
`docs/architecture.md`; this page pulls them into the required checklist shape so reviewers don't
have to reconstruct it.

| Field | Response | Status |
|---|---|---|
| **Deployment environment** | Cloud (backend + database) with a mobile-first client. Backend: FastAPI on a small managed compute instance (1–2 vCPU, 1–2GB RAM). Client: Flutter, Android-first. Web: Next.js landing page + admin dashboard. | Implemented |
| **Hosting provider or site** | Web (landing page + admin dashboard): deployed on Vercel at **[chengetai.vercel.app](https://chengetai.vercel.app)** — this is also the demo/evidence hub referenced throughout the proposal. Backend: any standard container/VM host (e.g. Render/Railway/Fly.io-class provider — not yet contracted). Database/Auth: Supabase managed Postgres. | Web live on Vercel; backend hosting for the live site not yet contracted — see note below |
| **Operator** | Lester Rusike (Lead Innovator), ChengetAI Team, post-challenge. See proposal §6.3. | Implemented |
| **Pilot site** | Target profile: one mobile-money agent network or one telco district (proposal §5.3). *A specific named partner has not yet been secured; outreach is scheduled for Month 1–3 of the post-bootcamp plan (proposal §3.2).* | **Pending — partner identification** |
| **Users to onboard** | Pilot-phase target: a small cohort of agents/SME till operators for Sentinel (10–30 range is a reasonable pilot size) plus open consumer sign-up for the scam-detector/number-lookup features (no fixed cap — freemium, self-serve). | Planned |
| **Training and support** | In-app walkthrough on first launch (roadmap item, not yet built); WhatsApp/email support channel via the team contact (`lesterrusike@gmail.com`) during pilot; written demo script already exists (`README.md` → "Demo script") and doubles as an onboarding script for pilot partners. | Partially implemented (demo script exists; in-app walkthrough and dedicated support channel are pilot-readiness roadmap items) |
| **Monitoring** | Current: Supabase's built-in Postgres/Auth logs; automated test suite (22 pytest tests) as a pre-deploy regression gate; LLM-classifier cost tracked manually against the budget in proposal §5.4. Roadmap: structured application logging/error tracking (e.g. Sentry-class tool) and an uptime check on the backend, targeted for pilot readiness (proposal §3.2, "Pilot readiness" phase). | Partially implemented |
| **Backup and recovery** | Supabase managed Postgres provides automated daily backups and point-in-time recovery on paid tiers (to be confirmed/upgraded before real user data is stored). `sample_data/seed.sql` and the versioned schema in the repo serve as a reproducible schema-recovery path independent of any hosted backup. Export/download of a user's own data is not yet implemented as a user-facing feature. | Partially implemented — relies on Supabase platform backups; explicit export tooling is a roadmap item |
| **Connectivity plan** | Flutter app caches the top-N flagged numbers locally so number-reputation lookups work offline; message classification and Sentinel CSV analysis require connectivity in the current MVP (docs/architecture.md → "Offline behaviour"). On-device classifier execution is a Month 4–6 roadmap item (proposal §3.2) to extend offline coverage. | Partially implemented |
| **Scale pathway** | Bootcamp (harden MVP) → Pilot readiness (Month 1–3, real data intake + dispute flow + one named pilot partner) → Scale-up (Month 4–6, on-device classifier + multi-agent Sentinel dashboards) → Institutionalization (Month 7–12, POTRAZ/telco/bank partnership, iOS release, Ndebele support, formal DPA compliance audit). Full detail in proposal §3.2. | Planned |
| **Milestones** | 30-day: clean codebase, harden MVP from judge feedback, confirm pilot partner, complete security checklist. 60-day: run pilot with limited users, collect feedback, fix defects. 90-day: prepare adoption case, refine business model, finalize support plan. (proposal §12.2) | Planned |

## What judges should take from this table

**Pilot site** is explicitly marked **pending** rather than filled with a placeholder claim: it is a
target profile (one mobile-money agent network or one telco district), not a secured named partner.
We chose to disclose this gap honestly rather than assert an unconfirmed partnership — consistent
with the ToR's guidance that "judges should reward honest assumptions" (§4.3) and that false claims
about partners or deployment are a disqualification risk (§15.2).
