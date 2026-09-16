# Accessibility Check

Accessibility notes. Covers font size, contrast, mobile view,
low-bandwidth mode, and language considerations across the Flutter app and the Next.js web app.

## Color contrast

Brand and semantic colors are shared between `app/lib/core/theme.dart` and `web/src/app/globals.css`
by design, so contrast holds consistently across both surfaces.

| Pairing | Approx. contrast ratio | WCAG 2.1 AA threshold | Result |
|---|---|---|---|
| Brand primary teal (`#0F6B5C`) text/icons on white background | ~6.4:1 | 4.5:1 (normal text), 3:1 (large text/UI) | Pass |
| Foreground `#0F172A` body text on white background | High (near-black on white) | 4.5:1 | Pass |
| Danger red (`#C62828`) on white — scam verdict | Meets AA for large text/icon use; verdict labels are paired with icon + text, not color alone | 3:1 (UI components) | Pass |
| Warning amber (`#B8860B`) on white — suspicious verdict | Darkened amber chosen specifically to hold contrast (avoids pale/light-yellow-on-white failure common in default Material amber) | 3:1 (UI components) | Pass |

Risk/verdict states (`AppColors.forVerdict`, `AppColors.forHotspotLevel`, `AppColors.forRiskLevel` in
`theme.dart`) are never conveyed by color alone — every colored state ships with a text label
(`scam`/`suspicious`/`safe`, risk chip text) so the product remains usable for color-blind users.

## Font size and readability

- Material 3 default type scale is used (`useMaterial3: true` in `buildAppTheme()`), which sets
  body text at 14–16sp and headline/title sizes well above minimum legibility thresholds — no
  custom font-size overrides shrink text below Material defaults.
- The one deliberately small text style is `ChipThemeData.labelStyle` at 12.5sp for risk chips —
  used only for short category labels (e.g. "Wrong deposit / reversal"), never for body content a
  user must read to understand a verdict. Category keys are always rendered through
  `humanizeCategory()` rather than shown raw, so no user ever reads a snake_case identifier.

## Mobile responsiveness / low-bandwidth mode

- The Flutter app is Android-first and built mobile-native — there is no responsive-breakpoint
  concern in the way a web app has one, since every screen is designed for a phone viewport from
  the start.
- **Offline/low-bandwidth behaviour** (docs/architecture.md → "Offline behaviour"): the app caches
  recent number lookups locally, and bundles the country registry and category list so the report
  form and country picker render instantly and work without connectivity — the common case for
  prepaid users in low-signal areas. Message classification, Sentinel CSV analysis and the support
  pathway require connectivity in the current MVP. Caching the support pathway per country is the
  highest-priority offline gap, since needing help and having no signal frequently coincide;
  on-device classifier execution is a Month 4–6 roadmap item.
- **Hotspot maps are lists, not map graphics.** A list needs no per-country map asset (seven and
  counting), renders on a low-end device, and is readable by a screen reader — which a coloured
  polygon is not.
- The web landing page (`web/`) uses Tailwind's default responsive utilities and has no fixed-width
  layouts that would overflow on small viewports; it has not yet been tested at the 320px breakpoint
  specifically (see "Known gaps" below).

## Language considerations

**ChengetAI is English-only, end to end.** The interface, the training corpus, the classifier
prompt, the support pathways and the explanations are all English. This is a deliberate scope
boundary for the MVP, and it is the product's single largest accessibility gap — stated plainly
here rather than softened.

What that means concretely:

- A message written in Shona, Swahili, Nigerian Pidgin or isiZulu **will still be scored**, because
  the classifier accepts any text. But it will not be scored *reliably*, because neither the corpus
  nor the prompt covers those languages. The LLM prompt is instructed to say so in its explanation
  and lower its confidence rather than guess, so an unreliable verdict is at least an honest one.
- Everything else about a verdict *is* localised: the wallets named, the currency, the scam
  patterns, and the support contacts. A Kenyan user's explanation names M-PESA and a Nigerian
  user's names their own bank. Localisation here is about **market**, not language.
- What English-only costs: across these markets, the people most exposed to mobile-money fraud
  include those least likely to read English comfortably — older adults, rural users, and
  first-time smartphone owners. An English-only scam tool is least available to the people it would
  help most. We are not claiming otherwise.

Language coverage is a roadmap item, and a genuine one rather than a placeholder: it needs a corpus
per language, native-speaker review of explanations, and UI localisation — not a translation pass.
The order it would happen in is corpus first (so verdicts are correct), then explanations, then UI.

## Known gaps (disclosed)

1. No automated accessibility audit (e.g. Flutter's `flutter_a11y` lint set, axe-core for the web
   app) has been run yet — the contrast figures above are calculated manually from the defined
   theme colors, not machine-verified against rendered output.
2. No screen-reader (TalkBack/VoiceOver) pass has been performed on the Flutter app.
3. Web app has not been tested at the 320px mobile breakpoint specifically.
4. **The product is English-only in every market** — interface, corpus, prompt and explanations
   (see "Language considerations" above). This is the largest accessibility gap in the product.
