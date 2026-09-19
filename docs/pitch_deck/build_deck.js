/**
 * Builds the ChengetAI pitch deck (OSF x Andela hackathon submission).
 *
 *   node docs/pitch_deck/build_deck.js
 *
 * The deck is generated rather than hand-authored so its numbers stay honest:
 * test counts, corpus size and market coverage are read from the repo at build
 * time, so a deck rebuilt after a code change cannot quietly keep stale claims.
 *
 * Requires pptxgenjs. If it is not resolvable from the repo, run the script
 * from a directory where it is installed, or `npm install pptxgenjs` first.
 */

const fs = require("fs");
const path = require("path");
const { execSync } = require("child_process");
const pptxgen = require("pptxgenjs");

const REPO = path.resolve(__dirname, "..", "..");
const OUT = path.join(__dirname, "ChengetAI-Pitch-Deck.pptx");

// ---------------------------------------------------------------------------
// Palette — the product's own, from app/lib/core/theme.dart and
// web/src/app/globals.css. Deep teal dominates; the semantic colours appear
// only where they mean what they mean in the product (red = scam/high risk).
// ---------------------------------------------------------------------------
const C = {
  primary: "0F6B5C",   // deep teal — dominant
  secondary: "14A085", // lighter teal accent
  tint: "F4FAF8",      // surface tint
  ink: "0F172A",       // foreground
  neutral: "64748B",
  danger: "C62828",
  warning: "B8860B",
  safe: "2E7D32",
  white: "FFFFFF",
  deep: "0A3A32",      // darker teal for title/closing slides
};

const FONT_H = "Arial";
const FONT_B = "Calibri";

// ---------------------------------------------------------------------------
// Facts pulled from the repo, so the deck cannot drift from the code.
// ---------------------------------------------------------------------------
function readFacts() {
  const corpusPath = path.join(REPO, "sample_data", "scam_corpus.jsonl");
  const corpus = fs
    .readFileSync(corpusPath, "utf8")
    .split("\n")
    .filter(Boolean)
    .map(JSON.parse);

  const countriesSrc = fs.readFileSync(
    path.join(REPO, "backend", "app", "services", "countries.py"),
    "utf8"
  );
  const markets = [...countriesSrc.matchAll(/^        name="([^"]+)",$/gm)].map((m) => m[1]);

  const taxonomySrc = fs.readFileSync(
    path.join(REPO, "backend", "app", "services", "taxonomy.py"),
    "utf8"
  );
  const categories = [...taxonomySrc.matchAll(/^        key="([^"]+)",$/gm)].map((m) => m[1]);

  let tests = 0;
  try {
    const out = execSync(
      "cd backend && .venv/bin/pytest --collect-only -q 2>/dev/null | tail -2",
      { cwd: REPO, encoding: "utf8" }
    );
    const m = out.match(/(\d+)\s+tests?\s+collected/);
    if (m) tests = Number(m[1]);
  } catch {
    // Leave at 0 and fail loudly below rather than printing a guess.
  }
  if (!tests) throw new Error("Could not count tests — run the backend venv setup first.");

  return {
    tests,
    corpusTotal: corpus.length,
    corpusScam: corpus.filter((r) => r.label === "scam").length,
    markets,
    categories: categories.filter((k) => k !== "other").length,
  };
}

const F = readFacts();

const pres = new pptxgen();
pres.layout = "LAYOUT_WIDE"; // 13.3 x 7.5
pres.author = "ChengetAI";
pres.title = "ChengetAI — Safety, Reporting & Protection";

const W = 13.3;
const M = 0.62; // side margin
const CW = W - M * 2;

// ---------------------------------------------------------------------------
// Shared builders. Each returns a *fresh* options object — pptxgenjs mutates
// option objects in place, so sharing one across two add* calls corrupts the
// second.
// ---------------------------------------------------------------------------
const shadow = () => ({ type: "outer", color: "0F172A", blur: 10, offset: 2, angle: 90, opacity: 0.1 });

function darkSlide() {
  const s = pres.addSlide();
  s.background = { color: C.deep };
  return s;
}

function lightSlide(kicker, title, opts = {}) {
  const s = pres.addSlide();
  s.background = { color: opts.tint ? C.tint : C.white };
  s.addText(kicker.toUpperCase(), {
    x: M, y: 0.5, w: CW, h: 0.28,
    fontFace: FONT_H, fontSize: 12, bold: true, color: C.secondary,
    charSpacing: 1.4, isTextBox: true, margin: 0,
  });
  s.addText(title, {
    x: M, y: 0.82, w: opts.titleW || CW, h: opts.titleH || 1.0,
    fontFace: FONT_H, fontSize: opts.titleSize || 32, bold: true, color: C.ink,
    isTextBox: true, margin: 0,
  });
  return s;
}

