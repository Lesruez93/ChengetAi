import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/country_preference.dart';
import '../../../core/models/screened_event.dart';
import '../../../core/theme.dart';

/// Drives a sender through the real screening pipeline without real traffic.
///
/// Testing this feature for real needs a second handset and a scammer willing
/// to cooperate. Everything that actually breaks in the field — the base URL,
/// country resolution, the notification permission, the warning threshold —
/// is reachable without either, so this card exists to exercise all of it.
class TestEventCard extends StatefulWidget {
  const TestEventCard({required this.onSend, super.key});

  final Future<void> Function(ThreatChannel channel, String sender, String? body) onSend;

  @override
  State<TestEventCard> createState() => _TestEventCardState();
}

class _TestEventCardState extends State<TestEventCard> {
  final TextEditingController _senderController = TextEditingController();
  final TextEditingController _bodyController = TextEditingController();
  ThreatChannel _channel = ThreatChannel.call;

  @override
  void dispose() {
    _senderController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _send() {
    final String sender = _senderController.text.trim();
    if (sender.isEmpty) return;
    widget.onSend(
      _channel,
      sender,
      _channel == ThreatChannel.sms ? _bodyController.text.trim() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isSms = _channel == ThreatChannel.sms;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.science_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Send a test',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Runs the real screening path — same lookup, same classifier, same warning '
              'notification — without needing a second phone.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13, height: 1.35),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThreatChannel>(
              segments: const <ButtonSegment<ThreatChannel>>[
                ButtonSegment<ThreatChannel>(
                  value: ThreatChannel.call,
                  label: Text('Call'),
                  icon: Icon(Icons.phone_outlined, size: 16),
                ),
                ButtonSegment<ThreatChannel>(
                  value: ThreatChannel.sms,
                  label: Text('SMS'),
                  icon: Icon(Icons.sms_outlined, size: 16),
                ),
                ButtonSegment<ThreatChannel>(
                  value: ThreatChannel.whatsappCall,
                  label: Text('WhatsApp'),
                  icon: Icon(Icons.chat_outlined, size: 16),
                ),
              ],
              selected: <ThreatChannel>{_channel},
              onSelectionChanged: (Set<ThreatChannel> selection) {
                setState(() => _channel = selection.first);
              },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: CountryPreference.codeNotifier,
              builder: (BuildContext context, String _, __) => Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _senderController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Sender',
                        hintText: CountryPreference.profile.exampleMsisdn,
                        prefixIcon: const Icon(Icons.phone_forwarded_outlined),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _send,
                    child: const Icon(Icons.play_arrow),
                  ),
                ],
              ),
            ),
            if (isSms) ...<Widget>[
              const SizedBox(height: 10),
              TextField(
                controller: _bodyController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message text',
                  hintText: 'Wrong deposit, please reverse to this number urgently',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'An SMS is checked twice — the sender against reported numbers, and the '
                'text against the classifier. Either one can trigger the warning, so a '
                'clean sender with a scam script still gets caught.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.3),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: kCallGuardTestNumbers
                  .map(
                    (CallGuardTestNumber sample) => ActionChip(
                      avatar: Icon(
                        sample.expectsWarning ? Icons.warning_amber : Icons.check_circle_outline,
                        size: 16,
                        color: sample.expectsWarning ? AppColors.danger : AppColors.safe,
                      ),
                      label: Text(sample.label),
                      onPressed: () => _senderController.text = sample.msisdn,
                    ),
                  )
                  .toList(),
            ),
            if (isSms) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCallGuardTestMessages
                    .map(
                      (CallGuardTestMessage sample) => ActionChip(
                        avatar: Icon(
                          sample.expectsWarning
                              ? Icons.warning_amber
                              : Icons.check_circle_outline,
                          size: 16,
                          color: sample.expectsWarning ? AppColors.danger : AppColors.safe,
                        ),
                        label: Text(sample.label),
                        onPressed: () => _bodyController.text = sample.text,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
