/// App-wide constants: API configuration and value lists mirrored from the
/// backend so form pickers (province, category) stay in sync with what the
/// API actually accepts.
library;

class AppConfig {
  const AppConfig._();

  /// Backend base URL.
  ///
  /// Defaults to `10.0.2.2`, the special alias the Android emulator uses to
  /// reach the host machine's `localhost` — so `uvicorn app.main:app --reload`
  /// running on your dev machine is reachable out of the box when you run
  /// this app in the emulator. It will NOT work on a physical device or in
  /// release builds; override it at build/run time:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:8000
  ///   flutter build apk --dart-define=API_BASE_URL=https://api.chengetai.example
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const Duration apiTimeout = Duration(seconds: 20);
}

/// Zimbabwean provinces, mirrored from `backend/app/models/domain.py::ZIMBABWE_PROVINCES`.
/// Kept as a plain client-side list (rather than fetched from the API) since
/// it is effectively static reference data used purely to populate form pickers.
const List<String> kZimbabweProvinces = <String>[
  'Harare',
  'Bulawayo',
  'Manicaland',
  'Mashonaland Central',
  'Mashonaland East',
  'Mashonaland West',
  'Masvingo',
  'Matabeleland North',
  'Matabeleland South',
  'Midlands',
];

/// Scam report categories. `category` is a free-text field on the backend
/// (see `ReportCreate` schema) but the app constrains input to this curated
/// set — mirrored from `docs/architecture.md` and `sample_data/seed.sql` —
/// plus "other" as an escape hatch, so reports stay comparable for aggregation.
const List<String> kScamCategories = <String>[
  'ecocash_reversal',
  'fake_job',
  'fake_forex',
  'wrong_transfer',
  'fake_loan_ngo',
  'church_prophet',
  'other',
];

/// Turns a `snake_case` category key into a human-readable label, e.g.
/// `ecocash_reversal` -> `Ecocash Reversal`.
String humanizeCategory(String category) {
  return category
      .split('_')
      .where((String part) => part.isNotEmpty)
      .map((String part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}
