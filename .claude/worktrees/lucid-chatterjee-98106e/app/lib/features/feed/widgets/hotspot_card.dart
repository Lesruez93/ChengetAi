import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../core/models/feed_models.dart';
import '../../../core/theme.dart';

/// A single hotspot row — a coloured dot for `level` (green/yellow/red), the
/// place name, report count, and top category.
///
/// Shared between the within-country regional map and the cross-country
/// rollup, which render identically and differ only in what "place" means.
/// Rather than parameterise on the two model types, callers pass the already
/// extracted fields, so adding a third scope later needs no change here.
class HotspotCard extends StatelessWidget {
  const HotspotCard({
    required this.name,
    required this.level,
    required this.reportCount,
    required this.topCategory,
    super.key,
  });

  /// Named constructor for a within-country region (province, county, zone).
  HotspotCard.region(RegionHotspot hotspot, {Key? key})
      : this(
          name: hotspot.region,
          level: hotspot.level,
          reportCount: hotspot.reportCount,
          topCategory: hotspot.topCategory,
          key: key,
        );

  /// Named constructor for a whole market in the cross-country rollup.
  HotspotCard.country(CountryHotspot hotspot, {Key? key})
      : this(
          name: hotspot.countryName,
          level: hotspot.level,
          reportCount: hotspot.reportCount,
          topCategory: hotspot.topCategory,
          key: key,
        );

  final String name;
  final HotspotLevel level;
  final int reportCount;
  final String? topCategory;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forHotspotLevel(level);
    final bool hasActivity = reportCount > 0;

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
                boxShadow: level == 'red'
                    ? <BoxShadow>[
                        BoxShadow(color: color.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                  if (hasActivity && topCategory != null) ...<Widget>[
                    const SizedBox(height: 2),
                    Text(
                      'Top: ${humanizeCategory(topCategory!)}',
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
                hasActivity ? '$reportCount reports' : 'No reports',
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
