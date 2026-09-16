import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// A device-scoped pseudonymous reporter id.
///
/// The report form offers a genuine choice, and this is what makes it real
/// rather than cosmetic:
///
/// - **Anonymous** sends no `reporter_id` at all. The report is still counted
///   and still contributes to a number's reputation, but the backend cannot
///   rate-limit or duplicate-collapse it, and nothing links it to any other
///   report this device has made.
/// - **Not anonymous** sends this id. That buys the reporter per-reporter
///   abuse controls, duplicate detection, and a submission confirmation — the
///   trade-off being that their reports become linkable to each other.
///
/// The id is random and generated on-device. It is not a phone number, a
/// name, or an account: it identifies a *reporting stream*, not a person, so
/// choosing the non-anonymous path still discloses far less than signing in
/// would. It is never sent unless the user turns anonymity off.
class ReporterIdentity {
  ReporterIdentity._();

  static const String _storageKey = 'chengetai.reporter_id';
  static String? _cached;

  /// Returns the stored id, generating and persisting one on first use.
  /// Returns null if storage is unavailable — in which case the report is
  /// simply sent anonymously rather than failing.
  static Future<String?> get() async {
    if (_cached != null) {
      return _cached;
    }
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String? id = prefs.getString(_storageKey);
      if (id == null || id.isEmpty) {
        id = _generate();
        await prefs.setString(_storageKey, id);
      }
      _cached = id;
      return id;
    } catch (_) {
      return null;
    }
  }

  /// Forget the current id and start a new reporting stream, breaking the link
  /// between past and future non-anonymous reports from this device.
  static Future<void> reset() async {
    _cached = null;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (_) {
      // Cache is cleared either way; the next get() will generate a new id.
    }
  }

  static String _generate() {
    final Random random = Random.secure();
    final String hex = List<String>.generate(
      16,
      (int _) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return 'anon-$hex';
  }
}
