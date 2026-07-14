# Accessibility Check

Design evidence item per AI4I Product Readiness ToR §9.1. Covers font size, contrast, mobile view,
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
  used only for short category labels (e.g. "ecocash_reversal"), never for body content a user must
  read to understand a verdict.

## Mobile responsiveness / low-bandwidth mode

- The Flutter app is Android-first and built mobile-native — there is no responsive-breakpoint
  concern in the way a web app has one, since every screen is designed for a phone viewport from
  the start.
- **Offline/low-bandwidth behaviour** (docs/architecture.md → "Offline behaviour"): the app caches
  the top-N flagged numbers locally so number-reputation lookups work without connectivity — the
  common case for prepaid users in low-signal areas. Message classification and Sentinel CSV
  analysis require connectivity in the current MVP; on-device classifier execution to extend
  offline coverage is a Month 4–6 roadmap item (proposal §3.2).
- The web landing page (`web/`) uses Tailwind's default responsive utilities and has no fixed-width
  layouts that would overflow on small viewports; it has not yet been tested at the 320px breakpoint
  specifically (see "Known gaps" below).

## Language considerations

- The scam-classifier training corpus and the LLM few-shot prompt are built specifically for
  Shona-English code-switched text (`docs/dataset_statement.md`, proposal §2.2) — the product's
  core accessibility consideration is linguistic, not just visual, since this is precisely the gap
  generic English-only tools leave for Zimbabwean users.
- Ndebele-language support is an explicit roadmap item (proposal §3.2, "Institutionalization" phase,
  Month 7–12) — not yet implemented. This is disclosed as a known gap, not claimed as done.

## Known gaps (disclosed)

1. No automated accessibility audit (e.g. Flutter's `flutter_a11y` lint set, axe-core for the web
   app) has been run yet — the contrast figures above are calculated manually from the defined
   theme colors, not machine-verified against rendered output.
2. No screen-reader (TalkBack/VoiceOver) pass has been performed on the Flutter app.
3. Web app has not been tested at the 320px mobile breakpoint specifically.
4. Ndebele-language support is roadmap, not implemented (see above).