/** The deck's motif: a number or glyph in a filled teal circle. */
function badge(slide, x, y, label, opts = {}) {
  const d = opts.d || 0.46;
  slide.addShape(pres.ShapeType.ellipse, {
    x, y, w: d, h: d,
    fill: { color: opts.fill || C.primary },
  });
  slide.addText(label, {
    x, y, w: d, h: d,
    fontFace: FONT_H, fontSize: opts.size || 14, bold: true,
    color: opts.color || C.white, align: "center", valign: "middle",
    isTextBox: true, margin: 0,
  });
}

/**
 * Row of pill-shaped chips that wraps at the content edge.
 * Widths are estimated from label length; the wrap is what guarantees a long
 * label can never push a chip off the canvas. Returns the y it ended on.
 */
function chipRow(slide, labels, x0, y0, opts = {}) {
  const h = opts.h || 0.56;
  let x = x0;
  let y = y0;
  labels.forEach((label) => {
    const w = 0.118 * label.length + 0.62;
    if (x + w > x0 + CW) { x = x0; y += h + 0.14; }
    slide.addShape(pres.ShapeType.roundRect, {
      x, y, w, h, rectRadius: h / 2,
      fill: { color: C.white }, line: { color: "D6E7E2", width: 1 },
    });
    slide.addText(label, {
      x, y, w, h,
      fontFace: FONT_H, fontSize: opts.size || 13, bold: true, color: C.primary,
      align: "center", valign: "middle", isTextBox: true, margin: 0,
    });
    x += w + 0.16;
  });
  return y + h;
}

/** Tinted card with a soft shadow — used for every grid cell in the deck. */
function card(slide, x, y, w, h, opts = {}) {
  slide.addShape(pres.ShapeType.roundRect, {
    x, y, w, h,
    rectRadius: 0.08,
    fill: { color: opts.fill || C.tint },
    shadow: shadow(),
  });
}

// ===========================================================================
// 1 — Title
// ===========================================================================
{
  const s = darkSlide();
  s.addImage({ path: path.join(REPO, "docs/assets/logo-mark.png"), x: M, y: 1.28, w: 1.15, h: 1.15 });

  s.addText("ChengetAI", {
    x: M, y: 2.62, w: 9.6, h: 0.92,
    fontFace: FONT_H, fontSize: 54, bold: true, color: C.white, isTextBox: true, margin: 0,
  });
  s.addText("Check it. Report it safely. Know who to call next.", {
    x: M, y: 3.56, w: 9.8, h: 0.5,
    fontFace: FONT_H, fontSize: 21, color: C.secondary, isTextBox: true, margin: 0,
  });
  s.addText(
    "Scam protection for African mobile money — detection that ends in help, " +
      "not just a verdict.",
    {
      x: M, y: 4.12, w: 9.2, h: 0.72,
      fontFace: FONT_B, fontSize: 15, color: "C9DED8", isTextBox: true, margin: 0,
    }
  );

  s.addText('"Chengeta" — Shona: to protect, to guard', {
    x: M, y: 5.22, w: 6.4, h: 0.32,
    fontFace: FONT_B, fontSize: 12.5, italic: true, color: "8FB5AC", isTextBox: true, margin: 0,
  });

  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 5.78, w: 6.75, h: 0.56, rectRadius: 0.28,
    fill: { color: "13564A" },
  });
  s.addText("OSF × Andela Hackathon  ·  Safety, Reporting & Protection", {
    x: M, y: 5.78, w: 6.75, h: 0.56,
    fontFace: FONT_H, fontSize: 12.5, bold: true, color: C.white,
    align: "center", valign: "middle", isTextBox: true, margin: 0,
  });

  s.addText("chengetai.vercel.app", {
    x: 7.7, y: 5.78, w: 5.0, h: 0.56,
    fontFace: FONT_B, fontSize: 13, color: C.secondary,
    valign: "middle", isTextBox: true, margin: 0,
  });

  s.addNotes(
    "Chengeta is Shona for 'to protect'. The one line to land: detection alone is not " +
      "protection. A verdict that doesn't tell you who to call leaves the user exactly " +
      "where it found them — that gap is what this product closes."
  );
}

