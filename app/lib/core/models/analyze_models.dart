/// Models for `POST /analyze` — the universal "paste anything" check. Mirrors
/// `backend/app/schemas/analyze.py`.
library;

import 'classify_models.dart';

/// One link found in the pasted text, judged from its address alone.
class LinkFinding {
  const LinkFinding({
    required this.url,
    required this.host,
    required this.riskLevel,
    required this.reasons,
  });

  final String url;
  final String host;

  /// `unknown` / `low` / `medium` / `high`. Note that `unknown` means "nothing
  /// wrong with the address" — the backend never opens the link, so it is never
  /// in a position to call one safe.
  final String riskLevel;

  /// Plain-language reasons, one sentence each, ready to show as-is.
  final List<String> reasons;

  factory LinkFinding.fromJson(Map<String, dynamic> json) {
    return LinkFinding(
      url: json['url'] as String,
      host: json['host'] as String,
      riskLevel: json['risk_level'] as String,
      reasons: (json['reasons'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
    );
  }
}

/// One phone number found in the pasted text, checked against community reports.
class NumberFinding {
  const NumberFinding({
    required this.msisdn,
    required this.riskLevel,
    required this.reportCount,
    required this.isPubliclyFlagged,
    required this.topCategory,
  });

  final String msisdn;
  final String riskLevel;
  final int reportCount;
  final bool isPubliclyFlagged;
  final String? topCategory;

  factory NumberFinding.fromJson(Map<String, dynamic> json) {
    return NumberFinding(
      msisdn: json['msisdn'] as String,
      riskLevel: json['risk_level'] as String,
      reportCount: json['report_count'] as int,
      isPubliclyFlagged: json['is_publicly_flagged'] as bool? ?? false,
      topCategory: json['top_category'] as String?,
    );
  }
}

/// The combined result: one verdict, with the per-entity findings that produced
/// it.
class AnalyzeResponse {
  const AnalyzeResponse({
    required this.verdict,
    required this.confidence,
    required this.summary,
    required this.message,
    required this.links,
    required this.numbers,
    required this.unrecognizedNumbers,
    required this.methodNote,
  });

  final Verdict verdict;
  final double confidence;

  /// Plain-language summary of every finding, safe to show on its own.
  final String summary;

  /// Classifier result for the prose. Null when the paste was just a link or a
  /// number, with too few words to be worth classifying.
  final ClassifyResponse? message;

  final List<LinkFinding> links;
  final List<NumberFinding> numbers;

  /// Phone-like text that isn't a Zimbabwean mobile number, so it couldn't be
  /// looked up. Surfaced rather than dropped: "we can't check this" is a
  /// different answer from "this is fine".
  final List<String> unrecognizedNumbers;
  final String methodNote;

  bool get hasFindings => links.isNotEmpty || numbers.isNotEmpty || message != null;

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return AnalyzeResponse(
      verdict: json['verdict'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      summary: json['summary'] as String,
      message: json['message'] == null
          ? null
          : ClassifyResponse.fromJson(json['message'] as Map<String, dynamic>),
      links: (json['links'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => LinkFinding.fromJson(e as Map<String, dynamic>))
          .toList(),
      numbers: (json['numbers'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => NumberFinding.fromJson(e as Map<String, dynamic>))
          .toList(),
      unrecognizedNumbers: (json['unrecognized_numbers'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      methodNote: json['method_note'] as String? ?? '',
    );
  }
}
