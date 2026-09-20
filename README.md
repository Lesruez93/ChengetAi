<p align="center">
  <img src="docs/assets/logo-full.png" alt="ChengetAI" width="280">
</p>

# ChengetAI

**"Chengeta"** — Shona for *to protect / to guard*.

Check a suspicious message. Report the number behind it without putting
yourself at risk. Reach the right help, fast.

ChengetAI is a mobile-first scam protection tool for African mobile-money
markets, built for the **OSF × Andela Hackathon — Safety, Reporting &
Protection** track (cross-track: Stability & Social Cohesion).

Currently covering **Zimbabwe, Kenya, Nigeria, Uganda, South Africa, Ghana and
Tanzania**, with one shared scam-number database across all of them.

---

## The problem

Mobile money is the default payment rail across much of Africa, and its primary
fraud surface. Losses hit the poorest hardest, exactly where financial
inclusion is deepening fastest. Four things make it worse than it needs to be:

**1. The same scam runs everywhere, but the warnings don't travel.**
"Reverse this wrong deposit" is the identical attack on EcoCash, M-PESA, MTN
MoMo, Airtel Money and OPay. A number burned in Lagos works fine in Accra the
next day, because nothing connects the two.

**2. Generic filters don't know the local scripts.** Spam filters trained on
Western corpora miss every local wallet's terminology and the scam scripts
built around it — "reverse the wrong deposit", the agent-till pretext, the
grant-release fee — because none of them look like the phishing those filters
were trained on.

**3. Reporting goes nowhere.** People are told to "report it" — but not to
whom, in what order, or how fast. By the time someone finds the right desk, the
transfer is no longer recoverable. **Detection alone is not protection**: a
verdict that doesn't say who to call leaves the user exactly where it found
them.

**4. Reporting costs safety.** The people most exposed to retaliation are the
least able to report under their own name. Any system that demands an identity
first silences precisely the reports that matter most.

---

## How ChengetAI answers the track

The Safety, Reporting & Protection track asks for tools that let people
**safely report** threats and **access clear pathways to timely support**.
That's the product's spine, in that order:

| Track requirement | How ChengetAI meets it |
|---|---|
| **Safely report** | Anonymous by default — no account, no name. Reports still count toward a number's reputation. |
| Protect the reporter's evidence | Excerpts are **redacted at intake**: phone numbers, OTPs, emails, links and ID numbers (BVN, NIN) are stripped *before* the record reaches any store, not at render time. |
| **Clear pathways to support** | Every non-safe verdict ships with `next_steps`. A dedicated **Get Help** screen gives the ordered escalation ladder for the user's country: wallet provider → regulator → police → support line. |
| **Timely** support | The ladder is ordered by how quickly each rung stops the loss. The wallet provider comes first because it is the only one that can still freeze a transfer in flight. |
| Trust and verification | Support contacts are a **curated registry, never generated**, and each carries a `verified` flag. Unverified contacts are shown to the user *as unverified* — a hallucinated police hotline is worse than none. |
| Protect the accused too | Rate limiting, duplicate collapse, and a public-flag threshold mean one hostile report can't brand a number a scammer. |

### Cross-track: Stability & Social Cohesion

The hotspot maps and trending feed act as a community early-warning signal — a
scam wave is visible before it spreads — and the classifier's core job is
telling people which messages they can trust, which is what restores confidence
in digital payments.

---

## What's in this MVP

| Module | What it does |
|---|---|
| **Check Message** | Paste or share a message; an AI classifier verdicts it scam / suspicious / safe, grounded in your market's own wallets and currency, with a plain-language explanation and highlighted risk phrases. |
| **Get Help** | The ordered "what do I do now" ladder for your country — immediate steps first, then wallet provider, regulator, police, support lines. Reachable on its own tab, not only after a verdict. |
| **Report** | Report a number anonymously or with a random on-device id. Excerpt redaction at intake; country and region pickers that use each market's own vocabulary. |
| **Number Lookup** | Search a number for a community-sourced reputation: report count, categories, risk level, and **which countries it has been reported from**. Cross-border reach escalates risk on its own. |
| **Trending Feed & Hotspot Maps** | "Trending this week" plus a within-country regional map and a cross-country rollup — computed live with weighted rules, not AI, and the API says so explicitly. |
| **Agent Fraud Sentinel (B2B)** | Upload a mobile-money agent transaction CSV; get back flagged transactions (rapid reversals, structuring, unusual hours) with human-readable reasons. |
| **Landing page & Admin dashboard** | A Next.js web app (`web/`): a public marketing page with live stats, and a password-gated admin dashboard for report moderation, flagged-number review (with cross-border markers) and Sentinel job history. |

### Screenshots

