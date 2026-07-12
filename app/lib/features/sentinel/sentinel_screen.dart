import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/models/sentinel_models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/stat_tile.dart';
import 'widgets/flagged_transaction_tile.dart';
import 'widgets/reason_summary_chart.dart';

/// Agent Fraud Sentinel — B2B demo screen.
///
/// Upload a transaction CSV (`transaction_id, timestamp, agent_id,
/// customer_msisdn, type, amount[, is_reversal]` — see
/// `sample_data/transactions_sample.csv`) to `POST /sentinel/analyze` and
/// review the anomaly results: summary stats, a flags-by-reason chart, and
/// a tappable flagged-transaction list.
///
/// Demo note: to pick `sample_data/transactions_sample.csv` on an emulator,
/// push it into device storage first, e.g.
///   adb push sample_data/transactions_sample.csv /sdcard/Download/
/// then select it from the system file picker below.
class SentinelScreen extends StatefulWidget {
  const SentinelScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<SentinelScreen> createState() => _SentinelScreenState();
}

class _SentinelScreenState extends State<SentinelScreen> {
  PlatformFile? _selectedFile;
  SentinelAnalyzeResponse? _result;
  bool _analyzing = false;
  String? _error;

  Future<void> _pickFile() async {
    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['csv'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    setState(() {
      _selectedFile = picked.files.single;
      _result = null;
      _error = null;
    });
  }

  Future<void> _analyze() async {
    final PlatformFile? file = _selectedFile;
    final bytes = file?.bytes;
    if (file == null || bytes == null) {
      setState(() => _error = 'Selected file has no readable data.');
      return;
    }

    setState(() {
      _analyzing = true;
      _error = null;
    });

    try {
      final SentinelAnalyzeResponse response = await widget.apiClient.analyzeSentinel(bytes, file.name);
      setState(() => _result = response);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Fraud Sentinel')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'Upload an agent transaction CSV to detect structuring, rapid '
              'reversals, unusual hours, and other anomalies.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.description_outlined, color: AppColors.brandPrimary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedFile?.name ?? 'No file selected',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _analyzing ? null : _pickFile,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('Choose CSV'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (_selectedFile == null || _analyzing) ? null : _analyze,
                            icon: _analyzing
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.analytics_outlined),
                            label: Text(_analyzing ? 'Analyzing...' : 'Analyze'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_error != null)
              EmptyState(icon: Icons.cloud_off, message: 'Analysis failed.\n$_error')
            else if (_result != null)
              _SentinelResults(result: _result!)
            else
              const EmptyState(
                icon: Icons.dashboard_customize_outlined,
                message: 'Choose a transaction CSV and tap "Analyze" to run the '
                    'anomaly detector.',
              ),
          ],
        ),
      ),
    );
  }
}

class _SentinelResults extends StatelessWidget {
  const _SentinelResults({required this.result});

  final SentinelAnalyzeResponse result;

  @override
  Widget build(BuildContext context) {
    final double flagRate = result.nTransactions == 0 ? 0 : result.nFlagged / result.nTransactions * 100;
    final List<MapEntry<String, int>> rankedReasons = result.summaryByReason.entries.toList()
      ..sort((MapEntry<String, int> a, MapEntry<String, int> b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: StatTile(
                value: '${result.nTransactions}',
                label: 'Transactions',
                icon: Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: '${result.nFlagged}',
                label: 'Flagged',
                icon: Icons.flag_outlined,
                color: AppColors.warning,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: StatTile(
                value: '${flagRate.toStringAsFixed(1)}%',
                label: 'Flag Rate',
                icon: Icons.percent,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
        if (result.summaryByReason.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          const Text('Flags by Reason', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
              child: ReasonSummaryChart(summaryByReason: result.summaryByReason),
            ),
          ),
          const SizedBox(height: 10),
          ...List<Widget>.generate(rankedReasons.length, (int i) {
            final MapEntry<String, int> entry = rankedReasons[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('#${i + 1}', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(entry.key, style: const TextStyle(fontSize: 12.5)),
                  ),
                  Text('${entry.value}', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 20),
        Text(
          'Flagged Transactions (${result.flagged.length})',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (result.flagged.isEmpty)
          const EmptyState(message: 'No anomalies found in this file.')
        else
          ...result.flagged.map((FlaggedTransaction t) => FlaggedTransactionTile(transaction: t)),
      ],
    );
  }
}