// ===========================================================================
// 2 — The problem
// ===========================================================================
{
  const s = lightSlide("The problem", "Mobile money is Africa's payment rail —\nand its primary fraud surface.", {
    titleSize: 29, titleH: 1.18, titleW: 8.8,
  });

  s.addText(
    "Losses land hardest on the poorest, exactly where financial inclusion is " +
      "deepening fastest. Four gaps make it worse than it needs to be.",
    {
      x: M, y: 2.04, w: 8.6, h: 0.5,
      fontFace: FONT_B, fontSize: 14, color: C.neutral, isTextBox: true, margin: 0,
    }
  );

  const gaps = [
    ["1", "The scam crosses borders. The warning doesn't.", "A number burned in Lagos works fine in Accra the next day — nothing connects the two."],
    ["2", "Generic filters don't know the local scripts.", "Western-trained spam filters miss every local wallet's terminology and the scams built on it."],
    ["3", "Reporting goes nowhere.", "People are told to report it — not to whom, in what order, or how fast. The money is gone by then."],
    ["4", "Reporting costs safety.", "Demanding an identity silences exactly the people most exposed to retaliation."],
  ];

  let y = 2.66;
  gaps.forEach(([n, title, body]) => {
    card(s, M, y, CW, 0.92);
    badge(s, M + 0.3, y + 0.23, n);
    s.addText(title, {
      x: M + 0.94, y: y + 0.16, w: CW - 1.3, h: 0.3,
      fontFace: FONT_H, fontSize: 15, bold: true, color: C.ink, isTextBox: true, margin: 0,
    });
    s.addText(body, {
      x: M + 0.94, y: y + 0.48, w: CW - 1.3, h: 0.32,
      fontFace: FONT_B, fontSize: 13, color: C.neutral, isTextBox: true, margin: 0,
    });
    y += 1.06;
  });

  s.addNotes(
    "Gaps 3 and 4 are the ones most scam tools ignore entirely. They are also exactly " +
      "what the Safety, Reporting & Protection track asks for: safe reporting, and clear " +
      "pathways to timely support."
  );
}

// ===========================================================================
// 3 — The insight
// ===========================================================================
{
  const s = lightSlide("The insight", "One script. Every wallet. Seven borders.", { tint: true });

  card(s, M, 1.82, CW, 1.72, { fill: C.white });
  s.addText("“", {
    x: M + 0.2, y: 1.82, w: 0.58, h: 1.0,
    fontFace: FONT_H, fontSize: 54, bold: true, color: C.secondary,
    valign: "top", isTextBox: true, margin: 0,
  });
  s.addText(
    "Confirmed. You have received $80. This was sent to you in error — please reverse " +
      "the money to 077…  and we will not report it.",
    {
      x: M + 0.85, y: 2.06, w: CW - 1.6, h: 0.86,
      fontFace: FONT_B, fontSize: 17, italic: true, color: C.ink, isTextBox: true, margin: 0,
    }
  );
  s.addText("The wrong-deposit scam — the single most reported pattern across every market we cover.", {
    x: M + 0.85, y: 2.98, w: CW - 1.6, h: 0.3,
    fontFace: FONT_B, fontSize: 12, color: C.neutral, isTextBox: true, margin: 0,
  });

  s.addText("Runs identically on:", {
    x: M, y: 3.78, w: 4, h: 0.3,
    fontFace: FONT_H, fontSize: 13, bold: true, color: C.ink, isTextBox: true, margin: 0,
  });

  chipRow(
    s,
    ["EcoCash", "M-PESA", "MTN MoMo", "Airtel Money", "OPay", "Capitec Pay"],
    M, 4.16, { h: 0.52 }
  );

  s.addShape(pres.ShapeType.roundRect, {
    x: M, y: 5.06, w: CW, h: 1.5, rectRadius: 0.1,
    fill: { color: C.primary },
  });
  s.addText("So the defence has to cross borders too.", {
    x: M + 0.42, y: 5.24, w: CW - 0.9, h: 0.38,
    fontFace: FONT_H, fontSize: 19, bold: true, color: C.white, isTextBox: true, margin: 0,
  });
  s.addText(
    "One shared scam-number database across all seven markets. A number reported in " +
      "Lagos is visible to someone in Accra — and a number reported from two countries goes " +
      "to high risk regardless of volume, because cross-border reach means an organised " +
      "operation rather than a local dispute.",
    {
      x: M + 0.42, y: 5.68, w: CW - 0.9, h: 0.76,
      fontFace: FONT_B, fontSize: 13, color: "C9DED8", isTextBox: true, margin: 0,
    }
  );

  s.addNotes(
    "This is the slide that justifies the whole multi-country design. The scam generalises, " +
      "so the model and the database have to generalise with it."
  );
}

