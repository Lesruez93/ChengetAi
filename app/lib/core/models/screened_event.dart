/// Models for the Call Guard screen, mirroring `ScreenedEvent` and the
/// `status` map in
/// `android/app/src/main/kotlin/com/chengetai/chengetai/callguard/`.
library;

/// Where a screened threat arrived from.
enum ThreatChannel {
  call,
  sms,
  whatsappCall;

  static ThreatChannel fromKey(String key) => switch (key) {
        'sms' => ThreatChannel.sms,
        'whatsapp_call' => ThreatChannel.whatsappCall,
        _ => ThreatChannel.call,
      };

  String get key => switch (this) {
        ThreatChannel.call => 'call',
        ThreatChannel.sms => 'sms',
        ThreatChannel.whatsappCall => 'whatsapp_call',
      };

  String get label => switch (this) {
        ThreatChannel.call => 'Call',
        ThreatChannel.sms => 'SMS',
        ThreatChannel.whatsappCall => 'WhatsApp',
      };
}

/// Why a screened event did or did not produce a warning.
///
/// Kept as an enum rather than a raw string so a new outcome added on the
/// Android side has to be handled here explicitly instead of rendering as a
/// blank row.
enum ScreeningOutcome {
  /// Flagged, and the warning was shown.
  warned,

  /// Flagged, but the warning could not be posted — notifications are off.
  /// The single most confusing state for a user, so it is surfaced loudly.
  flaggedNotificationBlocked,

  /// Checked successfully and nothing was flagged.
  clean,

  /// The backend could not parse the sender — a short code, a withheld
  /// number, or a market the product does not cover.
  notAMobileNumber,

  /// A WhatsApp call from a saved contact, where WhatsApp shows only a name.
  /// There is no number to look up, so no verdict is possible.
  noNumberAvailable,

  /// The lookup itself failed (offline, backend down, wrong base URL).
  lookupFailed,

  /// Screening is set up but the user turned it off.
  skippedDisabled,

  /// An outcome from a newer Android build than this Dart code knows about.
  unknown;

  static ScreeningOutcome fromKey(String key) {
    return switch (key) {
      'warned' => ScreeningOutcome.warned,
      'flagged_notification_blocked' => ScreeningOutcome.flaggedNotificationBlocked,
      'clean' => ScreeningOutcome.clean,
      'not_a_mobile_number' => ScreeningOutcome.notAMobileNumber,
      'no_number_available' => ScreeningOutcome.noNumberAvailable,
      'lookup_failed' => ScreeningOutcome.lookupFailed,
      'skipped_disabled' => ScreeningOutcome.skippedDisabled,
      _ => ScreeningOutcome.unknown,
    };
  }

  String get label => switch (this) {
        ScreeningOutcome.warned => 'Warned',
        ScreeningOutcome.flaggedNotificationBlocked => 'Flagged — warning blocked',
        ScreeningOutcome.clean => 'Not flagged',
        ScreeningOutcome.notAMobileNumber => 'Not checkable',
        ScreeningOutcome.noNumberAvailable => 'No number shown',
        ScreeningOutcome.lookupFailed => "Couldn't check",
        ScreeningOutcome.skippedDisabled => 'Screening off',
        ScreeningOutcome.unknown => 'Unknown',
      };

  String get explanation => switch (this) {
        ScreeningOutcome.warned => 'This sender is flagged, and you were warned.',
        ScreeningOutcome.flaggedNotificationBlocked =>
          'This sender is flagged but no warning could be shown — turn on notifications.',
        ScreeningOutcome.clean => 'Nothing flagged against this sender or message.',
        ScreeningOutcome.notAMobileNumber =>
          'Not a mobile number we can check — a short code, a withheld number, or an unsupported market.',
        ScreeningOutcome.noNumberAvailable =>
          'WhatsApp showed a saved contact name instead of a number, so there was nothing to look up.',
        ScreeningOutcome.lookupFailed =>
          'The check did not complete. Usually no connection at the time.',
        ScreeningOutcome.skippedDisabled => 'Call Guard was switched off at the time.',
        ScreeningOutcome.unknown => 'Unrecognised result.',
      };
}

