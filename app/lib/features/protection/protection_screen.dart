import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/models/protection_models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/risk_chip.dart';
import '../../shared/widgets/stat_tile.dart';
import 'protection_service.dart';

/// Live protection: screen incoming calls and SMS against the community
/// blocklist, on the device.
///
/// The screen's job is as much disclosure as configuration. Screening reads the
/// user's incoming calls and messages, so each toggle states plainly what it
/// turns on, what leaves the phone (nothing but the blocklist download), and
/// what it will miss.
class ProtectionScreen extends StatefulWidget {
  const ProtectionScreen({required this.apiClient, super.key, this.service});

  final ApiClient apiClient;

  /// Injectable for tests; defaults to the real MethodChannel-backed service.
  final ProtectionService? service;

  @override
  State<ProtectionScreen> createState() => _ProtectionScreenState();
}

class _ProtectionScreenState extends State<ProtectionScreen> {
  late final ProtectionService _service = widget.service ?? ProtectionService();

  ProtectionStatus _status = ProtectionStatus.unavailable;
  List<ScamDetection> _detections = <ScamDetection>[];
  bool _loading = true;
  bool _syncing = false;
  String? _syncError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final ProtectionStatus status = await _service.getStatus();
    final List<ScamDetection> detections = await _service.getDetections();
    if (!mounted) return;
    setState(() {
      _status = status;
      _detections = detections;
      _loading = false;
    });
    await _autoSyncIfStale();
  }

  /// Refreshes the blocklist in the background when it is missing or a day old.
  ///
  /// This screen is built (inside the home shell's [IndexedStack]) at app
  /// launch whether or not the user opens the tab, so in practice this is the
  /// "sync on startup" path. Without it a user who switches screening on once
  /// would keep matching against a frozen list forever — protection that
  /// silently decays is the failure mode most worth designing out.
  ///
  /// There is deliberately no background service: a scheduled job would need
  /// the app to wake on its own, and the honest trade is that the list updates
  /// when the app is opened, with the last-updated time shown on this screen.
  Future<void> _autoSyncIfStale() async {
    if (!_status.callScreeningActive && !_status.smsScreeningActive) return;

    final DateTime? syncedAt = _status.syncedAt;
    final bool stale =
        syncedAt == null || DateTime.now().difference(syncedAt) > const Duration(days: 1);
    if (!stale) return;

    await _sync();
  }

  void _apply(ProtectionStatus status) {
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _sync() async {
    setState(() {
      _syncing = true;
      _syncError = null;
    });
    try {
      final ProtectionStatus status = await _service.syncBlocklist(widget.apiClient);
      if (!mounted) return;
      setState(() => _status = status);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _syncError = e.message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Turning a feature on has to walk the user through the permission it needs;
  /// turning it off is unconditional. Permissions are never requested up front
  /// on first launch — only at the moment the user asks for the feature.
  Future<void> _toggleCallScreening(bool enabled) async {
    if (!enabled) {
      _apply(await _service.setCallScreeningEnabled(false));
      return;
    }

    ProtectionStatus status = _status;
    if (!status.callScreeningRoleHeld) {
      status = await _service.requestCallScreeningRole();
      if (!status.callScreeningRoleHeld) {
        _apply(status);
        _toast('ChengetAI needs the call-screening role to warn you about calls.');
        return;
      }
    }
    status = await _service.setCallScreeningEnabled(true);
    _apply(await _ensureNotifications(status));
    await _syncIfBlocklistEmpty();
  }

  Future<void> _toggleSmsScreening(bool enabled) async {
    if (!enabled) {
      _apply(await _service.setSmsScreeningEnabled(false));
      return;
    }

    ProtectionStatus status = _status;
    if (!status.smsPermissionGranted) {
      status = await _service.requestSmsPermission();
      if (!status.smsPermissionGranted) {
        _apply(status);
        _toast('Without SMS permission, ChengetAI cannot check incoming messages.');
        return;
      }
    }
    status = await _service.setSmsScreeningEnabled(true);
    _apply(await _ensureNotifications(status));
    await _syncIfBlocklistEmpty();
  }

  /// Screening with notifications denied runs but stays silent, which looks
  /// identical to it being broken — so ask once, right after the feature is
  /// switched on.
  Future<ProtectionStatus> _ensureNotifications(ProtectionStatus status) async {
    if (status.notificationsGranted) return status;
    return _service.requestNotificationPermission();
  }

  Future<void> _syncIfBlocklistEmpty() async {
    if (!_status.hasBlocklist) await _sync();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _clearHistory() async {
    await _service.clearDetections();
    if (!mounted) return;
    setState(() => _detections = <ScamDetection>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Live Protection'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Update blocklist',
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    if (!ProtectionService.isSupportedPlatform)
                      const _UnsupportedPlatformCard()
                    else ...<Widget>[
                      _StatusBanner(status: _status),
                      const SizedBox(height: 14),
                      _BlocklistCard(
                        status: _status,
                        syncing: _syncing,
                        error: _syncError,
                        onSync: _sync,
                      ),
                      const SizedBox(height: 14),
                      _ToggleCard(
                        status: _status,
                        onToggleCalls: _toggleCallScreening,
                        onToggleSms: _toggleSmsScreening,
                        onToggleBlockHighRisk: (bool v) async =>
                            _apply(await _service.setBlockHighRiskCalls(v)),
                      ),
                      const SizedBox(height: 14),
                      const _PrivacyCard(),
                      const SizedBox(height: 14),
                      _DetectionHistory(detections: _detections, onClear: _clearHistory),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// One-line answer to "am I protected right now?", with the specific gap named
/// when the answer is no.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final ProtectionStatus status;

  @override
  Widget build(BuildContext context) {
    final bool anyActive = status.callScreeningActive || status.smsScreeningActive;
    final bool bothActive = status.callScreeningActive && status.smsScreeningActive;

    final String message;
    final Color color;
    final IconData icon;

    if (bothActive && status.hasBlocklist) {
      message = 'Calls and messages are being screened against '
          '${status.flaggedCount} reported numbers.';
      color = AppColors.safe;
      icon = Icons.verified_user;
    } else if (anyActive && !status.hasBlocklist) {
      message = 'Screening is on, but the blocklist is empty — tap sync to download it.';
      color = AppColors.warning;
      icon = Icons.cloud_download_outlined;
    } else if (anyActive) {
      message = status.callScreeningActive
          ? 'Calls are screened. Message screening is off.'
          : 'Messages are screened. Call screening is off.';
      color = AppColors.warning;
      icon = Icons.shield_outlined;
    } else {
      message = 'Live protection is off. Nothing is being screened.';
      color = AppColors.neutral;
      icon = Icons.shield_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlocklistCard extends StatelessWidget {
  const _BlocklistCard({
    required this.status,
    required this.syncing,
    required this.error,
    required this.onSync,
  });

  final ProtectionStatus status;
  final bool syncing;
  final String? error;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    final DateTime? syncedAt = status.syncedAt;
    final String syncedLabel = syncedAt == null
        ? 'Never downloaded'
        : 'Updated ${DateFormat('d MMM, HH:mm').format(syncedAt.toLocal())}';

    // Anything older than a day is worth flagging: a stale list quietly stops
    // catching newly-reported numbers while still looking like it works.
    final bool stale =
        syncedAt != null && DateTime.now().difference(syncedAt) > const Duration(days: 1);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Blocklist', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Reported numbers stored on this phone. Screening matches against this '
              'copy, so it keeps working with no signal.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                StatTile(
                  value: '${status.flaggedCount}',
                  label: 'numbers',
                  icon: Icons.block,
                  dense: true,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    syncedLabel,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: stale ? AppColors.warning : Colors.grey.shade600,
                      fontWeight: stale ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
            if (stale) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'This list is over a day old. Numbers reported since then will not be caught.',
                style: TextStyle(fontSize: 12.5, color: AppColors.warning),
              ),
            ],
            if (error != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'Could not update: $error',
                style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: syncing ? null : onSync,
              icon: const Icon(Icons.sync, size: 18),
              label: Text(syncing ? 'Updating…' : 'Update now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  const _ToggleCard({
    required this.status,
    required this.onToggleCalls,
    required this.onToggleSms,
    required this.onToggleBlockHighRisk,
  });

  final ProtectionStatus status;
  final ValueChanged<bool> onToggleCalls;
  final ValueChanged<bool> onToggleSms;
  final ValueChanged<bool> onToggleBlockHighRisk;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: <Widget>[
            SwitchListTile(
              value: status.callScreeningEnabled,
              onChanged: status.callScreeningSupported ? onToggleCalls : null,
              title: const Text('Screen incoming calls'),
              subtitle: Text(
                status.callScreeningSupported
                    ? 'Warns you while the phone is ringing if the caller has been '
                        'reported. ChengetAI never reads your call history.'
                    : 'Not available on this device — call screening needs Android 10 or newer.',
                style: const TextStyle(fontSize: 12.5),
              ),
              secondary: const Icon(Icons.phone_in_talk_outlined),
            ),
            if (status.callScreeningEnabled && !status.callScreeningRoleHeld)
              const _GapNotice(
                message: 'Android has not granted the call-screening role, so calls are '
                    'not being checked. Switch this off and on again to re-request it.',
              ),
            if (status.callScreeningActive)
              SwitchListTile(
                value: status.blockHighRiskCalls,
                onChanged: onToggleBlockHighRisk,
                title: const Text('Reject high-risk calls automatically'),
                subtitle: const Text(
                  'Hangs up on numbers with the most reports instead of just warning you. '
                  'Blocked calls still appear in your call log.',
                  style: TextStyle(fontSize: 12.5),
                ),
                secondary: const Icon(Icons.phone_disabled_outlined),
              ),
            const Divider(height: 1),
            SwitchListTile(
              value: status.smsScreeningEnabled,
              onChanged: onToggleSms,
              title: const Text('Screen incoming messages'),
              subtitle: const Text(
                'Checks the sender against the blocklist and scans the text for known '
                'scam wording, on this phone. Messages are not uploaded and not hidden '
                'from your messaging app.',
                style: TextStyle(fontSize: 12.5),
              ),
              secondary: const Icon(Icons.sms_outlined),
            ),
            if (status.smsScreeningEnabled && !status.smsPermissionGranted)
              const _GapNotice(
                message: 'SMS permission is denied, so messages are not being checked. '
                    'Grant it in Settings → Apps → ChengetAI → Permissions.',
              ),
            if ((status.callScreeningEnabled || status.smsScreeningEnabled) &&
                !status.notificationsGranted)
              const _GapNotice(
                message: 'Notifications are blocked, so warnings cannot be shown. '
                    'Detections will still be listed below.',
              ),
          ],
        ),
      ),
    );
  }
}

/// An inline "this is switched on but cannot actually run" warning. Kept
/// visually distinct from the toggle itself, because the two states are
/// genuinely different and collapsing them would hide a silent failure.
class _GapNotice extends StatelessWidget {
  const _GapNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.lock_outline, size: 18, color: AppColors.brandPrimary),
                const SizedBox(width: 8),
                Text(
                  'What leaves your phone',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _PrivacyPoint(
              icon: Icons.download_outlined,
              text: 'ChengetAI downloads the list of reported numbers to your phone and '
                  'checks calls and messages against that copy here.',
            ),
            const _PrivacyPoint(
              icon: Icons.cloud_off_outlined,
              text: 'Who calls or messages you is never sent to our servers. Message text '
                  'is only uploaded when you paste it in yourself to be checked.',
            ),
            const _PrivacyPoint(
              icon: Icons.visibility_off_outlined,
              text: 'The history below records the number and the reason, never the '
                  'contents of a message.',
            ),
            const SizedBox(height: 6),
            Text(
              'Message scanning uses a short keyword list on the device, not the full '
              'AI classifier — it will miss scams worded in new ways. For anything you '
              'are unsure about, check the message on the Check tab.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyPoint extends StatelessWidget {
  const _PrivacyPoint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }
}

class _DetectionHistory extends StatelessWidget {
  const _DetectionHistory({required this.detections, required this.onClear});

  final List<ScamDetection> detections;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Recent detections',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (detections.isNotEmpty)
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            if (detections.isEmpty)
              const EmptyState(
                icon: Icons.shield_outlined,
                message: 'Nothing flagged yet. Calls and messages you are warned about '
                    'will be listed here.',
              )
            else
              ...detections.map((ScamDetection d) => _DetectionTile(detection: d)),
          ],
        ),
      ),
    );
  }
}

