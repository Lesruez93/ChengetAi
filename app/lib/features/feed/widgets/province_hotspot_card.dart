import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/models/feed_models.dart';
import '../../../core/theme.dart';

/// A single province row for the hotspot list — a colored dot/badge for
/// `level` (green/yellow/red), the province name, report count, and top
/// category. Kept local to the feed feature (rather than shared/widgets)
/// since it's a one-off list-item layout specific to this screen, unlike
/// the six cross-feature shared widgets.
class ProvinceHotspotCard extends StatelessWidget {
  const ProvinceHotspotCard({required this.hotspot, super.key});

  final ProvinceHotspot hotspot;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forHotspotLevel(hotspot.level);
    final bool hasActivity = hotspot.reportCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: hotspot.level == 'red'
                    ? <BoxShadow>[BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)]
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(hotspot.province, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  if (hasActivity && hotspot.topCategory != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'Top: ${humanizeCategory(hotspot.topCategory!)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                hasActivity ? '${hotspot.reportCount} reports' : 'No reports',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
