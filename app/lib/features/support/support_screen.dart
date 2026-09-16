import 'package:flutter/material.dart';

import '../../core/api_client.dart';
import '../../core/country_preference.dart';
import '../../core/models/support_models.dart';
import '../../shared/widgets/country_menu_button.dart';
import '../../shared/widgets/empty_state.dart';

/// "Get help" — the Safety, Reporting & Protection half of the product.
///
/// Reachable on its own tab, not only after a verdict, because the people who
/// need it most often arrive having already sent money, or having been called
/// rather than texted. Gating help behind "first paste us a message" would
/// shut out exactly those users.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key, required this.apiClient, this.initialCategory});

  final ApiClient apiClient;

  /// Set when the user arrives from a scam verdict, so the pathway leads with
  /// that category's specific first action.
  final String? initialCategory;

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  SupportPathway? _pathway;
  String? _error;
  bool _loading = false;

  /// Which country the in-flight request was for. Switching markets twice in
  /// quick succession would otherwise let a slower first response overwrite a
  /// faster second one, leaving Kenyan contacts on a Nigerian screen.
  String? _requestedFor;

  @override
  void initState() {
    super.initState();
    _load();
    CountryPreference.codeNotifier.addListener(_onCountryChanged);
  }

  @override
  void dispose() {
    CountryPreference.codeNotifier.removeListener(_onCountryChanged);
    super.dispose();
  }

  void _onCountryChanged() {
    if (mounted) {
      _load();
    }
  }

  Future<void> _load() async {
    final String country = CountryPreference.code;
    setState(() {
      _loading = true;
      _error = null;
      _requestedFor = country;
    });
    try {
      final SupportPathway pathway = await widget.apiClient
          .getSupportPathway(country, category: widget.initialCategory);
      if (!mounted || _requestedFor != country) {
        return;
      }
      setState(() {
        _pathway = pathway;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted || _requestedFor != country) {
        return;
      }
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Get help'),
        actions: const <Widget>[CountryMenuButton()],
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _pathway == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_pathway == null) {
      return ListView(
        children: <Widget>[
          const SizedBox(height: 80),
          EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load support contacts',
            message: _error ?? 'Pull down to try again.',
          ),
        ],
      );
    }
    final SupportPathway pathway = _pathway!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        Text(
          'What to do right now',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'Ordered by how quickly each step stops you losing money.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        ...pathway.immediateSteps.asMap().entries.map(
              (MapEntry<int, String> e) => _StepTile(index: e.key + 1, text: e.value),
            ),
        const SizedBox(height: 24),
        Text(
          'Who to contact in ${pathway.countryName}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        ..._channelSections(context, pathway),
        const SizedBox(height: 20),
        Text(pathway.dataNote, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<Widget> _channelSections(BuildContext context, SupportPathway pathway) {
    // Ordered by urgency, matching the backend's escalation ladder: the wallet
    // provider is the only rung that can still stop a transfer in flight.
    const Map<String, String> kindLabels = <String, String>{
      'wallet': 'Your wallet or bank — call first',
      'regulator': 'Regulators',
      'police': 'Law enforcement',
      'support': 'Other support',
    };

    final List<Widget> sections = <Widget>[];
    for (final MapEntry<String, String> entry in kindLabels.entries) {
      final List<SupportChannel> channels = pathway.channelsOfKind(entry.key);
      if (channels.isEmpty) {
        continue;
      }
      sections.add(Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(entry.value, style: Theme.of(context).textTheme.labelLarge),
      ));
      sections.addAll(channels.map((SupportChannel c) => _ChannelCard(channel: c)));
    }
    return sections;
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 12,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text('$index', style: Theme.of(context).textTheme.labelSmall),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({required this.channel});

  final SupportChannel channel;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              channel.organisation,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(channel.whatItDoes, style: Theme.of(context).textTheme.bodySmall),
            if (channel.contact != null) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  const Icon(Icons.phone_outlined, size: 16),
                  const SizedBox(width: 6),
                  SelectableText(
                    channel.contact!,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
            if (channel.url != null) ...<Widget>[
              const SizedBox(height: 6),
              SelectableText(channel.url!, style: Theme.of(context).textTheme.bodySmall),
            ],
            // An unconfirmed contact is shown *with* its caveat rather than
            // hidden: the organisation is still the right door to knock on, and
            // presenting a number we have not verified as fact is its own
            // safety failure.
            if (!channel.verified) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Icon(Icons.info_outline, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Confirm this contact on the organisation’s own website, your bank '
                      'card, or your SIM pack before relying on it.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
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
