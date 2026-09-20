import 'package:flutter/material.dart';

/// A small colored chip for a single risk signal (a flagged phrase, a
/// sentinel anomaly reason, a scam category, ...).
///
/// Reused across `VerdictCard` (risk phrases), the sentinel flagged-
/// transaction detail view (anomaly reasons), and the feed's trending
/// category list — anywhere the app needs to surface a short "why" label.
class RiskChip extends StatelessWidget {
  const RiskChip({
    required this.label,
    super.key,
    this.tooltip,
    this.color,
    this.icon,
    this.onTap,
  });

  final String label;

  /// Optional longer explanation shown on long-press / tap (e.g. why a
  /// phrase is risky). If null and [onTap] is null, the chip is inert.
  final String? tooltip;
  final Color? color;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = color ?? Theme.of(context).colorScheme.secondary;

    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: effectiveColor,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (tooltip == null && onTap == null) {
      return chip;
    }

    final Widget tappable = onTap == null
        ? chip
        : InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: chip);

    return tooltip == null ? tappable : Tooltip(message: tooltip!, child: tappable);
  }
}
