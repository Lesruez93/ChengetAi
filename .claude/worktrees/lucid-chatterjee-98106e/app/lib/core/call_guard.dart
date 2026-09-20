import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'constants.dart';
import 'country_preference.dart';
import 'models/screened_event.dart';

/// Dart side of the incoming call, SMS and WhatsApp screening feature.
///
/// The screening itself lives in Kotlin (see
/// `android/app/src/main/kotlin/com/chengetai/chengetai/callguard/`) because a
/// call or text can arrive when the Flutter engine is not running at all — the
/// app may have been swiped away or never opened since boot. Putting the
/// lookup in Dart would mean warnings that only work when the app happens to
/// be alive, which is the opposite of what someone needs from this.
///
/// This class is therefore a thin control surface: sync config down, read
/// status and history up, and trigger the same pipeline for a test event.
///
/// Android-only. iOS forbids third-party apps from inspecting an incoming
/// caller's number or reading SMS; the nearest iOS equivalents (a CallKit
/// call-directory extension, an SMS filter extension) upload a *static*
/// blocklist ahead of time and cannot do a live lookup. Those are different
/// features, not a port of this one, so on iOS every method here resolves to
/// an unsupported state rather than pretending.
class CallGuard {
  const CallGuard._();

  static const MethodChannel _channel = MethodChannel('chengetai/call_guard');

  /// Deliberately uses [defaultTargetPlatform] rather than `dart:io`'s
  /// `Platform`: this app has a web target (see `web/`), and importing
  /// `dart:io` at all breaks the web build.
  static bool get _isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Push the resolved API base URL and selected market down to the Kotlin
  /// side, which cannot read either from Dart.
  ///
  /// Called on startup and whenever the country changes, so a debug build
  /// pointed at a local backend screens against that backend, and a user who
  /// switches markets gets local-format caller IDs resolved correctly.
  static Future<void> syncConfig() async {
    if (!_isAvailable) return;
    try {
      await _channel.invokeMethod<void>('syncConfig', <String, dynamic>{
        'baseUrl': AppConfig.apiBaseUrl,
        'countryCode': CountryPreference.code,
      });
    } on PlatformException {
      // Config sync is best-effort — the Kotlin side falls back to the same
      // defaults compiled into constants.dart, so a failure here degrades to
      // "screens against production" rather than "screening is broken".
    }
  }

  static Future<CallGuardStatus> status() async {
    if (!_isAvailable) return CallGuardStatus.unsupported;
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMethod<Map<dynamic, dynamic>>('status');
      if (result == null) return CallGuardStatus.unsupported;
      return CallGuardStatus.fromMap(result);
    } on PlatformException {
      return CallGuardStatus.unsupported;
    } on MissingPluginException {
      return CallGuardStatus.unsupported;
    }
  }

  /// Open the system dialog that makes ChengetAI the call screening app.
  ///
  /// Returns nothing useful on purpose: the dialog's result code is not a
  /// reliable grant signal across OEM builds. Re-read [status] once the app
  /// resumes instead.
  static Future<void> requestRole() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('requestRole');
  }

  static Future<void> requestSmsPermission() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('requestSmsPermission');
  }

  /// Opens the system notification-access list, the only place WhatsApp
  /// screening can be enabled. There is no runtime prompt for it.
  static Future<void> openNotificationAccessSettings() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('openNotificationAccessSettings');
  }

  static Future<void> requestNotificationPermission() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('requestNotificationPermission');
  }

  static Future<void> openNotificationSettings() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('openNotificationSettings');
  }

  static Future<CallGuardStatus> setEnabled(bool enabled) async {
    if (!_isAvailable) return CallGuardStatus.unsupported;
    final Map<dynamic, dynamic>? result = await _channel
        .invokeMethod<Map<dynamic, dynamic>>('setEnabled', <String, dynamic>{'enabled': enabled});
    if (result == null) return CallGuardStatus.unsupported;
    return CallGuardStatus.fromMap(result);
  }

  static Future<List<ScreenedEvent>> screenedEvents() async {
    if (!_isAvailable) return const <ScreenedEvent>[];
    try {
      final String? raw = await _channel.invokeMethod<String>('screenedEvents');
      if (raw == null || raw.isEmpty) return const <ScreenedEvent>[];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic e) => ScreenedEvent.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } on PlatformException {
      return const <ScreenedEvent>[];
    } on FormatException {
      return const <ScreenedEvent>[];
    }
  }

  static Future<void> clearScreenedEvents() async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('clearScreenedEvents');
  }

  /// Run a sender through the real screening pipeline without real traffic.
  ///
  /// This is not a mock: it performs the same lookup and classification
  /// against the same base URL and posts the same notification, so it
  /// exercises everything that actually breaks in the field. The only
  /// difference is the entry point and a flag marking the history row a test.
  ///
  /// [body] is only meaningful for [ThreatChannel.sms] — it is what gets sent
  /// to `POST /classify`.
  static Future<void> simulateEvent({
    required ThreatChannel channel,
    required String sender,
    String? body,
  }) async {
    if (!_isAvailable) return;
    await _channel.invokeMethod<void>('simulateEvent', <String, dynamic>{
      'channel': channel.key,
      'sender': sender,
      if (body != null && body.isNotEmpty) 'body': body,
    });
  }
}
