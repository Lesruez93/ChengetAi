import 'package:flutter/material.dart';

import '../../core/call_guard.dart';
import '../../core/constants.dart';
import '../../core/country_preference.dart';
import '../../core/models/screened_event.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/country_menu_button.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/screened_event_tile.dart';
import 'widgets/setup_step_tile.dart';
import 'widgets/test_event_card.dart';

/// Incoming call, SMS and WhatsApp screening: setup, status, and history.
///
/// The screen is built around the fact that this feature fails *silently*.
/// A user who has not granted a permission sees exactly what a user with
/// working protection sees: nothing, until a scammer gets through. So the
/// setup state is the top of the screen rather than buried in settings, and
/// the history deliberately lists events that produced no warning — an empty
/// history with screening "on" is the signal that something is wrong.
class CallGuardScreen extends StatefulWidget {
  const CallGuardScreen({super.key});

  @override
  State<CallGuardScreen> createState() => _CallGuardScreenState();
}

class _CallGuardScreenState extends State<CallGuardScreen> with WidgetsBindingObserver {
  CallGuardStatus _status = CallGuardStatus.unsupported;
  List<ScreenedEvent> _history = const <ScreenedEvent>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The role dialog, the SMS prompt and the notification-access screen are
    // all system UI, and none returns a result we can trust. Re-reading on
    // resume is the only reliable way to know what the user actually granted.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final CallGuardStatus status = await CallGuard.status();
    final List<ScreenedEvent> history = await CallGuard.screenedEvents();
    if (!mounted) return;
    setState(() {
      _status = status;
      _history = history;
      _loading = false;
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    final CallGuardStatus status = await CallGuard.setEnabled(enabled);
    if (!mounted) return;
    setState(() => _status = status);
  }

  Future<void> _sendTest(ThreatChannel channel, String sender, String? body) async {
    FocusScope.of(context).unfocus();
    await CallGuard.simulateEvent(channel: channel, sender: sender, body: body);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Screening $sender — the result appears below in a moment.')),
    );

    // Screening runs on a background thread in Kotlin and finishes well under
    // a second against a warm backend. An SMS test makes two calls (lookup +
    // classify), so this allows for both; pull-to-refresh covers the rest.
    await Future<void>.delayed(const Duration(milliseconds: 1800));
    if (mounted) await _refresh();
  }

