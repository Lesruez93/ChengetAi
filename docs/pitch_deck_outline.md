# Pitch Deck Outline

Content outline for the required pitch deck (AI4I Product Readiness ToR §13: "short slide deck
explaining problem, solution, traction, business model, architecture, deployment and impact").
This is the content plan — say the word and I'll build it out as an actual `.pptx` next.

## Slide 1 — Title
- **ChengetAI** — "Chengeta" (Shona: to protect, to guard, to care for)
- AI4I 2026 Innovation Challenge — POTRAZ, Track 3: Development
- Live demo: [chengetai.vercel.app](https://chengetai.vercel.app)

## Slide 2 — The problem
- Mobile money dominates everyday payments in Zimbabwe → also the primary fraud attack surface
- Named local scam patterns: EcoCash/OneMoney "wrong deposit" reversal, fake job offers, fake forex,
  "wrong transfer," fake NGO/loan, church/prophet "seed" requests
- Three structural gaps: generic filters miss Shona-English code-switching; no shared citizen
  scam-number database; agents/SMEs have zero fraud tooling
- (Proposal §1.1)

## Slide 3 — The solution
- One app, one backend, four capabilities: Check Message (AI classifier) · Number Lookup
  (crowd-sourced reputation) · Trending Feed & hotspot map · Agent Fraud Sentinel (B2B)
- Screenshots/demo: linked from [chengetai.vercel.app](https://chengetai.vercel.app), not duplicated
  here

## Slide 4 — Why AI (and where it's deliberately NOT used)
- Table from proposal §2.2 / `docs/architecture.md`: classifier (TF-IDF baseline + LLM strategy),
  Sentinel (IsolationForest + rules) — vs. number reputation and trending feed, which are
  deliberately plain CRUD/weighted-rules, not AI
- One line: "we justify AI use case-by-case, and say so explicitly at runtime (`method_note` field)"

## Slide 5 — Architecture
- System diagram from `docs/architecture.md` (Flutter app + Next.js web → FastAPI backend →
  Supabase Postgres/Auth/RLS)
- Callout: runs with zero external dependencies for judge evaluation (in-memory store), same
  codebase ships to production with `USE_SUPABASE=true`

## Slide 6 — Traction / what's already built
- FastAPI backend, 22 passing automated tests, seeded Postgres schema with RLS
- Synthetic, fully-disclosed training data (143 labeled messages, 200 transactions)
- Flutter Android-first MVP app
- Deployed landing page: [chengetai.vercel.app](https://chengetai.vercel.app)
- Version-pinned dependencies for reproducible CCE evaluation

## Slide 7 — Business model
- Freemium consumer (free) + B2B Sentinel licensing (agents/SMEs) + institutional licensing
  (telcos/banks/POTRAZ) — see `docs/business_model_summary.md`
- 3-month pilot budget: ≈$450–1,050 · 12-month: ≈$4,200–10,500 (proposal §5.4)

## Slide 8 — Deployment & pilot plan
- See `docs/deployment_plan.md` for the full Annex-B-style table
- Bootcamp → Pilot readiness (Month 1–3) → Scale-up (Month 4–6) → Institutionalization (Month 7–12)
- Honest disclosure: pilot partner and named operator are pending, not fabricated

## Slide 9 — Compliance & risk posture
- Data Protection Act alignment, consent-first collection, RLS access control, abuse-resistant
  reputation system (rate limiting, duplicate collapse, public-flag threshold)
- See `docs/risk_compliance_checklist.md`

## Slide 10 — Team
- **Lester Rusike** — Lead Innovator (product, backend/AI engineering, architecture, compliance)
- **Agnes Goora** — Frontend Developer (Flutter + web UI)
- Skills gaps and how they'll be filled: proposal §6.2

## Slide 11 — Impact & ask
- Financial-inclusion framing: protecting trust in mobile money protects the inclusion gains
  already made (proposal §1.3)
- Ask: CCE testing slot, pilot partner introduction (agent network or telco district), bootcamp
  mentorship on the dispute/human-review flow and formal DPA compliance audit