class _DetectionTile extends StatelessWidget {
  const _DetectionTile({required this.detection});

  final ScamDetection detection;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forRiskLevel(detection.riskLevel);
    final String when = DateFormat('d MMM, HH:mm').format(detection.detectedAt.toLocal());

    final String subtitle = detection.isHeuristicOnly
        ? 'Message wording looked like a scam — this number has no community reports.'
        : 'Reported ${detection.reportCount} '
            '${detection.reportCount == 1 ? 'time' : 'times'} for '
            '${humanizeCategory(detection.topCategory)}.';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withOpacity(0.12),
            child: Icon(
              detection.isCall ? Icons.phone_in_talk_outlined : Icons.sms_outlined,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        detection.msisdn,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                    ),
                    Text(when, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                  ],
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700)),
                if (detection.wasBlocked || detection.signals.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      if (detection.wasBlocked)
                        const RiskChip(
                          label: 'Call rejected',
                          icon: Icons.phone_disabled_outlined,
                          color: AppColors.danger,
                        ),
                      ...detection.signals.map(
                        (String s) => RiskChip(label: s, color: AppColors.warning),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnsupportedPlatformCard extends StatelessWidget {
  const _UnsupportedPlatformCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Live protection is Android-only',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'iOS does not let apps see incoming SMS, and only allows call blocking '
              'from a pre-loaded list with no way to explain why a number was blocked. '
              'Number lookup and message checking work on every platform.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
