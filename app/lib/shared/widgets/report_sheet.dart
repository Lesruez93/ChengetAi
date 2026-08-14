import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/models/reputation_models.dart';

/// A modal bottom sheet form for `POST /reports`, opened from both the
/// analyze screen ("Report this number") and the lookup screen. Kept
/// as a single shared widget so the report UX (fields, validation, status
/// handling) never drifts between the two entry points.
class ReportSheet extends StatefulWidget {
  const ReportSheet({
    required this.apiClient,
    super.key,
    this.initialMsisdn,
    this.initialCategory,
    this.initialMessageExcerpt,
  });

  final ApiClient apiClient;
  final String? initialMsisdn;
  final String? initialCategory;
  final String? initialMessageExcerpt;

  /// Convenience launcher — shows the sheet and returns once it's dismissed.
  static Future<void> show(
    BuildContext context, {
    required ApiClient apiClient,
    String? initialMsisdn,
    String? initialCategory,
    String? initialMessageExcerpt,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => ReportSheet(
        apiClient: apiClient,
        initialMsisdn: initialMsisdn,
        initialCategory: initialCategory,
        initialMessageExcerpt: initialMessageExcerpt,
      ),
    );
  }

  @override
  State<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<ReportSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _msisdnController =
      TextEditingController(text: widget.initialMsisdn ?? '');
  late final TextEditingController _excerptController =
      TextEditingController(text: widget.initialMessageExcerpt ?? '');

  late String _category = widget.initialCategory != null && kScamCategories.contains(widget.initialCategory)
      ? widget.initialCategory!
      : kScamCategories.first;
  String _province = kZimbabweProvinces.first;
  bool _submitting = false;

  @override
  void dispose() {
    _msisdnController.dispose();
    _excerptController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    try {
      final ReportResponse response = await widget.apiClient.submitReport(
        ReportCreate(
          msisdn: _msisdnController.text.trim(),
          category: _category,
          province: _province,
          messageExcerpt: _excerptController.text.trim(),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      final String message = switch (response.status) {
        'recorded' => 'Report submitted — thank you for helping keep others safe.',
        'duplicate_collapsed' => "You've already reported this number for this category recently.",
        'rate_limited' => "You've hit the hourly report limit. Try again later.",
        _ => 'Report submitted.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: ${e.message}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.flag_outlined),
                  const SizedBox(width: 10),
                  const Text(
                    'Report this number',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _msisdnController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '0771234567',
                ),
                validator: (String? value) {
                  final String v = (value ?? '').trim();
                  if (v.isEmpty) return 'Enter the number you want to report.';
                  if (!RegExp(r'^\+?\d{9,13}$').hasMatch(v)) {
                    return 'Enter a valid Zimbabwean mobile number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _category,
                decoration: const InputDecoration(labelText: 'Scam category'),
                items: kScamCategories
                    .map(
                      (String c) => DropdownMenuItem<String>(
                        value: c,
                        child: Text(humanizeCategory(c)),
                      ),
                    )
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _province,
                decoration: const InputDecoration(labelText: 'Province'),
                items: kZimbabweProvinces
                    .map((String p) => DropdownMenuItem<String>(value: p, child: Text(p)))
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setState(() => _province = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _excerptController,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message excerpt (optional)',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit Report'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
