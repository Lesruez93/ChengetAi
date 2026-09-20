# Dataset Statement

Both datasets shipped in this repo are **entirely synthetic** — no real user
messages, real phone numbers, or real transaction records were used or
collected. Every phone number appearing in them is generated, not observed.

## `sample_data/scam_corpus.jsonl` — scam/legit message corpus

- **Generation method**: `sample_data/generate_scam_corpus.py` fills randomized
  name/amount/number/location slots into hand-written templates modeled on
  **publicly reported** scam patterns across all seven markets the product
  covers. Each market supplies its own wallets, banks, employers, names, towns
  and currency, and **every scam pattern is emitted for every market**:
  wrong-deposit reversal, fake jobs, fake investment/forex/crypto, fake
  loans/grants/relief aid, SIM swap, OTP and identity phishing (BVN in Nigeria,
  ID numbers elsewhere), institutional impersonation, and faith-based "seed"
  requests — alongside legitimate wallet notices, bank alerts and everyday
  family/business texts. **All messages are in English**, matching the
  product's scope (`docs/accessibility.md`); per-market variation comes from
  wallets, banks, employers, names, towns, currency and register rather than
  from language.
- **Why multi-country**: a corpus drawn from one market teaches the model that
  the local wallet's *name* is the scam signal — the same overfit that makes
  imported spam filters useless here, reappearing one country over. Mixing
  markets forces the learned weight onto the mechanism, which is the part that
  transfers.
- **Size**: 647 messages after de-duplication (332 scam across 8 categories,
  315 legit across 3 categories), spread evenly across 7 markets (90-95 each).
  Regenerate with a different `--seed` or `--per-*-category` count for a larger
  run.
- **Labels**: `label` (`scam` | `legit`), `category` (e.g.
  `mobile_money_reversal`, `otp_phishing`, `bank_notice`), and `country` (ISO
  3166-1 alpha-2), so per-market performance can be evaluated separately.
- **Validation performed**: class balance and per-market counts printed at
  generation time; manual spot-check that each template produces plausible,
  non-duplicate phrasing in its market's register;
  `backend/tests/test_classifier.py` asserts the trained baseline separates
  known scam from legit examples **and** that it catches the same mechanism in
  a market other than the one the example was written for.
- **Known limitations**: template-generated text is less lexically diverse than
  real scam messages and cannot capture patterns absent from our template set.
  It is English-only, so the model has no coverage of the Shona, Swahili, Pidgin
  or isiZulu messages a real inbox in these markets also receives — the largest
  single gap in the dataset, recorded in `docs/accessibility.md`. It is a
  starting point for the baseline model and the LLM few-shot prompt, not a claim
  of comprehensive coverage.
- **Roadmap**: replace/augment with real, consented, anonymized reports
  collected via the in-app report flow (already redacted at intake, see below),
  plus partnerships with telcos, national cybercrime units and banks in each
  market for validated scam samples. Non-English coverage would start here too:
  a corpus per language is the prerequisite for a correct verdict in it, and no
  amount of prompt translation substitutes for one.

## `sample_data/transactions_sample.csv` — mobile-money agent transaction log

- **Generation method**: `sample_data/generate_transactions.py` produces a
  day of normal agent till activity (cash-in/out, transfers, airtime, bill
  pay at realistic amounts and trading hours) plus deliberately injected
  anomalous patterns: structuring (repeated just-under-threshold cash-outs),
  rapid reversal-then-redraw, and unusual-hour large withdrawals — for every
  market in `backend/app/services/countries.py`. Customer numbers are E.164,
  built from each country's dial code, mobile prefixes and NSN length, and
  amounts are scaled to each market's own currency against the structuring
  threshold the detector uses there. Both are imported from the backend rather
  than hardcoded, so a regenerated fixture cannot drift from the detector.
- **Size**: 7 markets × (40 normal + 10 injected anomalies) = 350
  transactions, 70 of them anomalies (labeled in the `label` column for
  evaluation only — the Sentinel analyzer does not read this column, so it is
  a fair test of detection, not a leak).
- **Validation performed**: `backend/tests/test_sentinel.py` asserts the
  analyzer flags at least one transaction from each injected anomaly
  category, that the injected structuring burst is caught in *every* market
  (not just the USD one), that no normal row trips the structuring rule, and
  that every number round-trips to the market it claims.
- **Known limitations**: single synthetic "day," three agents per market, and
  a small, hand-chosen anomaly set; real agent data would have far more
  transaction types, seasonal patterns, and subtler fraud signatures. The
  structuring thresholds are round figures of comparable real value, not each
  jurisdiction's statutory reporting limit — a deployment should substitute
  its network's own limits.
- **Roadmap**: pilot with a real agent network under a data-sharing
  agreement, with PII (MSISDNs, agent identities) pseudonymized before it
  reaches the Sentinel service.

## Privacy notes

- **Excerpts are redacted at intake, not at render time**
  (`backend/app/services/redaction.py`). Before a report reaches any store,
  phone numbers, email addresses, URLs, OTPs and identity numbers (BVN, NIN, ID)
  are replaced with markers. A reporting tool accumulates other people's
  messages, and those carry identifiers belonging to people who never consented
  to anything; redacting at render time would protect the screen while leaving
  the database a liability. What survives is the scam's wording, which is what
  the classifier learns from and what a moderator reads.
- Message content is **not stored** beyond that redacted excerpt, capped at 500
  characters; full message bodies are never persisted.
- **Anonymous reports carry no reporter identifier at all** — not a blank one.
  The non-anonymous mode uses a random on-device id, not a name, phone number or
  account.
- Reported phone numbers are quasi-personal data. The reputation system
  (`docs/architecture.md` → "Abuse-resistance") requires multiple corroborating
  reports before a number is *publicly* flagged, and a dispute/human-review path
  is on the roadmap.
- **Multi-country data-protection posture**: the markets covered have
  overlapping but non-identical regimes — Zimbabwe's Data Protection Act,
  Kenya's Data Protection Act 2019, Nigeria's NDPA 2023, Uganda's Data
  Protection and Privacy Act 2019, South Africa's POPIA, Ghana's Data Protection
  Act 2012 and Tanzania's Personal Data Protection Act 2022. The design targets
  the common floor of all of them: minimise at collection, corroborate before
  publishing, and provide a contest path. A per-jurisdiction compliance review,
  including data-residency requirements and whether a local representative must
  be registered, is required before any pilot with real user data and is **not**
  claimed as done here.
- Signup requires an explicit consent checkbox (`profiles.consent_given_at` in
  `sample_data/seed.sql`) before any report submitted by that user is attributed
  to them.