// ===========================================================================
// 4 — The solution: three beats
// ===========================================================================
{
  const s = lightSlide("The solution", "Detect → report safely → reach help.");

  s.addText(
    "Most scam tools stop at the first beat. The second and third are what the " +
      "Safety, Reporting & Protection track actually asks for.",
    {
      x: M, y: 1.9, w: 9.6, h: 0.44,
      fontFace: FONT_B, fontSize: 14, color: C.neutral, isTextBox: true, margin: 0,
    }
  );

  const beats = [
    ["01", "Check it", "Paste a suspicious message. Verdict, the exact phrases that triggered it, and a plain-language reason — grounded in your own market's wallets and currency."],
    ["02", "Report it safely", "Anonymous by default: no account, no name, and the report still counts. Phone numbers, one-time codes and ID numbers are stripped before it is ever stored."],
    ["03", "Reach help", "What to do in the next five minutes, then who to contact in your country — wallet provider first, because it is the only one that can still stop the transfer."],
  ];

  const cw = (CW - 0.6) / 3;
  beats.forEach(([n, title, body], i) => {
    const x = M + i * (cw + 0.3);
    card(s, x, 2.36, cw, 3.24);
    badge(s, x + 0.36, 2.74, n, { d: 0.56, size: 15 });
    s.addText(title, {
      x: x + 0.36, y: 3.48, w: cw - 0.72, h: 0.38,
      fontFace: FONT_H, fontSize: 19, bold: true, color: C.primary, isTextBox: true, margin: 0,
    });
    s.addText(body, {
      x: x + 0.36, y: 3.94, w: cw - 0.72, h: 1.5,
      fontFace: FONT_B, fontSize: 13, color: C.ink, lineSpacing: 17, isTextBox: true, margin: 0,
    });
  });

  s.addText(
    "A verdict without a next step is only half an answer — so every non-safe verdict " +
      "ships with the pathway attached, not behind another tap.",
    {
      x: M, y: 5.86, w: CW, h: 0.4,
      fontFace: FONT_B, fontSize: 13.5, italic: true, color: C.primary, isTextBox: true, margin: 0,
    }
  );

  s.addNotes("If you only remember one slide, this is it. Detection is table stakes; the pathway is the product.");
}

// ===========================================================================
// 5 — What's built
// ===========================================================================
{
  const s = lightSlide("What's built", "Six modules, one backend, one shared database.", { tint: true });

  const mods = [
    ["Check Message", "AI classifier, grounded per market. Verdict, confidence, risk phrases, plain-language reason."],
    ["Get Help", "The ordered escalation ladder per country: wallet → regulator → police → support."],
    ["Report", "Anonymous by default. Excerpts redacted at intake, before anything is stored."],
    ["Number Lookup", "Crowd-sourced reputation, including which countries a number has been reported from."],
    ["Trending & Hotspots", "Live weighted-rules ranking, a regional map and a cross-country rollup."],
    ["Agent Fraud Sentinel", "B2B: upload an agent transaction log, get flagged anomalies with readable reasons."],
  ];

  const cw = (CW - 0.36) / 2;
  mods.forEach(([title, body], i) => {
    const col = i % 2;
    const row = Math.floor(i / 2);
    const x = M + col * (cw + 0.36);
    const y = 1.92 + row * 1.42;
    card(s, x, y, cw, 1.22, { fill: C.white });
    s.addText(title, {
      x: x + 0.34, y: y + 0.2, w: cw - 0.68, h: 0.32,
      fontFace: FONT_H, fontSize: 16, bold: true, color: C.primary, isTextBox: true, margin: 0,
    });
    s.addText(body, {
      x: x + 0.34, y: y + 0.56, w: cw - 0.68, h: 0.56,
      fontFace: FONT_B, fontSize: 12.5, color: C.ink, isTextBox: true, margin: 0,
    });
  });

  s.addText(
    `Plus a public landing page and a moderation dashboard. ${F.categories} scam categories, ` +
      `named by mechanism rather than by wallet brand — so one taxonomy holds in every market.`,
    {
      x: M, y: 6.12, w: CW, h: 0.4,
      fontFace: FONT_B, fontSize: 13, color: C.neutral, isTextBox: true, margin: 0,
    }
  );
}

// ===========================================================================
// 6 — Product proof
// ===========================================================================
{
  const s = lightSlide("It runs", "Not slideware — this is the running product.");

  s.addImage({
    path: path.join(REPO, "docs/screenshots/admin-overview.png"),
    x: M, y: 1.72, w: 8.5, h: 4.62,
    sizing: { type: "contain", w: 8.5, h: 4.62 },
  });

  const notes = [
    ["Live data", "Trending categories and the country hotspot map are computed from the reports table on every request."],
    ["Cross-border", "Numbers reported from more than one market are flagged for moderators as an operation, not a dispute."],
    ["Stated method", "The feed carries a method_note saying it is weighted rules, not a model — shown in the UI verbatim."],
  ];

  let y = 1.86;
  notes.forEach(([t, b]) => {
    s.addText(t, {
      x: 9.36, y, w: 3.3, h: 0.3,
      fontFace: FONT_H, fontSize: 15, bold: true, color: C.primary, isTextBox: true, margin: 0,
    });
    s.addText(b, {
      x: 9.36, y: y + 0.34, w: 3.3, h: 1.0,
      fontFace: FONT_B, fontSize: 12.5, color: C.ink, isTextBox: true, margin: 0,
    });
    y += 1.56;
  });

  s.addText("Moderation dashboard · captured against a running backend", {
    x: M, y: 6.48, w: 8.5, h: 0.28,
    fontFace: FONT_B, fontSize: 11, italic: true, color: C.neutral, isTextBox: true, margin: 0,
  });
}

