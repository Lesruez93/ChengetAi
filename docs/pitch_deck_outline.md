# Pitch Deck Outline

Content outline for the submission pitch deck — problem, solution, traction, business model,
architecture, deployment and impact. This is the content plan, not the deck itself.

## Slide 1 — Title
- **ChengetAI** — "Chengeta" (Shona: to protect, to guard, to care for)
- OSF × Andela Hackathon — **Safety, Reporting & Protection** (cross-track: Stability & Social Cohesion)
- Live demo: [chengetai.vercel.app](https://chengetai.vercel.app)

## Slide 2 — The problem
- Mobile money is the default payment rail across much of Africa → also its primary fraud surface
- **The same script crosses borders**: "reverse this wrong deposit" runs identically on EcoCash,
  M-PESA, MTN MoMo, Airtel Money and OPay, faster than any one country's warnings travel
- Four structural gaps:
  1. generic filters miss code-switched Shona / Swahili / Pidgin / isiZulu text
  2. reporting goes nowhere — people are told to "report it", not to whom or how fast
  3. reporting costs safety — demanding an identity silences those most at risk of retaliation
  4. no shared citizen scam-number database, least of all across a border

## Slide 3 — The solution
- One app, one backend, one shared database across seven markets:
  Check Message (AI classifier, grounded per market) · **Get Help** (ordered escalation ladder
  per country) · Report (anonymous by default, redacted at intake) · Number Lookup (with
  cross-border reach) · Trending Feed & hotspot maps · Agent Fraud Sentinel (B2B)
- The through-line: **detect → report safely → reach help**. Detection alone is not protection.
- Screenshots/demo: linked from [chengetai.vercel.app](https://chengetai.vercel.app), not duplicated
  here

## Slide 4 — Why AI (and where it's deliberately NOT used)
- Table from the roadmap / `docs/architecture.md`: classifier (TF-IDF baseline + LLM strategy),
  Sentinel (IsolationForest + rules) — vs. number reputation and trending feed, which are
  deliberately plain CRUD/weighted-rules, not AI
- One line: "we justify AI use case-by-case, and say so explicitly at runtime (`method_note` field)"
- The sharpest example: **support contacts are a curated registry, never generated**. A
  hallucinated police hotline is worse than no hotline, so unverified contacts are shown to the
  user *as unverified* rather than hidden.

## Slide 5 — Architecture
- System diagram from `docs/architecture.md` (Flutter app + Next.js web → FastAPI backend →
  Supabase Postgres/Auth/RLS)
- Callout: runs with zero external dependencies for evaluation (in-memory store), same
  codebase ships to production with `USE_SUPABASE=true`

## Slide 6 — Traction / what's already built
- FastAPI backend, 72 passing automated tests, seeded Postgres schema with RLS
- Seven markets live behind one country registry — adding one is a two-file data change
- Synthetic, fully-disclosed training data (647 labeled messages across 7 markets, 200 transactions)
- Flutter Android-first MVP app
- Deployed landing page: [chengetai.vercel.app](https://chengetai.vercel.app)
- Version-pinned dependencies and CI (pytest + web build/lint) on every push

## Slide 7 — Business model
- Freemium consumer (free) + B2B Sentinel licensing (agents/SMEs) + institutional licensing
  (telcos, banks and national regulators) — see `docs/business_model_summary.md`
- 3-month pilot budget: ≈$450–1,050 · 12-month: ≈$4,200–10,500

## Slide 8 — Deployment & pilot plan
- See `docs/deployment_plan.md` for the full table
- Harden MVP → Pilot readiness (Month 1–3) → Scale-up (Month 4–6) → Institutionalization (Month 7–12)
- Sequenced by market, not launched everywhere at once: the code is market-agnostic, but
  partnerships, contact verification and language coverage are not
- Honest disclosure: pilot partner is pending, and unverified support contacts are labelled as such

## Slide 9 — Compliance & risk posture
- Evidence minimisation at intake: numbers, OTPs, IDs and links redacted before storage
- Anonymous reporting as a stated trade-off, not a checkbox — and what we give up for it
- Abuse-resistant reputation: rate limiting, duplicate collapse, public-flag threshold
- Seven overlapping data-protection regimes; we target their common floor and name the
  per-jurisdiction audit as *not done*
- See `docs/risk_compliance_checklist.md` and `docs/dataset_statement.md`

## Slide 10 — Team
- **Lester Rusike** — Lead Innovator (product, backend/AI engineering, architecture, compliance)
- **Agnes Goora** — Frontend Developer (Flutter + web UI)
- Skills gaps and how they'll be filled: the roadmap

## Slide 11 — Impact & ask
- Civic-information framing: people can only act on information they can verify. ChengetAI makes
  a suspicious message checkable, a report safe to file, and help findable — in that order
- Financial-inclusion framing: protecting trust in mobile money protects the inclusion gains
  already made
- Ask: a pilot partner introduction in one launch market (agent network or telco district),
  help verifying national support-desk contacts, and mentorship on the dispute/human-review flow
