import 'package:flutter/material.dart';

/// A compact "number + label" tile for dashboards and summary rows.
///
/// Reused in the feed screen (trending category score/report count), the
/// sentinel screen (transactions analyzed / flagged / flag rate), and the
/// number lookup card (report count).
class StatTile extends StatelessWidget {
  const StatTile({
    required this.value,
    required this.label,
    super.key,
    this.icon,
    this.color,
    this.dense = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? color;

  /// Tighter padding/typography for use inside already-dense rows (e.g. a
  /// stat strip at the top of a card) versus a standalone tile.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final Color effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 8 : 12),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: dense ? 16 : 18, color: effectiveColor),
                const SizedBox(width: 6),
              ],
              Text(
                value,
                style: TextStyle(
                  fontSize: dense ? 18 : 22,
                  fontWeight: FontWeight.bold,
                  color: effectiveColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: dense ? 11.5 : 12.5,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