// ===========================================================================
// 7 — Architecture
// ===========================================================================
{
  const s = lightSlide("Architecture", "One backend. Two clients. Zero setup to evaluate.", { tint: true });

  const tiers = [
    ["Clients", "Flutter app (Android-first)\nNext.js landing page + admin dashboard", C.secondary],
    ["FastAPI backend", "classifier · reputation · feed · support\ncountries · taxonomy · redaction · sentinel", C.primary],
    ["Storage", "In-memory store by default\nSupabase Postgres + RLS with one env var", "3C6E64"],
  ];

  let y = 1.92;
  tiers.forEach(([title, body, colour], i) => {
    s.addShape(pres.ShapeType.roundRect, {
      x: M, y, w: 7.5, h: 1.18, rectRadius: 0.1, fill: { color: colour },
    });
    s.addText(title, {
      x: M + 0.36, y: y + 0.16, w: 3.0, h: 0.34,
      fontFace: FONT_H, fontSize: 16, bold: true, color: C.white, isTextBox: true, margin: 0,
    });
    s.addText(body, {
      x: M + 0.36, y: y + 0.52, w: 6.8, h: 0.56,
      fontFace: FONT_B, fontSize: 12.5, color: "DCEDE9", isTextBox: true, margin: 0,
    });
    if (i < 2) {
      s.addText("↓", {
        x: M + 3.5, y: y + 1.16, w: 0.5, h: 0.32,
        fontFace: FONT_H, fontSize: 16, bold: true, color: C.neutral,
        align: "center", isTextBox: true, margin: 0,
      });
    }
    y += 1.52;
  });

  const facts = [
    ["Runs with no external services", "The full API surface works on the in-memory store — no Supabase project, no API key. A reviewer clones and runs."],
    ["Adding a market is a data change", "Two files: the country registry and the support-channel table. No service logic, no model, no client release."],
    ["Same code ships to production", "USE_SUPABASE=true swaps the store behind a protocol. Nothing above the persistence layer changes."],
  ];
  let fy = 1.92;
  facts.forEach(([t, b]) => {
    s.addText(t, {
      x: 8.42, y: fy, w: 4.26, h: 0.3,
      fontFace: FONT_H, fontSize: 14, bold: true, color: C.primary, isTextBox: true, margin: 0,
    });
    s.addText(b, {
      x: 8.42, y: fy + 0.32, w: 4.26, h: 1.02,
      fontFace: FONT_B, fontSize: 12, color: C.ink, isTextBox: true, margin: 0,
    });
    fy += 1.52;
  });
}

// ===========================================================================
// 8 — Why AI, and where not
// ===========================================================================
{
  const s = lightSlide("Judgement", "We justify AI case by case — and say so at runtime.");

  const cw = (CW - 0.4) / 2;

  card(s, M, 1.78, cw, 4.3, { fill: C.tint });
  badge(s, M + 0.34, 2.06, "AI", { d: 0.52, size: 12 });
  s.addText("Where AI earns its place", {
    x: M + 0.34, y: 2.72, w: cw - 0.68, h: 0.34,
    fontFace: FONT_H, fontSize: 17, bold: true, color: C.primary, isTextBox: true, margin: 0,
  });
  s.addText(
    [
      { text: "Message classification — scam text is adversarial and mutates constantly; a keyword blocklist catches yesterday's scripts, not tomorrow's. We ship a trained baseline and an LLM strategy so the trade-off is demonstrable, not asserted.", options: { bullet: true, breakLine: true, paraSpaceAfter: 10 } },
      { text: "Sentinel anomaly detection — agent fraud is unlabelled and drifts, which is what unsupervised learning is for. Paired with explicit rules as an honest baseline.", options: { bullet: true } },
    ],
    {
      x: M + 0.34, y: 3.18, w: cw - 0.68, h: 2.6,
      fontFace: FONT_B, fontSize: 12.5, color: C.ink, isTextBox: true, margin: 0,
    }
  );

  card(s, M + cw + 0.4, 1.78, cw, 4.3, { fill: C.tint });
  badge(s, M + cw + 0.74, 2.06, "—", { d: 0.52, size: 15, fill: C.danger });
  s.addText("Where it deliberately isn't", {
    x: M + cw + 0.74, y: 2.72, w: cw - 0.68, h: 0.34,
    fontFace: FONT_H, fontSize: 17, bold: true, color: C.danger, isTextBox: true, margin: 0,
  });
  s.addText(
    [
      { text: "Number reputation and the trending feed — plain CRUD and weighted rules. The API returns a method_note field saying so, and the UI shows it verbatim.", options: { bullet: true, breakLine: true, paraSpaceAfter: 10 } },
      { text: "Support pathways — a curated registry, never generated. A hallucinated police hotline is worse than no hotline, so unverified contacts are shown to the user as unverified rather than hidden.", options: { bullet: true, breakLine: true, paraSpaceAfter: 10 } },
      { text: "Evidence redaction — deterministic regex, so what is removed from a stored excerpt is auditable and testable rather than a model's judgement call.", options: { bullet: true } },
    ],
    {
      x: M + cw + 0.74, y: 3.18, w: cw - 0.68, h: 2.6,
      fontFace: FONT_B, fontSize: 12.5, color: C.ink, isTextBox: true, margin: 0,
    }
  );

  s.addNotes(
    "The support-registry decision is the one to dwell on in questions: it is the clearest " +
      "case where the responsible choice was to not use the model."
  );
}

