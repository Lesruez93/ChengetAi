import 'package:flutter/material.dart';

import '../../core/models/classify_models.dart';
import '../../core/theme.dart';
import 'risk_chip.dart';

/// The primary result card for `POST /classify` — verdict, confidence, an
/// inline highlight of risky phrases within the original message, a
/// plain-language explanation, and which classifier strategy produced it.
///
/// This is the visual centerpiece of the check-message flow, so it carries
/// more layout/paint logic than a typical shared widget; it's still a pure
/// presentation component (all data comes in via constructor) so it stays
/// reusable and easy to reason about.
class VerdictCard extends StatelessWidget {
  const VerdictCard({
    required this.result,
    super.key,
    this.sourceText,
  });

  final ClassifyResponse result;

  /// The original message text, used to render inline highlights over the
  /// matched risk phrases. If null, only the RiskChip list is shown.
  final String? sourceText;

  IconData get _icon => switch (result.verdict) {
        'scam' => Icons.gpp_bad_outlined,
        'suspicious' => Icons.warning_amber_outlined,
        'safe' => Icons.verified_outlined,
        _ => Icons.help_outline,
      };

  String get _verdictLabel => switch (result.verdict) {
        'scam' => 'Likely Scam',
        'suspicious' => 'Suspicious',
        'safe' => 'Looks Safe',
        _ => result.verdict,
      };

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forVerdict(result.verdict);
    final int confidencePct = (result.confidence * 100).round();

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
                  child: Icon(_icon, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _verdictLabel,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$confidencePct% confidence · ${result.strategyUsed} classifier',
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: result.confidence,
                    minHeight: 6,
                    backgroundColor: color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  result.explanation,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                if (result.matchedCategory != null) ...<Widget>[
                  const SizedBox(height: 12),
                  RiskChip(
                    label: 'Pattern: ${result.matchedCategory}',
                    icon: Icons.label_outline,
                    color: color,
                  ),
                ],
                if (sourceText != null && sourceText!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 16),
                  Text(
                    'Flagged phrases in your message',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: _buildHighlightedText(sourceText!, color),
                  ),
                ],
                if (result.riskPhrases.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: result.riskPhrases
                        .map(
                          (RiskPhrase rp) => RiskChip(
                            label: rp.phrase,
                            tooltip: rp.reason,
                            color: color,
                            icon: Icons.info_outline,
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders [text] as RichText with every occurrence of a risk phrase
  /// (case-insensitive) bolded and underlined in the verdict color.
  Widget _buildHighlightedText(String text, Color highlightColor) {
    if (result.riskPhrases.isEmpty) {
      return Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4));
    }

    final String lowerText = text.toLowerCase();
    final List<_Match> matches = <_Match>[];
    for (final RiskPhrase rp in result.riskPhrases) {
      final String needle = rp.phrase.toLowerCase();
      if (needle.isEmpty) continue;
      int start = 0;
      while (true) {
        final int idx = lowerText.indexOf(needle, start);
        if (idx == -1) break;
        matches.add(_Match(idx, idx + needle.length));
        start = idx + needle.length;
      }
    }
    matches.sort((_Match a, _Match b) => a.start.compareTo(b.start));

    final List<TextSpan> spans = <TextSpan>[];
    int cursor = 0;
    for (final _Match m in matches) {
      if (m.start < cursor) continue; // skip overlaps
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: highlightColor,
            decoration: TextDecoration.underline,
            decorationColor: highlightColor,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13.5, height: 1.4, color: Colors.black87),
        children: spans,
      ),
    );
  }
}

class _Match {
  const _Match(this.start, this.end);
  final int start;
  final int end;
}
