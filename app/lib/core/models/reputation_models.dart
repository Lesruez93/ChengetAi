/// Models for `GET /numbers/{msisdn}` and `POST /reports`. Mirrors
/// `backend/app/schemas/reputation.py`.
library;

/// Request payload for `POST /reports`.
class ReportCreate {
  const ReportCreate({
    required this.msisdn,
    required this.country,
    required this.category,
    required this.region,
    this.messageExcerpt = '',
    this.reporterId,
  });

  final String msisdn;

  /// ISO 3166-1 alpha-2. Required to disambiguate a local-format number —
  /// 0771234567 is a valid Zimbabwean, Ugandan *and* Tanzanian number, so
  /// without this the backend cannot tell three different people apart.
  final String country;

  final String category;

  /// First-level unit within the country; what it is called depends on the
  /// market (see `CountryProfile.regionLabel`).
  final String region;

  /// Redacted server-side before storage — third-party numbers, OTPs and ID
  /// numbers never reach the database.
  final String messageExcerpt;

  /// Leave null to report anonymously. Anonymous reports are accepted and
  /// counted; requiring an identity is a barrier for exactly the people most
  /// at risk of retaliation.
  final String? reporterId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'msisdn': msisdn,
      'country': country,
      'category': category,
      'region': region,
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
    required this.country,
    required this.category,
    required this.region,
    required this.createdAt,
    required this.status,
  });

  final String id;

  /// Always returned in E.164 form, e.g. `+263771234567`.
  final String msisdn;
  final String country;
  final String category;
  final String region;
  final DateTime createdAt;
  final ReportStatus status;

  factory ReportResponse.fromJson(Map<String, dynamic> json) {
    return ReportResponse(
      id: json['id'] as String,
      msisdn: json['msisdn'] as String,
      country: json['country'] as String,
      category: json['category'] as String,
      region: json['region'] as String,
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
    required this.country,
    required this.reportCount,
    required this.categories,
    required this.countries,
    required this.lastReportedAt,
    required this.isPubliclyFlagged,
    required this.riskLevel,
    this.isFromCache = false,
    this.cachedAt,
  });

  /// Always E.164, e.g. `+254712345678`.
  final String msisdn;

  /// The market the number was most reported from.
  final String country;

  final int reportCount;
  final Map<String, int> categories;

  /// Report counts keyed by reporting country. More than one entry means the
  /// number has cross-border reach, which the backend treats as high risk
  /// regardless of volume.
  final Map<String, int> countries;

  final DateTime? lastReportedAt;
  final bool isPubliclyFlagged;
  final RiskLevel riskLevel;

  /// True when this instance was served from the local offline cache
  /// (see `features/lookup/lookup_cache.dart`) rather than a live API call.
  final bool isFromCache;
  final DateTime? cachedAt;

  bool get isCrossBorder => countries.length > 1;

  factory NumberReputation.fromJson(Map<String, dynamic> json) {
    return NumberReputation(
      msisdn: json['msisdn'] as String,
      country: json['country'] as String? ?? '',
      reportCount: json['report_count'] as int,
      categories: Map<String, int>.from(
          json['categories'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{}),
      countries: Map<String, int>.from(
          json['countries'] as Map<dynamic, dynamic>? ?? <dynamic, dynamic>{}),
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
      'country': country,
      'report_count': reportCount,
      'categories': categories,
      'countries': countries,
      'last_reported_at': lastReportedAt?.toIso8601String(),
      'is_publicly_flagged': isPubliclyFlagged,
      'risk_level': riskLevel,
    };
  }

  NumberReputation asCached({required DateTime cachedAt}) {
    return NumberReputation(
      msisdn: msisdn,
      country: country,
      reportCount: reportCount,
      categories: categories,
      countries: countries,
      lastReportedAt: lastReportedAt,
      isPubliclyFlagged: isPubliclyFlagged,
      riskLevel: riskLevel,
      isFromCache: true,
      cachedAt: cachedAt,
    );
  }
}