// ===========================================================================
// 9 — Seven markets
// ===========================================================================
{
  const s = lightSlide("Coverage", `One codebase, ${F.markets.length} markets.`, { tint: true });

  chipRow(s, F.markets, M, 1.96, { size: 13.5 });

  const decisions = [
    ["Numbers stored in E.164", "0771234567 is a valid Zimbabwean, Ugandan and Tanzanian number. A national-format key would have silently merged three unrelated people's reputations — invisible in a demo, catastrophic in production."],
    ["One classifier, localised grounding", "The mechanism generalises even when the vocabulary doesn't, so one model trained across all markets sees more of each pattern than seven per-country models would."],
    ["Coarse regions, two hotspot maps", "A 47-county map splits reports too thin to mean anything. Cross-country rollup always; the regional breakdown only when a country is named."],
  ];

  let dy = 3.02;
  decisions.forEach(([t, b]) => {
    card(s, M, dy, CW, 1.06, { fill: C.white });
    s.addText(t, {
      x: M + 0.34, y: dy + 0.14, w: CW - 0.68, h: 0.3,
      fontFace: FONT_H, fontSize: 15, bold: true, color: C.primary, isTextBox: true, margin: 0,
    });
    s.addText(b, {
      x: M + 0.34, y: dy + 0.46, w: CW - 0.68, h: 0.5,
      fontFace: FONT_B, fontSize: 12.5, color: C.ink, isTextBox: true, margin: 0,
    });
    dy += 1.2;
  });
}

// ===========================================================================
// 10 — Traction
// ===========================================================================
{
  const s = lightSlide("Traction", "What already exists, not what's promised.");

  const stats = [
    [String(F.markets.length), "markets live", "behind one country registry"],
    [String(F.tests), "passing tests", "run in CI on every push"],
    [String(F.corpusTotal), "labelled messages", `${F.corpusScam} scam, spread evenly across markets`],
    ["6", "API modules", "classify · support · reputation · feed · reference · sentinel"],
  ];

  const cw = (CW - 0.54) / 4;
  stats.forEach(([big, label, sub], i) => {
    const x = M + i * (cw + 0.18);
    card(s, x, 1.82, cw, 2.1);
    s.addText(big, {
      x: x + 0.24, y: 1.96, w: cw - 0.48, h: 0.8,
      fontFace: FONT_H, fontSize: 44, bold: true, color: C.primary, isTextBox: true, margin: 0,
    });
    s.addText(label, {
      x: x + 0.24, y: 2.8, w: cw - 0.48, h: 0.3,
      fontFace: FONT_H, fontSize: 14, bold: true, color: C.ink, isTextBox: true, margin: 0,
    });
    s.addText(sub, {
      x: x + 0.24, y: 3.12, w: cw - 0.48, h: 0.72,
      fontFace: FONT_B, fontSize: 11.5, color: C.neutral, isTextBox: true, margin: 0,
    });
  });

  const built = [
    "FastAPI backend with a full API surface that runs with zero external services",
    "Flutter Android-first app: check, help, report, lookup, feed, sentinel",
    "Deployed landing page and a password-gated moderation dashboard",
    "Supabase schema with Row Level Security, and a synthetic dataset disclosed in full",
    "Version-pinned dependencies, CI running pytest plus web build and lint on every push",
  ];

  s.addText("Also shipped", {
    x: M, y: 4.24, w: 5, h: 0.34,
    fontFace: FONT_H, fontSize: 17, bold: true, color: C.ink, isTextBox: true, margin: 0,
  });
  s.addText(
    built.map((b, i) => ({
      text: b,
      options: { bullet: true, breakLine: i < built.length - 1, paraSpaceAfter: 7 },
    })),
    {
      x: M, y: 4.66, w: CW, h: 2.0,
      fontFace: FONT_B, fontSize: 13.5, color: C.ink, isTextBox: true, margin: 0,
    }
  );
}

