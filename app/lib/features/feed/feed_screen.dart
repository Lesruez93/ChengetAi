import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../core/models/feed_models.dart';
import '../../core/theme.dart';
import '../../shared/widgets/app_logo.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/risk_chip.dart';
import '../../shared/widgets/stat_tile.dart';
import 'widgets/province_hotspot_card.dart';

/// Alerts / trending feed screen — the second visually-strong demo screen.
///
/// Two tabs:
///  - "Alerts": seeded editorial entries from `GET /feed`.
///  - "Trending": live weighted-rules ranking + province hotspot map from
///    `GET /feed/trending`. The hotspot list is deliberately a styled list
///    of province cards (colored dot/badge per `level`) rather than an SVG
///    map of Zimbabwe, per the spec — legible and fast to build correctly.
class FeedScreen extends StatefulWidget {
  const FeedScreen({required this.apiClient, super.key});

  final ApiClient apiClient;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  late Future<List<FeedItem>> _feedFuture;
  late Future<TrendingFeedResponse> _trendingFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = widget.apiClient.getFeed();
    _trendingFuture = widget.apiClient.getTrendingFeed();
  }

  Future<void> _refreshFeed() async {
    setState(() => _feedFuture = widget.apiClient.getFeed());
    await _feedFuture;
  }

  Future<void> _refreshTrending() async {
    setState(() => _trendingFuture = widget.apiClient.getTrendingFeed());
    await _trendingFuture;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: const AppLogo(),
          title: const Text('Scam Alerts'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: <Widget>[
              Tab(text: 'Alerts'),
              Tab(text: 'Trending & Hotspots'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            RefreshIndicator(onRefresh: _refreshFeed, child: _AlertsTab(future: _feedFuture)),
            RefreshIndicator(onRefresh: _refreshTrending, child: _TrendingTab(future: _trendingFuture)),
          ],
        ),
      ),
    );
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.future});

  final Future<List<FeedItem>> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<FeedItem>>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<List<FeedItem>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            children: <Widget>[
              EmptyState(
                icon: Icons.cloud_off,
                message: 'Could not load alerts.\n${snapshot.error}',
              ),
            ],
          );
        }
        final List<FeedItem> items = snapshot.data ?? const <FeedItem>[];
        if (items.isEmpty) {
          return ListView(
            children: const <Widget>[EmptyState(message: 'No trending scam alerts right now.')],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          itemBuilder: (BuildContext context, int index) => _FeedItemCard(item: items[index]),
        );
      },
    );
  }
}

class _FeedItemCard extends StatelessWidget {
  const _FeedItemCard({required this.item});

  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Text(item.summary, style: TextStyle(fontSize: 13.5, color: Colors.grey.shade800, height: 1.35)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                RiskChip(label: humanizeCategory(item.category), icon: Icons.category_outlined),
                if (item.province != null)
                  RiskChip(label: item.province!, icon: Icons.place_outlined, color: Colors.blueGrey),
                RiskChip(
                  label: _relativeTime(item.createdAt),
                  icon: Icons.schedule,
                  color: Colors.grey.shade700,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingTab extends StatelessWidget {
  const _TrendingTab({required this.future});

  final Future<TrendingFeedResponse> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TrendingFeedResponse>(
      future: future,
      builder: (BuildContext context, AsyncSnapshot<TrendingFeedResponse> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return ListView(
            children: <Widget>[
              EmptyState(icon: Icons.cloud_off, message: 'Could not load trending data.\n${snapshot.error}'),
            ],
          );
        }

        final TrendingFeedResponse data = snapshot.data!;
        final List<ProvinceHotspot> sortedHotspots = List<ProvinceHotspot>.from(data.hotspots)
          ..sort((ProvinceHotspot a, ProvinceHotspot b) {
            const Map<String, int> severity = <String, int>{'red': 0, 'yellow': 1, 'green': 2};
            final int levelCompare = (severity[a.level] ?? 3).compareTo(severity[b.level] ?? 3);
            if (levelCompare != 0) return levelCompare;
            return b.reportCount.compareTo(a.reportCount);
          });

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            _SectionHeader(
              title: 'Trending This Week',
              subtitle: 'Window: last ${data.windowDays} days',
            ),
            const SizedBox(height: 10),
            if (data.trendingCategories.isEmpty)
              const EmptyState(message: 'No trending categories in this window.')
            else
              SizedBox(
                height: 104,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: data.trendingCategories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final TrendingCategory category = data.trendingCategories[index];
                    return SizedBox(
                      width: 150,
                      child: StatTile(
                        value: category.score.toStringAsFixed(1),
                        label: '${humanizeCategory(category.category)} · ${category.reportCount} reports',
                        icon: Icons.trending_up,
                        color: AppColors.brandPrimary,
                        dense: true,
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                data.methodNote,
                style: TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.grey.shade600),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionHeader(title: 'Province Hotspots', subtitle: 'Green = quiet, red = active scam activity'),
            const SizedBox(height: 10),
            ...sortedHotspots.map((ProvinceHotspot h) => ProvinceHotspotCard(hotspot: h)),
          ],
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Text(subtitle!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

String _relativeTime(DateTime dateTime) {
  final Duration diff = DateTime.now().toUtc().difference(dateTime.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('d MMM').format(dateTime.toLocal());
}
