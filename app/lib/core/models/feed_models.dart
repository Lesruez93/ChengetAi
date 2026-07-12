/// Models for `GET /feed` and `GET /feed/trending`. Mirrors
/// `backend/app/schemas/feed.py`.
library;

class FeedItem {
  const FeedItem({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.province,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String summary;
  final String? province;
  final DateTime createdAt;

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    return FeedItem(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      summary: json['summary'] as String,
      province: json['province'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class TrendingCategory {
  const TrendingCategory({
    required this.category,
    required this.score,
    required this.reportCount,
  });

  final String category;
  final double score;
  final int reportCount;

  factory TrendingCategory.fromJson(Map<String, dynamic> json) {
    return TrendingCategory(
      category: json['category'] as String,
      score: (json['score'] as num).toDouble(),
      reportCount: json['report_count'] as int,
    );
  }
}

/// `level` is one of `green`, `yellow`, `red`.
typedef HotspotLevel = String;

class ProvinceHotspot {
  const ProvinceHotspot({
    required this.province,
    required this.level,
    required this.reportCount,
    required this.topCategory,
  });

  final String province;
  final HotspotLevel level;
  final int reportCount;
  final String? topCategory;

  factory ProvinceHotspot.fromJson(Map<String, dynamic> json) {
    return ProvinceHotspot(
      province: json['province'] as String,
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
    required this.trendingCategories,
    required this.hotspots,
    required this.methodNote,
  });

  final DateTime generatedAt;
  final int windowDays;
  final List<TrendingCategory> trendingCategories;
  final List<ProvinceHotspot> hotspots;

  /// Backend-provided disclosure that this endpoint is weighted-rules, not
  /// an AI model — surfaced verbatim in the UI so the distinction (see
  /// docs/architecture.md, "Where AI is used, and where it deliberately
  /// isn't") is never lost in translation.
  final String methodNote;

  factory TrendingFeedResponse.fromJson(Map<String, dynamic> json) {
    return TrendingFeedResponse(
      generatedAt: DateTime.parse(json['generated_at'] as String),
      windowDays: json['window_days'] as int,
      trendingCategories: (json['trending_categories'] as List<dynamic>)
          .map((dynamic e) => TrendingCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      hotspots: (json['hotspots'] as List<dynamic>)
          .map((dynamic e) => ProvinceHotspot.fromJson(e as Map<String, dynamic>))
          .toList(),
      methodNote: json['method_note'] as String,
    );
  }
}
