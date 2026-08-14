import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/models/analyze_models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/report_sheet.dart';
import '../../shared/widgets/risk_chip.dart';
import '../../shared/widgets/verdict_card.dart';

/// "Check anything" — one text box that takes whatever the user has in their
/// clipboard and runs `POST /analyze` over it.
///
/// This replaces the older message-only check screen. Asking a worried user to
/// first decide whether the thing in their hand is "a message", "a link" or "a
/// number", and to find the matching tab, is a question they cannot reliably
/// answer about content designed to be confusing — and most scam texts are all
/// three at once. The backend splits the paste and routes each part to the
/// right checker instead.
class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  final TextEditingController _textController = TextEditingController();
  AnalyzeResponse? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _analyze() async {
    final String text = _textController.text.trim();
    if (text.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final AnalyzeResponse response = await widget.apiClient.analyze(text);
      if (!mounted) return;
      setState(() => _result = response);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    final String? text = data?.text;
    if (text == null || text.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Your clipboard is empty.')));
      return;
    }
    _textController.text = text;
    await _analyze();
  }

  void _clear() {
    _textController.clear();
    setState(() {
      _result = null;
      _error = null;
    });
  }

  /// Pre-fills the report form with whatever the analysis already worked out:
  /// the riskiest number found, and the classifier's category guess.
  void _openReportSheet({String? msisdn}) {
    final AnalyzeResponse? result = _result;
    ReportSheet.show(
      context,
      apiClient: widget.apiClient,
      initialMsisdn: msisdn ?? _worstNumber(result)?.msisdn,
      initialCategory: result?.message?.matchedCategory,
      initialMessageExcerpt: _textController.text.trim(),
    );
  }

  static NumberFinding? _worstNumber(AnalyzeResponse? result) {
    if (result == null || result.numbers.isEmpty) return null;
    const Map<String, int> order = <String, int>{'high': 3, 'medium': 2, 'low': 1, 'unknown': 0};
    final List<NumberFinding> sorted = List<NumberFinding>.from(result.numbers)
      ..sort((NumberFinding a, NumberFinding b) =>
          (order[b.riskLevel] ?? 0).compareTo(order[a.riskLevel] ?? 0));
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final AnalyzeResponse? result = _result;

    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Check Anything'),
        actions: <Widget>[
          if (_textController.text.isNotEmpty || result != null)
            IconButton(
              tooltip: 'Clear',
              onPressed: _clear,
              icon: const Icon(Icons.close),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Paste anything you are unsure about — a message, a link, a phone number, '
              'or all of it together. ChengetAI checks each part.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 8,
              minLines: 4,
              maxLength: 8000,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (_) => setState(() {}), // keeps the clear button in sync
              decoration: const InputDecoration(
                hintText: 'e.g. "Confirmed. You have received \$80 into your EcoCash '
                    'account. Kana isiri yako reverse to 0771234567" — or just paste a link.',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _analyze,
                    icon: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.fact_check_outlined),
                    label: Text(_loading ? 'Checking…' : 'Check it'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste, size: 18),
                  label: const Text('Paste'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                message: 'Could not check this.\n$_error',
                actionLabel: 'Retry',
                onAction: _analyze,
              )
            else if (result != null)
              ..._buildResult(result)
            else
              const EmptyState(
                icon: Icons.shield_outlined,
                message: 'Nothing checked yet. Paste a message, link or number above '
                    'and tap "Check it".',
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildResult(AnalyzeResponse result) {
    return <Widget>[
      _OverallVerdictCard(result: result),
      if (result.numbers.isNotEmpty) ...<Widget>[
        const SizedBox(height: 14),
        _SectionHeader(
          icon: Icons.phone_outlined,
          title: 'Phone numbers (${result.numbers.length})',
        ),
        const SizedBox(height: 8),
        ...result.numbers.map(
          (NumberFinding n) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _NumberFindingCard(
              finding: n,
              onReport: () => _openReportSheet(msisdn: n.msisdn),
            ),
          ),
        ),
      ],
      if (result.links.isNotEmpty) ...<Widget>[
        const SizedBox(height: 14),
        _SectionHeader(icon: Icons.link, title: 'Links (${result.links.length})'),
        const SizedBox(height: 8),
        ...result.links.map(
          (LinkFinding l) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _LinkFindingCard(finding: l),
          ),
        ),
      ],
      if (result.unrecognizedNumbers.isNotEmpty) ...<Widget>[
        const SizedBox(height: 14),
        _UnrecognizedNumbersCard(numbers: result.unrecognizedNumbers),
      ],
      if (result.message != null) ...<Widget>[
        const SizedBox(height: 14),
        const _SectionHeader(icon: Icons.chat_bubble_outline, title: 'Message wording'),
        const SizedBox(height: 8),
        VerdictCard(result: result.message!, sourceText: _textController.text),
      ],
      const SizedBox(height: 14),
      Text(
        result.methodNote,
        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600, height: 1.4),
      ),
      const SizedBox(height: 14),
      OutlinedButton.icon(
        onPressed: () => _openReportSheet(),
        icon: const Icon(Icons.flag_outlined),
        label: const Text('Report this to the community'),
      ),
    ];
  }
}

/// The single answer, above the evidence.
class _OverallVerdictCard extends StatelessWidget {
  const _OverallVerdictCard({required this.result});

  final AnalyzeResponse result;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forVerdict(result.verdict);
    final int confidencePct = (result.confidence * 100).round();

    final String label = switch (result.verdict) {
      'scam' => 'Likely a scam',
      'suspicious' => 'Treat with caution',
      'safe' => 'Nothing flagged',
      _ => result.verdict,
    };

    final IconData icon = switch (result.verdict) {
      'scam' => Icons.gpp_bad_outlined,
      'suspicious' => Icons.warning_amber_outlined,
      'safe' => Icons.verified_outlined,
      _ => Icons.help_outline,
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: double.infinity,
            color: color.withOpacity(0.10),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  child: Icon(icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$confidencePct% confidence',
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(result.summary, style: const TextStyle(fontSize: 14, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 16, color: Colors.grey.shade700),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _NumberFindingCard extends StatelessWidget {
  const _NumberFindingCard({required this.finding, required this.onReport});

  final NumberFinding finding;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forRiskLevel(finding.riskLevel);

    final String detail;
    if (finding.reportCount == 0) {
      detail = 'No community reports against this number. That only means nobody has '
          'reported it yet.';
    } else {
      final String plural = finding.reportCount == 1 ? 'report' : 'reports';
      final String category = finding.topCategory == null
          ? ''
          : ', mostly ${humanizeCategory(finding.topCategory!)}';
      detail = '${finding.reportCount} community $plural$category.'
          '${finding.isPubliclyFlagged ? '' : ' Not yet enough to flag it publicly.'}';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.phone_outlined, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          finding.msisdn,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      RiskChip(label: finding.riskLevel.toUpperCase(), color: color),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: TextStyle(fontSize: 13, color: Colors.grey.shade800)),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: onReport,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.flag_outlined, size: 15),
                    label: const Text('Report this number', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkFindingCard extends StatelessWidget {
  const _LinkFindingCard({required this.finding});

  final LinkFinding finding;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forRiskLevel(finding.riskLevel);

    // "unknown" is the backend's word for "nothing wrong with the address", and
    // it must not be shown as a clean bill of health — nothing ever opened the
    // link to find out.
    final String label = switch (finding.riskLevel) {
      'high' => 'DANGEROUS',
      'medium' => 'RISKY',
      'low' => 'MINOR FLAG',
      _ => 'NOT CHECKED',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(Icons.link, size: 20, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        finding.host.isEmpty ? finding.url : finding.host,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      // The full URL is shown as plain, non-tappable text on
                      // purpose: an app warning you about a link should not also
                      // be the thing that opens it.
                      Text(
                        finding.url,
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                RiskChip(label: label, color: color),
              ],
            ),
            const SizedBox(height: 10),
            ...finding.reasons.map(
              (String reason) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(Icons.chevron_right, size: 15, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnrecognizedNumbersCard extends StatelessWidget {
  const _UnrecognizedNumbersCard({required this.numbers});

  final List<String> numbers;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.help_outline, size: 20, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Could not be checked',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${numbers.join(', ')} — not a Zimbabwean mobile number, so there are '
                    'no community reports to check it against.',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
