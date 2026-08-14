/// Models for live call/SMS screening: the blocklist sync payload from
/// `GET /numbers/flagged/sync` (mirrors `backend/app/schemas/reputation.py`)
/// and the native-side state read back over the `chengetai/protection`
/// MethodChannel.
library;

/// One entry of the on-device blocklist.
class FlaggedNumber {
  const FlaggedNumber({
    required this.msisdn,
    required this.riskLevel,
    required this.reportCount,
    required this.topCategory,
  });

  final String msisdn;
  final String riskLevel;
  final int reportCount;
  final String topCategory;

  factory FlaggedNumber.fromJson(Map<String, dynamic> json) {
    return FlaggedNumber(
      msisdn: json['msisdn'] as String,
      riskLevel: json['risk_level'] as String,
      reportCount: json['report_count'] as int,
      topCategory: json['top_category'] as String,
    );
  }

  /// The shape [ProtectionService.syncFlaggedNumbers] hands to Kotlin. Keys are
  /// the backend's snake_case, so native, Dart and the API all agree.
  Map<String, dynamic> toChannelMap() {
    return <String, dynamic>{
      'msisdn': msisdn,
      'risk_level': riskLevel,
      'report_count': reportCount,
      'top_category': topCategory,
    };
  }
}

/// Response of `GET /numbers/flagged/sync`.
class FlaggedNumbersSync {
  const FlaggedNumbersSync({
    required this.version,
    required this.generatedAt,
    required this.count,
    required this.unchanged,
    required this.numbers,
    required this.methodNote,
  });

  final String version;
  final DateTime generatedAt;
  final int count;

  /// True when the server recognised our `known_version` and skipped the
  /// payload — [numbers] is empty and the local blocklist is already current.
  final bool unchanged;
  final List<FlaggedNumber> numbers;
  final String methodNote;

  factory FlaggedNumbersSync.fromJson(Map<String, dynamic> json) {
    return FlaggedNumbersSync(
      version: json['version'] as String,
      generatedAt: DateTime.parse(json['generated_at'] as String),
      count: json['count'] as int,
      unchanged: json['unchanged'] as bool? ?? false,
      numbers: (json['numbers'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => FlaggedNumber.fromJson(e as Map<String, dynamic>))
          .toList(),
      methodNote: json['method_note'] as String? ?? '',
    );
  }
}

/// Snapshot of what screening is actually able to do right now, as reported by
/// the native side.
///
/// Kept as one object because the answer to "is protection on?" is never a
/// single flag: the user can have granted the role but left the feature off, or
/// switched it on before granting anything. The screen renders each gap
/// separately rather than collapsing them into one on/off state.
class ProtectionStatus {
  const ProtectionStatus({
    required this.callScreeningSupported,
    required this.callScreeningRoleHeld,
    required this.smsPermissionGranted,
    required this.notificationsGranted,
    required this.callScreeningEnabled,
    required this.smsScreeningEnabled,
    required this.blockHighRiskCalls,
    required this.flaggedCount,
    required this.flaggedVersion,
    required this.syncedAt,
  });

  /// False on Android 9 and below, and on devices with no dialer role (some
  /// tablets) — screening simply can't run there.
  final bool callScreeningSupported;
  final bool callScreeningRoleHeld;
  final bool smsPermissionGranted;
  final bool notificationsGranted;

  final bool callScreeningEnabled;
  final bool smsScreeningEnabled;
  final bool blockHighRiskCalls;

  final int flaggedCount;
  final String flaggedVersion;

  /// Null when the blocklist has never been downloaded.
  final DateTime? syncedAt;

  /// The all-defaults state used before the first native call resolves, and on
  /// platforms with no screening implementation at all (iOS, web, desktop).
  static const ProtectionStatus unavailable = ProtectionStatus(
    callScreeningSupported: false,
    callScreeningRoleHeld: false,
    smsPermissionGranted: false,
    notificationsGranted: false,
    callScreeningEnabled: false,
    smsScreeningEnabled: false,
    blockHighRiskCalls: false,
    flaggedCount: 0,
    flaggedVersion: '',
    syncedAt: null,
  );

  /// True when calls are both switched on and actually able to fire.
  bool get callScreeningActive =>
      callScreeningEnabled && callScreeningRoleHeld && callScreeningSupported;

  /// True when SMS screening is both switched on and actually able to fire.
  bool get smsScreeningActive => smsScreeningEnabled && smsPermissionGranted;

  bool get hasBlocklist => flaggedCount > 0;

  factory ProtectionStatus.fromChannelMap(Map<dynamic, dynamic> map) {
    final int syncedAtMillis = (map['syncedAt'] as num?)?.toInt() ?? 0;
    return ProtectionStatus(
      callScreeningSupported: map['callScreeningSupported'] as bool? ?? false,
      callScreeningRoleHeld: map['callScreeningRoleHeld'] as bool? ?? false,
      smsPermissionGranted: map['smsPermissionGranted'] as bool? ?? false,
      notificationsGranted: map['notificationsGranted'] as bool? ?? false,
      callScreeningEnabled: map['callScreeningEnabled'] as bool? ?? false,
      smsScreeningEnabled: map['smsScreeningEnabled'] as bool? ?? false,
      blockHighRiskCalls: map['blockHighRiskCalls'] as bool? ?? false,
      flaggedCount: (map['flaggedCount'] as num?)?.toInt() ?? 0,
      flaggedVersion: map['flaggedVersion'] as String? ?? '',
      syncedAt: syncedAtMillis == 0 ? null : DateTime.fromMillisecondsSinceEpoch(syncedAtMillis),
    );
  }
}

/// One screening event from the native log.
///
/// Note the absence of a message-body field: the native side records who and
/// why, never what was said (see `ProtectionStore.recordDetection`).
class ScamDetection {
  const ScamDetection({
    required this.type,
    required this.msisdn,
    required this.riskLevel,
    required this.action,
    required this.reportCount,
    required this.topCategory,
    required this.signals,
    required this.detectedAt,
  });

  /// `call` or `sms`.
  final String type;
  final String msisdn;

  /// `high` / `medium` / `low` for a blocklist hit, or `suspicious` when only
  /// the local SMS phrase scan fired.
  final String riskLevel;

  /// `warned` or `blocked`.
  final String action;
  final int reportCount;
  final String topCategory;

  /// Human-readable reasons from the on-device SMS phrase scan; empty for calls.
  final List<String> signals;
  final DateTime detectedAt;

  bool get isCall => type == 'call';
  bool get wasBlocked => action == 'blocked';

  /// True when this fired on message wording alone, with no community reports
  /// behind it — a weaker claim, and the UI labels it as such.
  bool get isHeuristicOnly => reportCount == 0;

  factory ScamDetection.fromJson(Map<String, dynamic> json) {
    return ScamDetection(
      type: json['type'] as String? ?? 'sms',
      msisdn: json['msisdn'] as String? ?? '',
      riskLevel: json['risk_level'] as String? ?? 'suspicious',
      action: json['action'] as String? ?? 'warned',
      reportCount: (json['report_count'] as num?)?.toInt() ?? 0,
      topCategory: json['top_category'] as String? ?? 'unknown',
      signals: (json['signals'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      detectedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['detected_at'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
