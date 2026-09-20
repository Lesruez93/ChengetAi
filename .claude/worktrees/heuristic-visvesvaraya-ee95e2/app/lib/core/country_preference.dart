import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'constants.dart';

/// The user's selected market, held app-wide.
///
/// Every screen needs it: the classifier grounds its verdict in it, a
/// local-format number cannot be parsed without it, the hotspot map is scoped
/// by it, and the support pathway is entirely determined by it. Threading it
/// through four screens' constructors would mean a change in one tab silently
/// not reaching the others, so it lives here as a single [ValueListenable]
/// that screens watch.
///
/// Persisted to [SharedPreferences] because re-picking a country on every
/// launch is friction in exactly the moment the app is meant to be fast — and
/// the answer almost never changes for a given user.
class CountryPreference {
  CountryPreference._();

  static const String _storageKey = 'chengetai.country_code';

  static final ValueNotifier<String> codeNotifier =
      ValueNotifier<String>(AppConfig.defaultCountryCode);

  static String get code => codeNotifier.value;

  static CountryProfile get profile => CountryRegistry.byCode(codeNotifier.value);

  /// Load the stored choice. Any failure (first launch, cleared storage,
  /// a platform channel error) leaves the default in place rather than
  /// blocking startup — the user can still change it in the app.
  static Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? stored = prefs.getString(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        // Round-trip through the registry so a code removed from a later
        // build falls back instead of leaving the UI in a broken state.
        codeNotifier.value = CountryRegistry.byCode(stored).code;
      }
    } catch (_) {
      // Keep the default.
    }
  }

  static Future<void> set(String newCode) async {
    final String resolved = CountryRegistry.byCode(newCode).code;
    if (resolved == codeNotifier.value) {
      return;
    }
    codeNotifier.value = resolved;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, resolved);
    } catch (_) {
      // The in-memory value is already updated; persistence is best-effort.
    }
  }

  /// Best-effort refresh of the bundled country list from the API, so a market
  /// added on the backend appears without an app release. Silently keeps the
  /// bundled list if the call fails — an offline user must still be able to
  /// pick a country.
  static Future<void> refreshRegistry(ApiClient apiClient) async {
    try {
      CountryRegistry.refreshFrom(await apiClient.getCountries());
    } catch (_) {
      // Bundled list stands.
    }
  }
}
