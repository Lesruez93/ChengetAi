import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models/classify_models.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/report_sheet.dart';
import '../../shared/widgets/verdict_card.dart';

/// "Check a message" — paste (or, in future, share-into-app) SMS/WhatsApp
/// text, classify it via `POST /classify`, and show a VerdictCard.
///
/// Receiving OS-level share-intents (so a user can share a suspicious SMS
/// directly from their messaging app) is a natural extension but needs a
/// platform channel / `receive_sharing_intent`-style plugin and Android
/// manifest intent-filter wiring that belongs in the (not-yet-scaffolded)
/// android/ folder — out of scope for this MVP pass. The paste flow below
/// covers the same use case manually.
class CheckMessageScreen extends StatefulWidget {
  const CheckMessageScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<CheckMessageScreen> createState() => _CheckMessageScreenState();
}

class _CheckMessageScreenState extends State<CheckMessageScreen> {
  final TextEditingController _textController = TextEditingController();
  ClassifyResponse? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _checkMessage() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final ClassifyResponse response = await widget.apiClient.classify(text);
      setState(() => _result = response);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openReportSheet() {
    ReportSheet.show(
      context,
      apiClient: widget.apiClient,
      initialCategory: _result?.matchedCategory,
      initialMessageExcerpt: _textController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Check a Message')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Paste a suspicious SMS, WhatsApp, or email message below.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 6,
              minLines: 4,
              maxLength: 4000,
              decoration: const InputDecoration(
                hintText: 'e.g. "Confirmed. You have received \$80 into your EcoCash '
                    'account... please reverse the money to this number..."',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _checkMessage,
                icon: _loading
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.fact_check_outlined),
                label: Text(_loading ? 'Checking...' : 'Check Message'),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                message: 'Could not check this message.\n$_error',
                actionLabel: 'Retry',
                onAction: _checkMessage,
              )
            else if (_result != null) ...<Widget>[
              VerdictCard(result: _result!, sourceText: _textController.text),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openReportSheet,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report the Sender\'s Number'),
              ),
            ] else
              const EmptyState(
                icon: Icons.shield_outlined,
                message: 'No message checked yet. Paste a message above and tap '
                    '"Check Message" to see if it looks like a scam.',
              ),
          ],
        ),
      ),
    );
  }
}
