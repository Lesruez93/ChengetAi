import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/reputation_models.dart';

/// Local cache of recent number lookups.
///
/// Per `docs/architecture.md` ("Offline behaviour"): the app caches the top
/// N flagged numbers from `/numbers` lookups so a basic "is this number
/// flagged?" check still works without connectivity. This is a lightweight
/// LRU-ish cache backed by `SharedPreferences` (fine for a few dozen
/// entries; not intended as a general offline datastore).
class LookupCache {
  LookupCache._(this._prefs);

  static const String _storageKey = 'chengetai.number_lookup_cache.v1';
  static const int _maxEntries = 50;

  final SharedPreferences _prefs;

  static Future<LookupCache> open() async {
    return LookupCache._(await SharedPreferences.getInstance());
  }

  Map<String, dynamic> _readRaw() {
    final String? raw = _prefs.getString(_storageKey);
    if (raw == null) return <String, dynamic>{};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> save(NumberReputation reputation) async {
    final Map<String, dynamic> all = _readRaw();
    all[reputation.msisdn] = <String, dynamic>{
      'reputation': reputation.toJson(),
      'cached_at': DateTime.now().toUtc().toIso8601String(),
    };

    // Trim to the most recently cached entries if we've grown past the cap.
    if (all.length > _maxEntries) {
      final List<MapEntry<String, dynamic>> entries = all.entries.toList()
        ..sort((MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) {
          final String aTime = (a.value as Map<String, dynamic>)['cached_at'] as String;
          final String bTime = (b.value as Map<String, dynamic>)['cached_at'] as String;
          return bTime.compareTo(aTime);
        });
      all
        ..clear()
        ..addEntries(entries.take(_maxEntries));
    }

    await _prefs.setString(_storageKey, jsonEncode(all));
  }

  NumberReputation? read(String msisdn) {
    final Map<String, dynamic> all = _readRaw();
    final dynamic entry = all[msisdn];
    if (entry == null) return null;
    final Map<String, dynamic> map = entry as Map<String, dynamic>;
    final NumberReputation reputation =
        NumberReputation.fromJson(map['reputation'] as Map<String, dynamic>);
    final DateTime cachedAt = DateTime.parse(map['cached_at'] as String);
    return reputation.asCached(cachedAt: cachedAt);
  }
}