`docs/screenshots/` holds the current set — `landing-page.png`,
`admin-overview.png`, `admin-reports.png`, `admin-numbers.png`,
`admin-sentinel.png`, `admin-login.png` — captured against a running backend
with seeded data, not mockups. They are also served from the live landing page
at [chengetai.vercel.app](https://chengetai.vercel.app).

The one exception is the **mobile** capture
(`web/public/screenshots/mobile-number-lookup.png`): it predates the current
build and does not show the Get Help tab, the country switcher, or cross-border
reach on a number. Refreshing it needs a device or emulator, which the
authoring environment does not have. The landing page says so next to the image
rather than presenting it as current.

To regenerate the dashboard set, run the backend and `npm run start` in `web/`
with `ADMIN_PASSWORD` set, then drive Chromium over `/`, `/admin/login`,
`/admin`, `/admin/reports`, `/admin/numbers` and `/admin/sentinel`.

---

## How one codebase serves seven markets

Almost every "local" detail differs between markets: dial code and number
format, which wallets people use, what the first-level administrative unit is
called, what currency amounts appear in, and which desk you call after a loss.
All of it lives in **one registry** (`backend/app/services/countries.py`) plus
**one support-channel table** (`backend/app/services/support.py`).

Language is the exception: the product is **English-only** (see Known
limitations).

**Adding a market is a data change in two files.** No service logic, no client
release, no new model.

Three decisions follow from that, and they're the ones worth arguing about:

**Numbers are stored in E.164, never national format.** Local forms collide
outright: `0771234567` is a valid Zimbabwean, Ugandan *and* Tanzanian number. A
national-format key would silently merge three unrelated people's reputations —
invisible in a single-country demo, catastrophic in a regional deployment.

**One classifier, localised grounding.** The scam *mechanism* generalises even
when its vocabulary doesn't, so one model trained across all seven markets sees
far more examples of each pattern than seven per-country models would. What's
localised is the prompt's grounding and the risk-phrase vocabulary.
Correspondingly the taxonomy names mechanisms, not brands:
`mobile_money_reversal`, not `ecocash_reversal`.

**Region buckets are coarse, and there are two hotspot maps.** Region lists are
4-16 buckets per country, not exhaustive administrative lists: the map answers
"is this wave near me?", and a 47-county map answers that worse because each
bucket holds too few reports to mean anything. And a single regional map across
seven countries would split the same volume across 60+ buckets and render
everything green — so the feed returns a cross-country rollup always, and the
within-country breakdown only when a country is named.

See `docs/architecture.md` for the full system diagram and an explicit
breakdown of where AI is used and where it deliberately isn't.

---

## Repository layout

```
chengetai/
├── app/             # Flutter app (Android-first), feature-first structure
├── web/             # Next.js landing page + admin dashboard
├── backend/         # Python FastAPI backend
│   └── tests/       # pytest suite (72 tests)
├── sample_data/     # Synthetic multi-market scam corpus, transaction data, Supabase seed.sql
├── docs/            # Architecture, API reference, dataset statement, screenshots
└── .github/workflows/ci.yml  # backend pytest + web build/lint on every push
```

## Running the backend

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # defaults work out of the box: in-memory store, baseline classifier, console SMS

uvicorn app.main:app --reload
# API now at http://localhost:8000, interactive docs at http://localhost:8000/docs
```

No Supabase project or Anthropic API key is required to run the full API
surface: the backend defaults to an in-memory store (`USE_SUPABASE=false`,
seeded with reports across several markets so every cross-country view has
data) and the TF-IDF/LogisticRegression baseline classifier
(`CLASSIFIER_STRATEGY=baseline`). Set `USE_SUPABASE=true` plus Supabase
credentials to use a real Postgres project (schema in `sample_data/seed.sql`),
and `CLASSIFIER_STRATEGY=llm` plus `ANTHROPIC_API_KEY` to use the
Anthropic-backed classifier (the API gracefully falls back to the baseline if
the key is missing).

`DEFAULT_COUNTRY` (default `ZW`) decides how a local-format number with no
country is read. International-format numbers always resolve from their own
dial code and ignore it.

Run the test suite:

```bash
cd backend && .venv/bin/pytest -q   # 72 tests
```

Regenerate the synthetic sample data (already committed, regeneration is
optional):

```bash
python3 sample_data/generate_scam_corpus.py    # 647 messages across 7 markets
python3 sample_data/generate_transactions.py
```

## Running the app

```bash
cd app

flutter run
```

The app was written and reviewed without a Flutter SDK available in the
authoring environment (no `flutter pub get`/`analyze`/`run` was possible
there) — do a first-build check of `fl_chart` tooltip callback signatures and
Material icon names against your installed SDK version.

## Running the web app (landing page + admin dashboard)

```bash
cd web
npm install
cp .env.example .env.local   # set ADMIN_PASSWORD; CHENGETAI_API_BASE_URL defaults to localhost:8000
npm run dev
# Landing page at http://localhost:3000, admin dashboard at http://localhost:3000/admin
```

Requires the backend running (above) to render live data — the landing page's
stats section and every `/admin/*` page will show a "backend unreachable"
notice instead of crashing if it isn't. The admin dashboard is gated by a
single shared `ADMIN_PASSWORD` (see `docs/architecture.md` → "Admin dashboard
auth" for why, and the roadmap to real Supabase Auth).

---

## Demo script

The demo is built to walk the track's three beats in order: **detect → report
safely → reach help**.

1. **Check Message (detect, in two markets).** Paste an EcoCash "wrong deposit"
   message with the country set to Zimbabwe → `scam` verdict with highlighted
   risk phrases. Now switch the country picker to Kenya and paste the M-PESA
   equivalent (`M-PESA Alert: KSh5,000 was sent to your wallet in error...
   please reverse to 0722113344`) → same verdict, same mechanism, different
   grounding. *This is the point of the multi-market corpus: the model keys on
   the trick, not the wallet's name.*
2. **Get Help (reach help).** Tap *See who to contact* on the verdict → the
   ordered ladder for that country. Note the unverified contacts are labelled
   as unverified rather than hidden.
3. **Report (report safely).** Tap *Report the sender's number* → anonymous is
   on by default. Submit with a message excerpt containing a phone number and
   an OTP, then open the admin dashboard's report queue and see them already
   redacted.
4. **Number Lookup (cross-border).** Search `+2348031234567` (seeded) → see its
   report history, categories, and risk level.
5. **Feed.** Open Alerts → trending categories, the regional map for your
   country, and the cross-country rollup underneath it.
6. **Sentinel.** Upload `sample_data/transactions_sample.csv` → flagged
   transactions with reasons (structuring, rapid reversal, unusual hours).
7. **Admin dashboard.** Log in at `http://localhost:3000/admin/login` → the same
   data from a moderator's view, with cross-border numbers marked.

---

## Where AI is used — and where it deliberately isn't

**AI is used for:**

- **Message classification** — scam text is adversarial and constantly
  mutating; a keyword blocklist catches yesterday's scripts, not tomorrow's. The repo ships both a trained baseline and an LLM strategy
  specifically so this trade-off is demonstrable rather than asserted.
- **Sentinel anomaly detection** — agent fraud patterns are unlabeled and drift
  over time, which is exactly what unsupervised learning (IsolationForest) is
  for, paired with explicit rules as an honest baseline.

**AI is deliberately NOT used for:**

- **Number reputation** and the **trending feed / hotspot maps** — plain CRUD
  and weighted-rules aggregation. The `/feed/trending` response carries a
  `method_note` field saying so at runtime.
- **Support pathways** — a curated, human-maintained registry. Who to call
  after a fraud is too consequential to generate.
- **Evidence redaction** — deterministic regex, so what is and isn't removed
  from a stored excerpt is auditable and testable rather than a model's
  judgement call.

---

## Known limitations (MVP scope)

- Both sample datasets (`sample_data/`) are **synthetic**, disclosed in
  `docs/dataset_statement.md` — not real user messages or real transactions.
- **Most support contacts are unverified.** Entries name the correct
  organisation, but only long-standing national short codes are marked
  `verified`. The API and UI both surface the distinction. Verifying a market's
  contacts is a blocking prerequisite for piloting there.
- **The product is English-only, end to end** — interface, training corpus,
  classifier prompt and explanations. A message in another language is still
  scored, but not reliably, and the LLM strategy is instructed to say so and
  lower its confidence rather than guess. This is the largest coverage gap in
  the product: across these markets, the people most exposed to mobile-money
  fraud overlap heavily with those least likely to read English comfortably.
  `docs/accessibility.md` states what it costs and what fixing it would take.
- **No per-jurisdiction data-protection review** has been done for any of the
  seven markets; the design targets their common floor (`docs/dataset_statement.md`).
- The support pathway requires connectivity — the most important offline gap,
  since needing help and having no signal frequently coincide.
- No live SMS interception (share-intent / manual paste only), no iOS build, no
  telco integrations, no real payments, no real bank data.
- The Flutter app's auth flow is still a minimal stub pending real Supabase Auth
  wiring on the client side.
- A full human-review dispute flow is roadmap, not MVP. This matters *more* in a
  multi-country deployment, not less: a flag raised in one market now follows a
  number into every other.
- The admin dashboard uses a single shared password, and the three list
  endpoints it reads are not themselves auth-gated on the backend in this MVP.

---

## Live demo

**[chengetai.vercel.app](https://chengetai.vercel.app)** — the deployed landing
page, and the single evidence hub for screenshots, demo walkthroughs and mobile
app links.

## Docs

- `docs/architecture.md` — system diagram, the multi-market design, AI justification, safe reporting, offline behaviour, abuse resistance
- `docs/api.md` — full API reference, including country and region conventions
- `docs/dataset_statement.md` — dataset provenance, validation, privacy and redaction notes
- `docs/business_model_summary.md` — one-page business model summary
- `docs/deployment_plan.md` — hosting, operator, support, monitoring, backup/recovery, scale pathway
- `docs/risk_compliance_checklist.md` — privacy/security/bias/misuse checklist
- `docs/accessibility.md` — contrast, font size, low-bandwidth and language considerations
- `docs/usability_testing.md` — internal testing log and planned pilot usability protocol
- `docs/pitch_deck_outline.md` — the pitch deck: structure, rationale and how to rebuild it
- `docs/pitch_deck/ChengetAI-Pitch-Deck.pptx` — the built deck (13 slides), generated by `build_deck.js` so its numbers are read from this repo rather than typed by hand
- `docs/assets/` — logo source files, reused by the Flutter app, the web app and this README
