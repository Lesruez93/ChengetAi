# Dataset Statement

Rubric C3. Both datasets shipped in this repo are **entirely synthetic** —
no real user messages, real phone numbers, or real transaction records were
used or collected.

## `sample_data/scam_corpus.jsonl` — scam/legit message corpus

- **Generation method**: `sample_data/generate_scam_corpus.py` fills
  randomized name/amount/number/location slots into hand-written templates
  modeled on **publicly reported** Zimbabwean scam patterns (EcoCash/OneMoney
  "wrong deposit" reversal scams, fake remote job offers, fake forex deals,
  "wrong transfer" scams, fake NGO/loan offers, church/prophet "sow a seed"
  requests) plus legitimate bank/mobile-money notices and everyday
  family/business texts. Text mixes English and Shona the way real local
  messages do, since that code-switching is exactly what generic filters miss.
- **Size**: 143 messages after de-duplication (90 scam across 6 categories,
  53 legit across 2 categories); regenerate with a different `--seed` or
  `--per-*-category` count for a larger run.
- **Labels**: `label` (`scam` | `legit`) and `category` (e.g.
  `ecocash_reversal`, `fake_job`, `bank_notice`).
- **Validation performed**: class balance checked at generation time (script
  prints scam/legit counts); manual spot-check that each template produces
  plausible, non-duplicate Shona/English phrasing; `backend/tests/test_classifier.py`
  asserts the trained baseline correctly separates known scam vs. legit
  examples pulled from these templates.
- **Known limitations**: template-generated text is less lexically diverse
  than real scam messages and cannot capture patterns scammers haven't used
  yet in our template set; it is a starting point for the baseline model and
  the LLM few-shot prompt, not a claim of comprehensive coverage.
- **Roadmap**: replace/augment with real, consented, anonymized reports
  collected via the in-app "Report this message" flow, plus partnerships
  with telcos, the ZRP cyber unit, and banks for validated scam samples.

## `sample_data/transactions_sample.csv` — mobile-money agent transaction log

- **Generation method**: `sample_data/generate_transactions.py` produces a
  day of normal agent till activity (cash-in/out, transfers, airtime, bill
  pay at realistic amounts and trading hours) plus deliberately injected
  anomalous patterns: structuring (repeated just-under-$500 cash-outs),
  rapid reversal-then-redraw, and unusual-hour large withdrawals.
- **Size**: 200 transactions, 20 of them injected anomalies (labeled in the
  `label` column for evaluation only — the Sentinel analyzer does not read
  this column, so it is a fair test of detection, not a leak).
- **Validation performed**: `backend/tests/test_sentinel.py` asserts the
  analyzer flags at least one transaction from each injected anomaly
  category.
- **Known limitations**: single synthetic "day," three agents, and a small,
  hand-chosen anomaly set; real agent data would have far more transaction
  types, seasonal patterns, and subtler fraud signatures.
- **Roadmap**: pilot with a real agent network under a data-sharing
  agreement, with PII (MSISDNs, agent identities) pseudonymized before it
  reaches the Sentinel service.

## Privacy notes

- Reported phone numbers are quasi-personal data. The reputation system
  (`docs/architecture.md` → "Abuse-resistance") requires multiple
  corroborating reports before a number is *publicly* flagged, and a
  dispute/human-review path is on the roadmap — both intended to satisfy
  Zimbabwe's **Data Protection Act** obligations around fair processing and
  the right to contest automated-adjacent decisions.
- Message content is **not stored** beyond a short `message_excerpt` used
  for context on a report; full message bodies are never persisted.
- Signup requires an explicit consent checkbox (`profiles.consent_given_at`
  in `sample_data/seed.sql`) before any report submitted by that user is
  attributed to them.
