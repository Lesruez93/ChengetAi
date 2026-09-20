import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/constants.dart';
import '../../../core/models/screened_event.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/risk_chip.dart';

/// Width cap for the outcome label column. Wide enough to keep every
/// single-word verdict ("Warned", "Unknown") on one line, narrow enough that
/// the longest one wraps to two lines instead of squeezing the sender number.
const double _outcomeLabelMaxWidth = 112;

/// Ceiling on how tall the outcome label may grow before it is ellipsized.
const int _outcomeLabelMaxLines = 2;

/// One row in the Call Guard history.
///
/// Non-warning outcomes are shown as prominently as warnings, in muted colour
/// but never hidden. The question this list answers is "is screening actually
/// running?", and a list that only ever shows scams cannot answer it.
class ScreenedEventTile extends StatelessWidget {
  const ScreenedEventTile({required this.event, super.key});

  final ScreenedEvent event;

  Color get _accent => switch (event.outcome) {
        ScreeningOutcome.warned => AppColors.danger,
        ScreeningOutcome.flaggedNotificationBlocked => AppColors.danger,
        ScreeningOutcome.clean => AppColors.safe,
        ScreeningOutcome.lookupFailed => AppColors.warning,
        ScreeningOutcome.skippedDisabled => AppColors.warning,
        ScreeningOutcome.noNumberAvailable => AppColors.neutral,
        ScreeningOutcome.notAMobileNumber => AppColors.neutral,
        ScreeningOutcome.unknown => AppColors.neutral,
      };

  IconData get _outcomeIcon => switch (event.outcome) {
        ScreeningOutcome.warned => Icons.warning_amber_rounded,
        ScreeningOutcome.flaggedNotificationBlocked => Icons.notifications_off_outlined,
        ScreeningOutcome.clean => Icons.check_circle_outline,
        ScreeningOutcome.lookupFailed => Icons.cloud_off_outlined,
        ScreeningOutcome.skippedDisabled => Icons.pause_circle_outline,
        ScreeningOutcome.noNumberAvailable => Icons.person_outline,
        ScreeningOutcome.notAMobileNumber => Icons.help_outline,
        ScreeningOutcome.unknown => Icons.help_outline,
      };

  IconData get _channelIcon => switch (event.channel) {
        ThreatChannel.call => Icons.phone_outlined,
        ThreatChannel.sms => Icons.sms_outlined,
        ThreatChannel.whatsappCall => Icons.chat_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final Color accent = _accent;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_outcomeIcon, color: accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            event.sender,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (event.wasSimulated) ...<Widget>[
                          const SizedBox(width: 8),
                          _Badge(text: 'TEST', color: Colors.grey.shade700),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: <Widget>[
                        Icon(_channelIcon, size: 13, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        // Flexible, because the channel/date string is the
                        // widest fixed-content line in the tile: "WhatsApp"
                        // plus a long month abbreviation overflows a narrow
                        // tile outright if it is left unconstrained.
                        Flexible(
                          child: Text(
                            '${event.channel.label} · '
                            '${DateFormat('d MMM, HH:mm').format(event.screenedAt)}',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Deliberately *not* Flexible. A flex child is allotted its share
              // of the row whether or not it uses it, so pairing one with the
              // Expanded above splits the row in half and starves the sender
              // and channel lines even when the label is as short as "Warned".
              // Sized to its own content instead, capped so the longest label
              // ("Flagged — warning blocked") wraps rather than pushing the
              // sender out.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _outcomeLabelMaxWidth),
                child: Text(
                  event.outcome.label,
                  textAlign: TextAlign.right,
                  // Two lines is the ceiling: left to wrap freely, the longest
                  // label stacks several lines deep and drags the whole card
                  // taller than the text it is labelling. Truncating is safe
                  // here and nowhere else in the tile, because the explanation
                  // line directly below always spells the outcome out in full.
                  maxLines: _outcomeLabelMaxLines,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            event.outcome.explanation,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5, height: 1.35),
          ),
          if (_hasSignals) ...<Widget>[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                if (event.riskLevel != null)
                  RiskChip(
                    label: '${event.riskLevel!.toUpperCase()} risk',
                    color: AppColors.forRiskLevel(event.riskLevel!),
                  ),
                if (event.reportCount != null && event.reportCount! > 0)
                  RiskChip(
                    label: event.reportCount == 1 ? '1 report' : '${event.reportCount} reports',
                    color: AppColors.neutral,
                  ),
                if (event.topCategory != null)
                  RiskChip(
                    label: humanizeCategory(event.topCategory!),
                    color: AppColors.warning,
                  ),
                // Shown separately from the reputation chips because it is an
                // independent signal: a clean sender with a scam verdict is a
                // different situation from a reported number, and the two
                // must not read as one combined score.
                if (event.messageVerdict != null)
                  RiskChip(
                    label: 'Text: ${event.messageVerdict}',
                    icon: Icons.sms_outlined,
                    color: AppColors.forVerdict(event.messageVerdict!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool get _hasSignals =>
      event.riskLevel != null || event.topCategory != null || event.messageVerdict != null;
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
