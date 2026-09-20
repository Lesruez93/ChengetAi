import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/country_preference.dart';
import '../../core/models/reputation_models.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/country_menu_button.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/number_reputation_card.dart';
import '../../shared/widgets/report_sheet.dart';
import 'lookup_cache.dart';

/// Search a phone number's reputation via `GET /numbers/{msisdn}`.
///
/// Falls back to a local cache (`LookupCache`) when the network call fails,
/// so a previously-looked-up number can still be checked offline — the
/// common case for prepaid users in low-signal areas (see
/// docs/architecture.md, "Offline behaviour").
class LookupScreen extends StatefulWidget {
  const LookupScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<LookupScreen> createState() => _LookupScreenState();
}

class _LookupScreenState extends State<LookupScreen> {
  final TextEditingController _msisdnController = TextEditingController();
  LookupCache? _cache;
  NumberReputation? _result;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    LookupCache.open().then((LookupCache cache) {
      if (mounted) setState(() => _cache = cache);
    });
  }

  @override
  void dispose() {
    _msisdnController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final String msisdn = _msisdnController.text.trim();
    if (msisdn.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // A local-format number is ambiguous across markets — 0771234567 is
      // valid in Zimbabwe, Uganda and Tanzania — so the selected country goes
      // with the request. The backend ignores it for an international number.
      final NumberReputation reputation = await widget.apiClient
          .lookupNumber(msisdn, country: CountryPreference.code);
      setState(() => _result = reputation);
      await _cache?.save(reputation);
    } on ApiException catch (e) {
      // Cache keys are the raw input, so an offline hit only matches a number
      // the user typed the same way before — acceptable for a fallback that
      // exists purely so a repeat check works with no signal.
      final NumberReputation? cached = _cache?.read(msisdn);
      if (cached != null) {
        setState(() => _result = cached);
      } else {
        setState(() => _error = e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openReportSheet() {
    ReportSheet.show(
      context,
      apiClient: widget.apiClient,
      initialMsisdn: _msisdnController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const AppLogo(),
        title: const Text('Number Lookup'),
        actions: const <Widget>[CountryMenuButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            ValueListenableBuilder<String>(
              valueListenable: CountryPreference.codeNotifier,
              builder: (BuildContext context, String _, __) => Text(
                'Check whether a number has been reported for scams before you reply, '
                'call back, or send money. Local numbers are read as '
                '${CountryPreference.profile.name} — type +country code for any other market.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _msisdnController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: CountryPreference.profile.exampleMsisdn,
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _loading ? null : _search,
                  child: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_error != null)
              EmptyState(
                icon: Icons.cloud_off,
                message: 'Could not look up this number.\n$_error',
                actionLabel: 'Retry',
                onAction: _search,
              )
            else if (_result != null) ...<Widget>[
              NumberReputationCard(reputation: _result!),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _openReportSheet,
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Report This Number'),
              ),
            ] else
              const EmptyState(
                icon: Icons.search,
                message: 'Enter a phone number above to see its scam-report history.',
              ),
          ],
        ),
      ),
    );
  }
}