// ===========================================================================
// 11 — Business model & path to pilot
// ===========================================================================
{
  const s = lightSlide("Sustainability", "Who pays, and what happens next.", { tint: true });

  const streams = [
    ["Free", "Consumers", "Checking, reporting, lookup and the support pathway stay free. This is the part that protects people and the part least able to pay for itself."],
    ["B2B", "Agents & SMEs", "Agent Fraud Sentinel licensed per agent or per till to mobile-money agent networks and SMEs who have no fraud tooling today."],
    ["Institutional", "Telcos, banks, regulators", "Licensed access to aggregated, anonymised cross-border scam signal — the asset no single-country tool can offer."],
  ];

  const cw = (CW - 0.4) / 3;
  streams.forEach(([tag, who, body], i) => {
    const x = M + i * (cw + 0.2);
    card(s, x, 1.82, cw, 2.16, { fill: C.white });
    s.addShape(pres.ShapeType.roundRect, {
      x: x + 0.3, y: 2.04, w: 0.16 * tag.length + 0.5, h: 0.4, rectRadius: 0.2,
      fill: { color: i === 0 ? C.secondary : C.primary },
    });
    s.addText(tag, {
      x: x + 0.3, y: 2.04, w: 0.16 * tag.length + 0.5, h: 0.4,
      fontFace: FONT_H, fontSize: 11.5, bold: true, color: C.white,
      align: "center", valign: "middle", isTextBox: true, margin: 0,
    });
    s.addText(who, {
      x: x + 0.3, y: 2.56, w: cw - 0.6, h: 0.3,
      fontFace: FONT_H, fontSize: 15, bold: true, color: C.ink, isTextBox: true, margin: 0,
    });
    s.addText(body, {
      x: x + 0.3, y: 2.9, w: cw - 0.6, h: 0.94,
      fontFace: FONT_B, fontSize: 12, color: C.neutral, isTextBox: true, margin: 0,
    });
  });

  s.addText("Path to pilot — sequenced by market, not launched everywhere at once", {
    x: M, y: 4.28, w: CW, h: 0.34,
    fontFace: FONT_H, fontSize: 16, bold: true, color: C.ink, isTextBox: true, margin: 0,
  });

  const phases = [
    ["Now", "Harden the MVP"],
    ["Month 1–3", "One named partner in one launch market; that market's support contacts verified; dispute flow built"],
    ["Month 4–6", "On-device classifier, multi-agent Sentinel dashboards, second market"],
    ["Month 7–12", "Telco, regulator and bank partnerships; iOS; per-jurisdiction data-protection audit"],
  ];

  const pw = (CW - 0.54) / 4;
  phases.forEach(([when, what], i) => {
    const x = M + i * (pw + 0.18);
    card(s, x, 4.76, pw, 1.5, { fill: C.white });
    s.addText(when, {
      x: x + 0.26, y: 4.94, w: pw - 0.52, h: 0.3,
      fontFace: FONT_H, fontSize: 13.5, bold: true, color: C.secondary, isTextBox: true, margin: 0,
    });
    s.addText(what, {
      x: x + 0.26, y: 5.26, w: pw - 0.52, h: 0.9,
      fontFace: FONT_B, fontSize: 11.5, color: C.ink, isTextBox: true, margin: 0,
    });
  });

  s.addNotes(
    "The code is market-agnostic; partnerships, support-contact verification and language " +
      "coverage are not. That is why the plan sequences markets instead of claiming seven at launch."
  );
}

// ===========================================================================
// 12 — What we are not claiming
// ===========================================================================
{
  const s = lightSlide("Honesty", "What we are not claiming.");

  s.addText(
    "Every one of these is disclosed in the repository rather than left for a reviewer to find.",
    {
      x: M, y: 1.9, w: 9.8, h: 0.34,
      fontFace: FONT_B, fontSize: 14, color: C.neutral, isTextBox: true, margin: 0,
    }
  );

  const gaps = [
    ["Support contacts are mostly unverified", "Only long-standing national short codes are marked verified. The rest name the right organisation with an unconfirmed number — surfaced to the user as unverified, and blocking before a pilot in that market."],
    ["The product is English-only", "Interface, corpus, prompt and explanations. Across these markets the people most exposed to mobile-money fraud overlap heavily with those least likely to read English comfortably."],
    ["The data is synthetic", `${F.corpusTotal} generated messages and 200 generated transactions, fully disclosed. No real user messages or transactions were collected.`],
    ["No per-jurisdiction privacy review", "Seven overlapping regimes. The design targets their common floor; the country-by-country audit is required before real user data and is not done."],
    ["No pilot partner yet", "A target profile, not a secured partnership. Stated as pending rather than filled with a name."],
  ];

  let y = 2.36;
  gaps.forEach(([t, b]) => {
    card(s, M, y, CW, 0.88);
    badge(s, M + 0.3, y + 0.23, "!", { d: 0.44, size: 14, fill: C.warning });
    s.addText(t, {
      x: M + 0.92, y: y + 0.12, w: CW - 1.28, h: 0.28,
      fontFace: FONT_H, fontSize: 14.5, bold: true, color: C.ink, isTextBox: true, margin: 0,
    });
    s.addText(b, {
      x: M + 0.92, y: y + 0.42, w: CW - 1.28, h: 0.42,
      fontFace: FONT_B, fontSize: 12, color: C.neutral, isTextBox: true, margin: 0,
    });
    y += 0.93;
  });

  s.addNotes(
    "A reviewer will find these anyway. Naming them first is both more useful and more " +
      "credible than a checklist of unqualified yeses — and it is the same posture the " +
      "product takes with users when a support contact is unverified."
  );
}

