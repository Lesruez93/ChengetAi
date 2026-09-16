/// Models for `POST /classify`. Field names and types mirror
/// `backend/app/schemas/classify.py` exactly.
library;

class RiskPhrase {
  const RiskPhrase({required this.phrase, required this.reason});

  final String phrase;
  final String reason;

  factory RiskPhrase.fromJson(Map<String, dynamic> json) {
    return RiskPhrase(
      phrase: json['phrase'] as String,
      reason: json['reason'] as String,
    );
  }
}

/// One of `scam`, `suspicious`, `safe` (backend's `Verdict` literal).
typedef Verdict = String;

class ClassifyResponse {
  const ClassifyResponse({
    required this.verdict,
    required this.confidence,
    required this.riskPhrases,
    required this.explanation,
    required this.matchedCategory,
    required this.strategyUsed,
    required this.country,
    required this.nextSteps,
  });

  final Verdict verdict;
  final double confidence;
  final List<RiskPhrase> riskPhrases;
  final String explanation;
  final String? matchedCategory;
  final String strategyUsed;

  /// The market the verdict was grounded in — which wallets, currency and
  /// languages the classifier assumed.
  final String country;

  /// What to do now. Always non-empty for a scam or suspicious verdict: a
  /// label without a pathway leaves the user exactly where it found them.
  final List<String> nextSteps;

  bool get isSafe => verdict == 'safe';

  factory ClassifyResponse.fromJson(Map<String, dynamic> json) {
    return ClassifyResponse(
      verdict: json['verdict'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      riskPhrases: (json['risk_phrases'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => RiskPhrase.fromJson(e as Map<String, dynamic>))
          .toList(),
      explanation: json['explanation'] as String,
      matchedCategory: json['matched_category'] as String?,
      strategyUsed: json['strategy_used'] as String,
      country: json['country'] as String? ?? '',
      nextSteps: List<String>.from(json['next_steps'] as List<dynamic>? ?? <dynamic>[]),
    );
  }
}
