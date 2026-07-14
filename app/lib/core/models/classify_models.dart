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
  });

  final Verdict verdict;
  final double confidence;
  final List<RiskPhrase> riskPhrases;
  final String explanation;
  final String? matchedCategory;
  final String strategyUsed;

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
    );
  }
}
