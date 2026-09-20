import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/country_preference.dart';
import '../../core/reporter_identity.dart';
import '../../core/models/reputation_models.dart';

/// A modal bottom sheet form for `POST /reports`, opened from both the
/// check-message screen ("Report this number") and the lookup screen. Kept
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

  late String _category =
      widget.initialCategory != null && kScamCategories.contains(widget.initialCategory)
          ? widget.initialCategory!
          : kScamCategories.first;

  /// The market the reported number belongs to. Defaults to the user's own,
  /// but is editable here because a scam number is not always local to the
  /// person receiving it — cross-border numbers are the ones worth catching.
  late String _countryCode = CountryPreference.code;
  late String _region = CountryRegistry.byCode(_countryCode).regions.first;

  /// Anonymous by default. Requiring an identity to report is a barrier for
  /// exactly the people most exposed to retaliation, and the abuse controls
  /// it would buy are recovered by the public-flag threshold instead.
  bool _reportAnonymously = true;
  bool _submitting = false;

  CountryProfile get _country => CountryRegistry.byCode(_countryCode);

  void _onCountryChanged(String? value) {
    if (value == null) return;
    setState(() {
      _countryCode = value;
      // The old region does not exist in the new country's list, so reset it
      // rather than leaving the dropdown holding an invalid value.
      _region = CountryRegistry.byCode(value).regions.first;
    });
  }

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
      // An anonymous report sends no reporter id at all — not a blank one —
      // so there is nothing linking it to this device's other reports.
      final String? reporterId =
          _reportAnonymously ? null : await ReporterIdentity.get();
      if (!mounted) return;

      final ReportResponse response = await widget.apiClient.submitReport(
        ReportCreate(
          msisdn: _msisdnController.text.trim(),
          country: _countryCode,
          category: _category,
          region: _region,
          messageExcerpt: _excerptController.text.trim(),
          reporterId: reporterId,
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
                decoration: InputDecoration(
                  labelText: 'Phone number',
                  hintText: _country.exampleMsisdn,
                  helperText: 'Local format, or international starting +${_country.dialCode}',
                ),
                validator: (String? value) {
                  final String v = (value ?? '').trim();
                  if (v.isEmpty) return 'Enter the number you want to report.';
                  // Deliberately loose: the backend owns per-country prefix and
                  // length validation (services/countries.py) and returns a
                  // specific message. Duplicating those rules here would mean
                  // two places to update every time a market is added.
                  if (!RegExp(r'^\+?[\d\s-]{7,18}$').hasMatch(v)) {
                    return 'Enter a valid mobile number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: _countryCode,
                decoration: const InputDecoration(labelText: 'Country of the number'),
                items: CountryRegistry.all
                    .map(
                      (CountryProfile c) => DropdownMenuItem<String>(
                        value: c.code,
                        child: Text('${c.name} (+${c.dialCode})'),
                      ),
                    )
                    .toList(),
                onChanged: _onCountryChanged,
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
                value: _region,
                // The label follows the country: a Kenyan user is asked for a
                // Region, a Nigerian for a Zone, a South African for a Province.
                decoration: InputDecoration(labelText: _country.regionLabel),
                items: _country.regions
                    .map((String r) => DropdownMenuItem<String>(value: r, child: Text(r)))
                    .toList(),
                onChanged: (String? value) {
                  if (value != null) setState(() => _region = value);
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _excerptController,
                maxLength: 1000,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Message excerpt (optional)',
                  helperText: 'Phone numbers, codes and ID numbers in this text are '
                      'removed before it is stored.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: _reportAnonymously,
                onChanged: (bool value) => setState(() => _reportAnonymously = value),
                contentPadding: EdgeInsets.zero,
                title: const Text('Report anonymously'),
                subtitle: Text(
                  _reportAnonymously
                      ? 'Your report still counts. Nothing links it to you or to '
                          'your other reports.'
                      : 'Sends a random device id so duplicate reports are merged '
                          'and you get a confirmation. Still no name or account.',
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
