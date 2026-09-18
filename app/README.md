# ChengetAI — Flutter app

The Android-first consumer client. Scam-message checking, the support pathway,
community reporting, number lookup, the alerts feed, and the Agent Fraud
Sentinel uploader.

Everything here talks to the FastAPI backend in `../backend/` — see
`../docs/api.md` for the endpoints and `lib/core/api_client.dart` for the typed
client.

## Setup

Platform folders (`android/`, `ios/`) are intentionally not checked in, so they
scaffold cleanly against whatever Flutter/AGP/Kotlin version you have locally:

```bash
flutter create . --org com.chengetai --project-name chengetai
```

Then confirm `android/app/src/main/AndroidManifest.xml` has the INTERNET
permission — every screen talks to the backend:

```xml
<uses-permission android:name="android.permission.INTERNET" />
```

```bash
flutter pub get
flutter run     # emulator reaches the host backend at http://10.0.2.2:8000
```

Override the backend URL for a physical device or a deployed backend:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
flutter build apk --dart-define=API_BASE_URL=https://api.chengetai.example
```

## Structure

```
lib/
├── core/
│   ├── api_client.dart          # typed wrapper over the FastAPI backend
│   ├── constants.dart           # API config + bundled country registry + scam categories
│   ├── country_preference.dart  # the selected market, app-wide and persisted
│   ├── reporter_identity.dart   # random on-device id for non-anonymous reports
│   ├── models/                  # mirrors backend/app/schemas/*.py
│   ├── routing.dart
│   └── theme.dart
├── features/
│   ├── check_message/           # paste a message → verdict + next steps
│   ├── support/                 # "Get help": the per-country escalation ladder
│   ├── lookup/                  # number reputation, with an offline cache
│   ├── feed/                    # alerts, trending, regional + cross-country hotspots
│   ├── sentinel/                # agent transaction CSV upload
│   ├── auth/                    # login/signup (stub pending real Supabase Auth)
│   └── home/home_shell.dart     # bottom-nav shell
└── shared/widgets/              # verdict card, report sheet, country switcher, chips...
```

## Country awareness

The selected market decides how a local-format number is parsed, which wallets
and currency the classifier is grounded in, which regions the picker offers, and
which support desks are listed. It lives in `CountryPreference` as a single
`ValueListenable` that every screen watches, rather than being threaded through
constructors — a change in one tab has to reach all of them.

The country registry and category list are **bundled** in `constants.dart` so
the report form and country picker work offline, and overlaid from
`GET /reference/countries` when the network is available, so a market added on
the backend appears without an app release.

## Tests

```bash
flutter test
```

Covers the country registry's fallback behaviour, category labelling, and JSON
parsing for every model — including that an anonymous report sends no
`reporter_id` key at all, and that an unverified support contact survives
parsing as unverified.

> **Note:** this app was written and reviewed without a Flutter SDK available
> in the authoring environment, so `flutter pub get` / `analyze` / `test` have
> not been run against it. Do a first-build check of `fl_chart` tooltip callback
> signatures and Material icon names against your installed SDK version.
