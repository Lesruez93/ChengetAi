import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../core/models/reputation_models.dart';
import '../../core/theme.dart';
import 'risk_chip.dart';
import 'stat_tile.dart';

/// Displays a `GET /numbers/{msisdn}` result: risk-level badge, report
/// count, category breakdown, last-reported date, and the "publicly
/// flagged" threshold badge. Used in the lookup feature, and reusable
/// wherever a number's reputation needs to be shown (e.g. a future inbox
/// integration).
class NumberReputationCard extends StatelessWidget {
  const NumberReputationCard({required this.reputation, super.key});

  final NumberReputation reputation;

  String get _riskLabel => switch (reputation.riskLevel) {
        'high' => 'High Risk',
        'medium' => 'Medium Risk',
        'low' => 'Low Risk',
        _ => 'No Reports Yet',
      };

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.forRiskLevel(reputation.riskLevel);
    final DateFormat dateFormat = DateFormat('d MMM y, HH:mm');

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (reputation.isFromCache)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.cloud_off, size: 14, color: Colors.black54),
                    const SizedBox(width: 6),
                    Text(
                      reputation.cachedAt == null
                          ? 'Offline — showing cached data'
                          : 'Offline — cached ${dateFormat.format(reputation.cachedAt!.toLocal())}',
                      style: const TextStyle(fontSize: 11.5, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    reputation.msisdn,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withOpacity(0.4)),
                  ),
                  child: Text(
                    _riskLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            if (reputation.isPubliclyFlagged) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Icon(Icons.flag, size: 14, color: AppColors.danger),
                  const SizedBox(width: 4),
                  Text(
                    'Publicly flagged by the community',
                    style: TextStyle(fontSize: 12.5, color: AppColors.danger, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: StatTile(
                    value: '${reputation.reportCount}',
                    label: reputation.reportCount == 1 ? 'Report' : 'Reports',
                    icon: Icons.report_gmailerrorred,
                    color: color,
                    dense: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StatTile(
                    value: reputation.categories.length.toString(),
                    label: reputation.categories.length == 1 ? 'Category' : 'Categories',
                    icon: Icons.category_outlined,
                    color: color,
                    dense: true,
                  ),
                ),
              ],
            ),
            if (reputation.categories.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: reputation.categories.entries
                    .map(
                      (MapEntry<String, int> e) => RiskChip(
                        label: '${humanizeCategory(e.key)} (${e.value})',
                        color: color,
                      ),
                    )
                    .toList(),
              ),
            ],
            if (reputation.lastReportedAt != null) ...<Widget>[
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Last reported ${dateFormat.format(reputation.lastReportedAt!.toLocal())}',
                    style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
