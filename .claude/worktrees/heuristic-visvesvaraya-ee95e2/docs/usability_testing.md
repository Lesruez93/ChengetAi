# Usability Testing & Feedback Log

Usability testing log and planned pilot protocol. At MVP/prototype stage this is evidence of
execution plus honesty about what remains incomplete — not a fully validated external user-testing
programme. This log reflects that stage honestly.

## What has been done so far

| Activity | Method | Outcome |
|---|---|---|
| Automated functional testing | 72 `pytest` tests covering classifier accuracy across markets, phone-number normalisation and country resolution, excerpt redaction, rate limiting, duplicate collapse, anonymous reporting, public-flag and cross-border thresholds, trending-feed ranking, both hotspot scopes, support-pathway coverage, and Sentinel anomaly detection (`backend/tests/`) | All passing — verifies backend logic behaves as designed, not a substitute for human usability feedback but the first line of "does this actually work" evidence |
| Internal team walkthrough | Manual run-through of the demo script (`README.md` → "Demo script": Check Message → Number Lookup → Feed → Sentinel → Landing page → Admin dashboard) against a running backend with seeded/uploaded data | Confirmed the core user journey is completable end-to-end without a developer explaining each step |
| Screenshot review | Web app (landing page + admin dashboard) screenshots captured against live seeded/uploaded data, not mockups (`docs/screenshots/`) | Used to sanity-check visual consistency and that displayed data matches what the backend actually returns |

## What has not been done yet (disclosed gap)

No external users outside the immediate team have used the product yet. This is the honest state at
prototype/MVP stage — there is no fabricated feedback log entry here standing in for real user
testing that hasn't happened.

## Planned usability testing protocol (pilot readiness phase, Month 1–3)

1. Recruit 5–8 informal testers (a mix of consumer users and, separately, 2–3 mobile-money
   agents/SME till operators) outside the immediate team.
2. Walk each tester through the same demo script used internally (README "Demo script"), observing
   without prompting where they get stuck.
3. Capture, per tester: whether they completed each step unaided, time-to-first-verdict on Check
   Message, and any point where the UI required developer explanation to proceed.
4. Log results in this file (a `## Pilot testing round 1` section will be added here with real
   dates, tester count, and findings once run) — no results are pre-filled or assumed.
5. Feed findings into the 30/60/90-day milestone plan, specifically the
   "improve prototype from judge feedback" and "improve user onboarding" milestones.

This structure mirrors the ToR's own guidance: "record changes made after feedback" — the
placeholder above is intentionally empty until that feedback round actually happens.