  Future<void> _clearHistory() async {
    await CallGuard.clearScreenedEvents();
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Call Guard'),
        actions: <Widget>[
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: _clearHistory,
              icon: const Icon(Icons.delete_outline),
            ),
          const CountryMenuButton(),
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
                    if (!_status.isSupported)
                      const _UnsupportedNotice()
                    else ...<Widget>[
                      _StatusBanner(status: _status),
                      const SizedBox(height: 16),
                      _SetupSection(
                        status: _status,
                        onChanged: _refresh,
                        onToggle: _setEnabled,
                      ),
                      const SizedBox(height: 20),
                      TestEventCard(onSend: _sendTest),
                      const SizedBox(height: 24),
                      Text(
                        'Screened events',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Every call and message Call Guard checked, including the ones it '
                        'let through quietly. If this stays empty while calls and texts come '
                        'in, screening is not running.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      if (_history.isEmpty)
                        const EmptyState(
                          icon: Icons.shield_outlined,
                          message: 'Nothing screened yet. Send a test above to check the '
                              'whole path end to end.',
                        )
                      else
                        ..._history.map(
                          (ScreenedEvent event) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ScreenedEventTile(event: event),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

/// Shown on iOS and on Android below 10, where the role cannot be requested.
class _UnsupportedNotice extends StatelessWidget {
  const _UnsupportedNotice();

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
                const Icon(Icons.info_outline, color: AppColors.neutral),
                const SizedBox(width: 8),
                Text(
                  'Not available on this device',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Call Guard needs Android 10 or newer. On iPhone, Apple does not let any '
              'app see an incoming caller\'s number or read your texts, so live '
              'screening is not possible there at all.',
              style: TextStyle(color: Colors.grey.shade800, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'You can still check a number on the Lookup tab, or paste a message into '
              'the Check tab.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-glance answer to "am I protected right now?".
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final CallGuardStatus status;

  @override
  Widget build(BuildContext context) {
    final bool active = status.isFullyActive;
    final Color color = active ? AppColors.safe : AppColors.warning;
    final int live = status.activeChannelCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        children: <Widget>[
          Icon(active ? Icons.verified_user : Icons.gpp_maybe, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  active
                      ? 'Call Guard is on · $live of 3 channels'
                      : 'Call Guard is not protecting you yet',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  active
                      ? 'Incoming calls and messages are checked against reported scam '
                          'numbers as they arrive.'
                      : 'Finish the steps below. Until then, calls and texts arrive '
                          'unchecked.',
                  style: TextStyle(color: Colors.grey.shade800, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupSection extends StatelessWidget {
  const _SetupSection({
    required this.status,
    required this.onChanged,
    required this.onToggle,
  });

  final CallGuardStatus status;
  final Future<void> Function() onChanged;
  final Future<void> Function(bool) onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Setup',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(
          'Each channel is separate — you can turn on only the ones you want.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ),
        const SizedBox(height: 12),
        SetupStepTile(
          done: status.hasNotificationPermission,
          title: 'Allow warning notifications',
          description: status.hasNotificationPermission
              ? 'Warnings can appear while a call rings or a text arrives.'
              : 'Needed by every channel. Without it a scam is detected but you are never '
                  'told — the worst possible failure for this feature.',
          actionLabel: 'Allow',
          onAction: () async {
            await CallGuard.requestNotificationPermission();
            await onChanged();
          },
        ),
        const SizedBox(height: 10),
        SetupStepTile(
          done: status.hasRole,
          title: 'Screen phone calls',
          description: status.hasRole
              ? 'ChengetAI is your call screening app.'
              : 'Android asks you to confirm this once. ChengetAI never blocks or answers '
                  'a call — it only checks the number and warns you.',
          actionLabel: 'Turn on',
          onAction: () async {
            await CallGuard.requestRole();
            await onChanged();
          },
        ),
        const SizedBox(height: 10),
        SetupStepTile(
          done: status.hasSmsPermission,
          title: 'Screen text messages',
          description: status.hasSmsPermission
              ? 'Incoming texts are checked by sender and by what they say.'
              : 'Checks both who sent a text and whether it reads like a known scam. '
                  'ChengetAI never reads your stored messages and never keeps the text.',
          actionLabel: 'Allow',
          onAction: () async {
            await CallGuard.requestSmsPermission();
            await onChanged();
          },
        ),
        const SizedBox(height: 10),
        SetupStepTile(
          done: status.hasWhatsAppAccess,
          title: 'Screen WhatsApp calls (limited)',
          description: status.hasWhatsAppAccess
              ? 'WhatsApp calls from numbers not in your contacts are checked. Calls from '
                  'saved contacts show only a name, which cannot be looked up.'
              : 'WhatsApp calls do not go through Android\'s call screening, so this reads '
                  'WhatsApp\'s own call notification instead. It only works for callers not '
                  'in your contacts, and may stop working when WhatsApp updates.',
          actionLabel: 'Open settings',
          onAction: () async {
            await CallGuard.openNotificationAccessSettings();
            await onChanged();
          },
        ),
        const SizedBox(height: 10),
        SetupStepTile(
          done: status.isEnabled,
          title: 'Warnings switched on',
          description: status.isEnabled
              ? 'Call Guard will warn you about flagged senders.'
              : 'Screening is set up but paused. No warnings will be shown.',
          actionLabel: status.isEnabled ? 'Pause' : 'Resume',
          onAction: () => onToggle(!status.isEnabled),
          isDestructiveAction: status.isEnabled,
        ),
      ],
    );
  }
}