// ===========================================================================
// 13 — Ask
// ===========================================================================
{
  const s = darkSlide();

  s.addText("The ask", {
    x: M, y: 0.72, w: CW, h: 0.34,
    fontFace: FONT_H, fontSize: 12, bold: true, color: C.secondary,
    charSpacing: 1.4, isTextBox: true, margin: 0,
  });
  s.addText("People can only act on information they can verify.", {
    x: M, y: 1.1, w: 11.6, h: 1.08,
    fontFace: FONT_H, fontSize: 29, bold: true, color: C.white, isTextBox: true, margin: 0,
  });
  s.addText(
    "ChengetAI makes a suspicious message checkable, a report safe to file, and help " +
      "findable — in that order.",
    {
      x: M, y: 2.26, w: 10.6, h: 0.56,
      fontFace: FONT_B, fontSize: 15, color: "C9DED8", isTextBox: true, margin: 0,
    }
  );

  const asks = [
    ["A pilot partner", "An introduction to one agent network or telco district in a single launch market."],
    ["Contact verification", "Help confirming national support-desk numbers — the blocker before any pilot."],
    ["Mentorship", "On the dispute and human-review flow, and on what non-English coverage really takes."],
  ];

  const cw = (CW - 0.4) / 3;
  asks.forEach(([t, b], i) => {
    const x = M + i * (cw + 0.2);
    s.addShape(pres.ShapeType.roundRect, {
      x, y: 2.98, w: cw, h: 1.78, rectRadius: 0.1, fill: { color: "13564A" },
    });
    badge(s, x + 0.3, 3.2, String(i + 1), { d: 0.44, size: 13, fill: C.secondary });
    s.addText(t, {
      x: x + 0.3, y: 3.76, w: cw - 0.6, h: 0.3,
      fontFace: FONT_H, fontSize: 15, bold: true, color: C.white, isTextBox: true, margin: 0,
    });
    s.addText(b, {
      x: x + 0.3, y: 4.08, w: cw - 0.6, h: 0.62,
      fontFace: FONT_B, fontSize: 12, color: "A8CCC3", isTextBox: true, margin: 0,
    });
  });

  s.addText("Built by", {
    x: M, y: 4.96, w: 4, h: 0.28,
    fontFace: FONT_H, fontSize: 11.5, bold: true, color: C.secondary,
    charSpacing: 1.2, isTextBox: true, margin: 0,
  });
  s.addText("Lester Rusike", {
    x: M, y: 5.26, w: 5.2, h: 0.32,
    fontFace: FONT_H, fontSize: 17, bold: true, color: C.white, isTextBox: true, margin: 0,
  });
  s.addText("Product, backend and AI engineering, architecture, compliance", {
    x: M, y: 5.6, w: 5.6, h: 0.3,
    fontFace: FONT_B, fontSize: 12, color: "A8CCC3", isTextBox: true, margin: 0,
  });
  s.addText("Frontend contribution: Agnes Goora (Flutter and web UI)", {
    x: M, y: 5.92, w: 6.2, h: 0.3,
    fontFace: FONT_B, fontSize: 11.5, italic: true, color: "8FB5AC", isTextBox: true, margin: 0,
  });

  s.addText("chengetai.vercel.app", {
    x: 8.0, y: 5.26, w: 4.7, h: 0.32,
    fontFace: FONT_H, fontSize: 16, bold: true, color: C.secondary, isTextBox: true, margin: 0,
  });
  s.addText("github.com/Lesruez93/ChengetAi", {
    x: 8.0, y: 5.62, w: 4.7, h: 0.3,
    fontFace: FONT_B, fontSize: 12, color: "A8CCC3", isTextBox: true, margin: 0,
  });

  s.addNotes(
    "Close on the first line: people can only act on information they can trust. That is the " +
      "OSF framing, and it is what this product does in three concrete steps."
  );
}

pres.writeFile({ fileName: OUT }).then(() => {
  console.log(`Wrote ${OUT}`);
  console.log(
    `Facts baked in: ${F.markets.length} markets · ${F.tests} tests · ` +
      `${F.corpusTotal} corpus messages (${F.corpusScam} scam) · ${F.categories} scam categories`
  );
});
