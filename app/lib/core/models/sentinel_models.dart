/// Models for `POST /sentinel/analyze`. Mirrors
/// `backend/app/schemas/sentinel.py`.
library;

class FlaggedTransaction {
  const FlaggedTransaction({
    required this.transactionId,
    required this.timestamp,
    required this.agentId,
    required this.customerMsisdn,
    required this.type,
    required this.amount,
    required this.anomalyScore,
    required this.reasons,
  });

  final String transactionId;
  final DateTime timestamp;
  final String agentId;
  final String customerMsisdn;
  final String type;
  final double amount;
  final double anomalyScore;
  final List<String> reasons;

  factory FlaggedTransaction.fromJson(Map<String, dynamic> json) {
    return FlaggedTransaction(
      transactionId: json['transaction_id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      agentId: json['agent_id'] as String,
      customerMsisdn: json['customer_msisdn'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      anomalyScore: (json['anomaly_score'] as num).toDouble(),
      reasons: List<String>.from(json['reasons'] as List<dynamic>),
    );
  }
}

class SentinelAnalyzeResponse {
  const SentinelAnalyzeResponse({
    required this.jobId,
    required this.nTransactions,
    required this.nFlagged,
    required this.flagged,
    required this.summaryByReason,
  });

  final String jobId;
  final int nTransactions;
  final int nFlagged;
  final List<FlaggedTransaction> flagged;
  final Map<String, int> summaryByReason;

  factory SentinelAnalyzeResponse.fromJson(Map<String, dynamic> json) {
    return SentinelAnalyzeResponse(
      jobId: json['job_id'] as String,
      nTransactions: json['n_transactions'] as int,
      nFlagged: json['n_flagged'] as int,
      flagged: (json['flagged'] as List<dynamic>)
          .map((dynamic e) => FlaggedTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      summaryByReason: Map<String, int>.from(json['summary_by_reason'] as Map<dynamic, dynamic>),
    );
  }
}
