# Pitch Deck

The deck is built, not just outlined: **`docs/pitch_deck/ChengetAI-Pitch-Deck.pptx`**
(13 slides, 16:9).

## Rebuilding it

```bash
node docs/pitch_deck/build_deck.js
```

The deck is **generated from a script rather than hand-authored**, for one
reason: the numbers on it are read out of the repository at build time — market
count from the country registry, test count from `pytest --collect-only`, corpus
size from the JSONL, category count from the taxonomy. A deck rebuilt after a
code change cannot quietly keep a stale claim, which is the usual way a pitch
deck starts lying about its own product.

It needs `pptxgenjs` and the backend virtualenv (for the test count). The script
fails loudly rather than printing a guess if it cannot count tests.

## Structure and the argument it makes

The spine is the track's own: **detect → report safely → reach help**. Slides
2–4 set up why the second and third beats are the product, and everything after
is evidence.

| # | Slide | What it has to land |
|---|---|---|
| 1 | Title | The one line: detection that ends in help, not just a verdict |
| 2 | The problem | Four gaps — and gaps 3 and 4 (reporting goes nowhere, reporting costs safety) are the ones the track is actually about |
| 3 | The insight | One scam script runs on every wallet in every market, so the defence has to cross borders too |
| 4 | The solution | The three beats. If only one slide survives, this is it |
| 5 | What's built | Six modules, one backend, one shared database |
| 6 | It runs | Screenshot of the live moderation dashboard — proof it is not slideware |
| 7 | Architecture | Runs with zero external services; adding a market is a two-file data change |
| 8 | Judgement | Where AI earns its place, and where it is deliberately refused |
| 9 | Coverage | Seven markets, and the three design decisions that made that possible |
| 10 | Traction | What exists, stated in numbers read from the repo |
| 11 | Sustainability | Who pays, and the market-by-market path to pilot |
| 12 | Honesty | What we are *not* claiming |
| 13 | The ask | Pilot partner, contact verification, mentorship |

Two slides carry disproportionate weight in questions:

- **Slide 8** — the support registry is the clearest case in the product where
  the responsible engineering choice was to *not* use the model. A hallucinated
  police hotline is worse than no hotline.
- **Slide 12** — a reviewer finds the gaps anyway. Naming them first is more
  credible than a checklist of unqualified yeses, and it mirrors what the
  product does with users when a support contact is unverified.

Every slide carries speaker notes; they are in the `.pptx`, not duplicated here.

## Design

Palette and typography come from the product itself — the deep teal in
`app/lib/core/theme.dart` and `web/src/app/globals.css` — so the deck, the app
and the landing page read as one thing. Dark title and closing slides, light
content between them.

## Before submitting — check these yourself

- **Budget figures are not in the deck.** An earlier outline carried 3-month and
  12-month ranges from a proposal that is not in this repository, so they were
  left out rather than reproduced unverified. Add them to slide 11 if you want
  them.
- **Slide 13 credits.** It names Lester Rusike as the builder with Agnes Goora
  credited for frontend contribution. The hackathon asks for individual
  submissions, so confirm this framing matches how you are entering.
- **The mobile screenshot** is not in the deck; slide 6 uses the dashboard,
  which is current. If you refresh the Flutter captures, consider adding one.

## QA

`docs/pitch_deck/build_deck.js` produces a file that passes the pptx schema and
relationship validator. LibreOffice is unavailable in the authoring environment,
so layout was verified geometrically instead — every shape checked against the
slide canvas and the 0.5" margin, text measured against its box with real font
metrics, and text boxes checked pairwise for overlap. That pass caught a chip
row running off the right edge of slide 3 and three text collisions.
