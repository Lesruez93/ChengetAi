import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/sentinel_models.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/risk_chip.dart';

/// One row in the flagged-transactions list. Tapping opens a detail sheet
/// with the full transaction and its anomaly reasons as RiskChips.
class FlaggedTransactionTile extends StatelessWidget {
  const FlaggedTransactionTile({required this.transaction, super.key});

  final FlaggedTransaction transaction;

  Color get _severityColor {
    if (transaction.anomalyScore >= 0.75) return AppColors.danger;
    if (transaction.anomalyScore >= 0.55) return AppColors.warning;
    return AppColors.neutral;
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (BuildContext context) => _FlaggedTransactionDetail(transaction: transaction),
    );
  }

  @override
  Widget build(BuildContext context) {
    final NumberFormat currency = NumberFormat.currency(symbol: '\$');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => _showDetail(context),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: _severityColor.withOpacity(0.15),
          foregroundColor: _severityColor,
          child: Text(
            transaction.anomalyScore.toStringAsFixed(2),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          '${transaction.transactionId} · ${currency.format(transaction.amount)}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
        ),
        subtitle: Text(
          '${transaction.type} · Agent ${transaction.agentId} · ${transaction.customerMsisdn}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _FlaggedTransactionDetail extends StatelessWidget {
  const _FlaggedTransactionDetail({required this.transaction});

  final FlaggedTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final DateFormat dateFormat = DateFormat('d MMM y, HH:mm');
    final NumberFormat currency = NumberFormat.currency(symbol: '\$');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(transaction.transactionId, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              dateFormat.format(transaction.timestamp.toLocal()),
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 18),
            _DetailRow(label: 'Amount', value: currency.format(transaction.amount)),
            _DetailRow(label: 'Type', value: transaction.type),
            _DetailRow(label: 'Agent', value: transaction.agentId),
            _DetailRow(label: 'Customer', value: transaction.customerMsisdn),
            _DetailRow(label: 'Anomaly score', value: transaction.anomalyScore.toStringAsFixed(3)),
            const SizedBox(height: 14),
            Text(
              'Why it was flagged',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: transaction.reasons
                  .map((String r) => RiskChip(label: r, color: AppColors.warning, icon: Icons.warning_amber_outlined))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
