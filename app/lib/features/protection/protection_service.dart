import 'dart:convert';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/models/protection_models.dart';

/// Dart side of the `chengetai/protection` MethodChannel.
///
/// Live call/SMS screening is Android-only (see `docs/architecture.md` →
/// "Live call & SMS screening" for why iOS cannot do the same thing), so every
/// method here degrades to a no-op returning [ProtectionStatus.unavailable]
/// on other platforms rather than throwing — the Protection screen renders an
/// explanation instead of an error.
class ProtectionService {
  ProtectionService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('chengetai/protection');

  final MethodChannel _channel;

  /// False on iOS/web/desktop, where no native implementation is registered.
  ///
  /// Uses [defaultTargetPlatform] rather than `dart:io`'s `Platform`, since
  /// this app also builds for web (`app/web/`) and importing `dart:io` would
  /// break that compile outright.
  static bool get isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<ProtectionStatus> _invokeStatus(String method, [Map<String, dynamic>? args]) async {
    if (!isSupportedPlatform) return ProtectionStatus.unavailable;
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMapMethod<dynamic, dynamic>(method, args);
      if (result == null) return ProtectionStatus.unavailable;
      return ProtectionStatus.fromChannelMap(result);
    } on PlatformException {
      // A "busy" error (an OS prompt already open) or a missing implementation
      // shouldn't take the screen down — re-read whatever state we can.
      return getStatus();
    } on MissingPluginException {
      return ProtectionStatus.unavailable;
    }
  }

  Future<ProtectionStatus> getStatus() async {
    if (!isSupportedPlatform) return ProtectionStatus.unavailable;
    try {
      final Map<dynamic, dynamic>? result =
          await _channel.invokeMapMethod<dynamic, dynamic>('getStatus');
      if (result == null) return ProtectionStatus.unavailable;
      return ProtectionStatus.fromChannelMap(result);
    } on PlatformException {
      return ProtectionStatus.unavailable;
    } on MissingPluginException {
      return ProtectionStatus.unavailable;
    }
  }

  /// Opens the system role prompt ("Allow ChengetAI to screen calls?").
  /// Resolves once the user answers, with the state re-read from the OS.
  Future<ProtectionStatus> requestCallScreeningRole() =>
      _invokeStatus('requestCallScreeningRole');

  Future<ProtectionStatus> requestSmsPermission() => _invokeStatus('requestSmsPermission');

  Future<ProtectionStatus> requestNotificationPermission() =>
      _invokeStatus('requestNotificationPermission');

  Future<ProtectionStatus> setCallScreeningEnabled(bool enabled) =>
      _invokeStatus('setSetting', <String, dynamic>{'key': 'screen_calls', 'enabled': enabled});

  Future<ProtectionStatus> setSmsScreeningEnabled(bool enabled) =>
      _invokeStatus('setSetting', <String, dynamic>{'key': 'screen_sms', 'enabled': enabled});

  Future<ProtectionStatus> setBlockHighRiskCalls(bool enabled) =>
      _invokeStatus('setSetting', <String, dynamic>{'key': 'block_high_risk', 'enabled': enabled});

  /// Fetches the flagged-number set from the backend and writes it into native
  /// storage, where the call-screening service and SMS receiver can reach it
  /// with no Flutter engine running.
  ///
  /// Returns the status after syncing. Throws [ApiException] if the backend is
  /// unreachable — callers surface that, since a blocklist that silently stops
  /// updating is worse than one that says it's stale.
  Future<ProtectionStatus> syncBlocklist(ApiClient apiClient) async {
    if (!isSupportedPlatform) return ProtectionStatus.unavailable;

    final ProtectionStatus current = await getStatus();
    final FlaggedNumbersSync sync =
        await apiClient.syncFlaggedNumbers(knownVersion: current.flaggedVersion);

    // Nothing changed server-side and we already hold that version: skip the
    // write entirely rather than re-persisting an identical list.
    if (sync.unchanged && current.hasBlocklist) return current;

    return _invokeStatus('syncFlaggedNumbers', <String, dynamic>{
      'version': sync.version,
      'numbers': sync.numbers.map((FlaggedNumber n) => n.toChannelMap()).toList(),
    });
  }

  /// The local screening log, newest first.
  Future<List<ScamDetection>> getDetections() async {
    if (!isSupportedPlatform) return <ScamDetection>[];
    try {
      final String? raw = await _channel.invokeMethod<String>('getDetections');
      if (raw == null || raw.isEmpty) return <ScamDetection>[];
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((dynamic e) => ScamDetection.fromJson(e as Map<String, dynamic>))
          .toList();
    } on PlatformException {
      return <ScamDetection>[];
    } on MissingPluginException {
      return <ScamDetection>[];
    } on FormatException {
      return <ScamDetection>[];
    }
  }

  Future<void> clearDetections() async {
    if (!isSupportedPlatform) return;
    try {
      await _channel.invokeMethod<void>('clearDetections');
    } on PlatformException {
      // Nothing actionable for the user; the list simply stays as it was.
    } on MissingPluginException {
      // No native side to clear.
    }
  }
}