/// One entry in the Call Guard history.
class ScreenedEvent {
  const ScreenedEvent({
    required this.channel,
    required this.sender,
    required this.screenedAt,
    required this.outcome,
    required this.wasWarned,
    required this.wasSimulated,
    this.riskLevel,
    this.reportCount,
    this.topCategory,
    this.messageVerdict,
  });

  final ThreatChannel channel;

  /// The calling number, SMS sender ID, or WhatsApp display name.
  final String sender;

  final DateTime screenedAt;
  final ScreeningOutcome outcome;
  final bool wasWarned;

  /// True for events injected by the "Send a test" button rather than
  /// received from the network.
  final bool wasSimulated;

  /// Null unless the sender lookup succeeded.
  final String? riskLevel;
  final int? reportCount;
  final String? topCategory;

  /// The classifier's read on an SMS body: `scam`, `suspicious` or `safe`.
  /// Null for channels that carry no message.
  final String? messageVerdict;

  factory ScreenedEvent.fromJson(Map<String, dynamic> json) {
    return ScreenedEvent(
      channel: ThreatChannel.fromKey(json['channel'] as String? ?? 'call'),
      sender: json['sender'] as String? ?? '',
      screenedAt: DateTime.fromMillisecondsSinceEpoch(
        (json['screened_at_millis'] as num?)?.toInt() ?? 0,
      ),
      outcome: ScreeningOutcome.fromKey(json['outcome'] as String? ?? ''),
      wasWarned: json['was_warned'] as bool? ?? false,
      wasSimulated: json['was_simulated'] as bool? ?? false,
      riskLevel: json['risk_level'] as String?,
      reportCount: (json['report_count'] as num?)?.toInt(),
      topCategory: json['top_category'] as String?,
      messageVerdict: json['message_verdict'] as String?,
    );
  }
}

/// Whether Call Guard can run, and what is still missing if it can't.
///
/// The three channels are independently gated: someone can have call
/// screening working while SMS is denied. [isFullyActive] deliberately does
/// not require WhatsApp access, which is a best-effort supplement rather than
/// a peer — see `WhatsAppCallListener` for why.
class CallGuardStatus {
  const CallGuardStatus({
    required this.isSupported,
    required this.hasRole,
    required this.hasSmsPermission,
    required this.hasWhatsAppAccess,
    required this.isEnabled,
    required this.hasNotificationPermission,
  });

  /// False on iOS, and on Android below 10 where the role cannot be requested.
  final bool isSupported;

  /// Whether the user has made ChengetAI their call screening app.
  final bool hasRole;

  final bool hasSmsPermission;

  /// Notification access, the only route to WhatsApp calls.
  final bool hasWhatsAppAccess;

  /// The in-app toggle, independent of the OS permissions.
  final bool isEnabled;

  final bool hasNotificationPermission;

  /// True when at least one channel is screening and warnings can be shown.
  /// Notifications are the shared prerequisite: without them every channel
  /// detects silently, which is the same as not running.
  bool get isFullyActive =>
      isSupported &&
      isEnabled &&
      hasNotificationPermission &&
      (hasRole || hasSmsPermission || hasWhatsAppAccess);

  /// How many of the three channels are actually live.
  int get activeChannelCount =>
      (hasRole ? 1 : 0) + (hasSmsPermission ? 1 : 0) + (hasWhatsAppAccess ? 1 : 0);

  static const CallGuardStatus unsupported = CallGuardStatus(
    isSupported: false,
    hasRole: false,
    hasSmsPermission: false,
    hasWhatsAppAccess: false,
    isEnabled: false,
    hasNotificationPermission: false,
  );

  factory CallGuardStatus.fromMap(Map<dynamic, dynamic> map) {
    return CallGuardStatus(
      isSupported: map['isSupported'] as bool? ?? false,
      hasRole: map['hasRole'] as bool? ?? false,
      hasSmsPermission: map['hasSmsPermission'] as bool? ?? false,
      hasWhatsAppAccess: map['hasWhatsAppAccess'] as bool? ?? false,
      isEnabled: map['isEnabled'] as bool? ?? false,
      hasNotificationPermission: map['hasNotificationPermission'] as bool? ?? false,
    );
  }
}
