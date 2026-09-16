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

The product's core accessibility consideration is linguistic, not visual: this is precisely the gap
generic English-only tools leave across the region.

- The training corpus and the LLM prompt handle code-switched text in **English, Shona, Swahili,
  Luganda and Nigerian Pidgin** (`docs/dataset_statement.md`). The LLM prompt is grounded per
  market, so a Kenyan user's explanation names M-PESA and a Nigerian user's names their own bank.
- **The interface itself is still English-only.** Understanding a *scam message* in Shona or Swahili
  is not the same as being able to *use the app* in it, and only the first is implemented. Full UI
  localisation is roadmap, not done.
- Language coverage is uneven in a way the market list hides: the corpus is richest for Shona and
  Swahili and thinnest for Luganda, Pidgin and the South African languages. isiZulu, isiXhosa,
  Afrikaans, Twi, Ga, Ewe, Hausa, Yoruba and Igbo are named in the country registry as languages
  messages plausibly arrive in, but are **not** yet represented in the training corpus.
- Additional language coverage is an explicit roadmap item ("Institutionalization" phase, Month
  7–12) — disclosed as a known gap, not claimed as done.

## Known gaps (disclosed)

1. No automated accessibility audit (e.g. Flutter's `flutter_a11y` lint set, axe-core for the web
   app) has been run yet — the contrast figures above are calculated manually from the defined
   theme colors, not machine-verified against rendered output.
2. No screen-reader (TalkBack/VoiceOver) pass has been performed on the Flutter app.
3. Web app has not been tested at the 320px mobile breakpoint specifically.
4. UI localisation is not implemented — the interface is English-only in every market (see above).
5. The training corpus covers only some of the languages the country registry names (see above).
