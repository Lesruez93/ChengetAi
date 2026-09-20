/// Models for `GET /feed` and `GET /feed/trending`. Mirrors
/// `backend/app/schemas/feed.py`.
library;

class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.country,
    required this.region,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String summary;

  /// `null` means the alert applies across every market, not that it is
  /// unlocated — those items are always shown regardless of country scoping.
  final String? country;
  final String? region;
  final DateTime createdAt;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      summary: json['summary'] as String,
      country: json['country'] as String?,
      region: json['region'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TrendingCategory {
  const TrendingCategory({
    required this.category,
    required this.label,
    required this.score,
    required this.reportCount,
  });

  final String category;

  /// Backend-supplied display name, so the app and the dashboard can never
  /// drift on what a category is called.
  final String label;
  final double score;
  final int reportCount;

  factory TrendingCategory.fromJson(Map<String, dynamic> json) {
    return TrendingCategory(
      category: json['category'] as String,
      label: json['label'] as String? ?? json['category'] as String,
      score: (json['score'] as num).toDouble(),
      reportCount: json['report_count'] as int,
    );
  }
}

/// `level` is one of `green`, `yellow`, `red`.
typedef HotspotLevel = String;

/// A first-level administrative unit inside one country. What it is *called*
/// varies by market, so the label travels with the feed response rather than
/// being hardcoded here.
class RegionHotspot {
  const RegionHotspot({
    required this.region,
    required this.level,
    required this.reportCount,
    required this.topCategory,
  });

  final String region;
  final HotspotLevel level;
  final int reportCount;
  final String? topCategory;

  factory RegionHotspot.fromJson(Map<String, dynamic> json) {
    return RegionHotspot(
      region: json['region'] as String,
      level: json['level'] as String,
      reportCount: json['report_count'] as int,
      topCategory: json['top_category'] as String?,
    );
  }
}

/// Cross-market rollup. Shown when no country is selected, and as context
/// beneath the regional map when one is.
class CountryHotspot {
  const CountryHotspot({
    required this.country,
    required this.countryName,
    required this.level,
    required this.reportCount,
    required this.topCategory,
  });

  final String country;
  final String countryName;
  final HotspotLevel level;
  final int reportCount;
  final String? topCategory;

  factory CountryHotspot.fromJson(Map<String, dynamic> json) {
    return CountryHotspot(
      country: json['country'] as String,
      countryName: json['country_name'] as String,
      level: json['level'] as String,
      reportCount: json['report_count'] as int,
      topCategory: json['top_category'] as String?,
    );
  }
}

class TrendingFeedResponse {
  const TrendingFeedResponse({
    required this.generatedAt,
    required this.windowDays,
    required this.country,
    required this.regionLabel,
    required this.trendingCategories,
    required this.hotspots,
    required this.countryHotspots,
    required this.methodNote,
  });

  final DateTime generatedAt;
  final int windowDays;

  /// The market this response was scoped to, or `null` for the
  /// cross-country view.
  final String? country;

  /// What the scoped country calls its first-level unit ("Province",
  /// "Region", "Zone"), used as the section heading. `null` when unscoped.
  final String? regionLabel;

  final List<TrendingCategory> trendingCategories;

  /// Empty unless a country was named on the request — a 60-bucket map across
  /// seven countries answers no question a user actually has.
  final List<RegionHotspot> hotspots;

  final List<CountryHotspot> countryHotspots;

  /// Backend-provided disclosure that this endpoint is weighted-rules, not
  /// an AI model — surfaced verbatim in the UI so the distinction (see
  /// docs/architecture.md, "Where AI is used, and where it deliberately
  /// isn't") is never lost in translation.
  final String methodNote;

  factory TrendingFeedResponse.fromJson(Map<String, dynamic> json) {
    return TrendingFeedResponse(
      generatedAt: DateTime.parse(json['generated_at'] as String),
      windowDays: json['window_days'] as int,
      country: json['country'] as String?,
      regionLabel: json['region_label'] as String?,
      trendingCategories: (json['trending_categories'] as List<dynamic>)
          .map((dynamic e) => TrendingCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      hotspots: (json['hotspots'] as List<dynamic>)
          .map((dynamic e) => RegionHotspot.fromJson(e as Map<String, dynamic>))
          .toList(),
      countryHotspots: (json['country_hotspots'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => CountryHotspot.fromJson(e as Map<String, dynamic>))
          .toList(),
      methodNote: json['method_note'] as String,
    );
  }
}
