/// Models for `GET /numbers/{msisdn}` and `POST /reports`. Mirrors
/// `backend/app/schemas/reputation.py`.
library;

/// Request payload for `POST /reports`.
class ReportCreate {
  const ReportCreate({
    required this.msisdn,
    required this.category,
    required this.province,
    this.messageExcerpt = '',
    this.reporterId,
  });

  final String msisdn;
  final String category;
  final String province;
  final String messageExcerpt;
  final String? reporterId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msisdn': msisdn,
      'category': category,
      'province': province,
      'message_excerpt': messageExcerpt,
      if (reporterId != null) 'reporter_id': reporterId,
    };
  }
}

/// One of `recorded`, `duplicate_collapsed`, `rate_limited`.
typedef ReportStatus = String;

class ReportResponse {
  const ReportResponse({
    required this.id,
    required this.msisdn,
    required this.category,
    required this.province,
    required this.createdAt,
    required this.status,
  });

  final String id;
  final String msisdn;
  final String category;
  final String province;
  final DateTime createdAt;
  final ReportStatus status;

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      id: json['id'] as String,
      msisdn: json['msisdn'] as String,
      category: json['category'] as String,
      province: json['province'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      status: json['status'] as String,
    );
  }
}

/// `risk_level` is one of `unknown`, `low`, `medium`, `high`.
typedef RiskLevel = String;

class NumberReputation {
  const NumberReputation({
    required this.msisdn,
    required this.reportCount,
    required this.categories,
    required this.lastReportedAt,
    required this.isPubliclyFlagged,
    required this.riskLevel,
    this.isFromCache = false,
    this.cachedAt,
  });

  final String msisdn;
  final int reportCount;
  final Map<String, int> categories;
  final DateTime? lastReportedAt;
  final bool isPubliclyFlagged;
  final RiskLevel riskLevel;

  /// True when this instance was served from the local offline cache
  /// (see `features/lookup/lookup_cache.dart`) rather than a live API call.
  final bool isFromCache;
  final DateTime? cachedAt;

  factory NumberReputation.fromJson(Map<String, dynamic> json) {
    return NumberReputation(
      msisdn: json['msisdn'] as String,
      reportCount: json['report_count'] as int,
      categories: Map<String, int>.from(json['categories'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{}),
      lastReportedAt: json['last_reported_at'] == null
          ? null
          : DateTime.parse(json['last_reported_at'] as String),
      isPubliclyFlagged: json['is_publicly_flagged'] as bool,
      riskLevel: json['risk_level'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msisdn': msisdn,
      'report_count': reportCount,
      'categories': categories,
      'last_reported_at': lastReportedAt?.toIso8601String(),
      'is_publicly_flagged': isPubliclyFlagged,
      'risk_level': riskLevel,
    };
  }

  NumberReputation asCached({required DateTime cachedAt}) {
    return NumberReputation(
      msisdn: msisdn,
      reportCount: reportCount,
      categories: categories,
      lastReportedAt: lastReportedAt,
      isPubliclyFlagged: isPubliclyFlagged,
      riskLevel: riskLevel,
      isFromCache: true,
      cachedAt: cachedAt,
    );
  }
}
