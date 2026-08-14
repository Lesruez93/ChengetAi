import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'constants.dart';
import 'models/classify_models.dart';
import 'models/feed_models.dart';
import 'models/protection_models.dart';
import 'models/reputation_models.dart';
import 'models/sentinel_models.dart';

/// Thrown for any non-2xx response or transport failure. Carries the raw
/// status code so callers can special-case things like 422 (validation).
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($statusCode): $message';
}

/// Thin wrapper around the ChengetAI FastAPI backend described in
/// `docs/api.md`. One method per endpoint, each returning a typed model.
///
/// Deliberately not a singleton: screens own an instance (or one is handed
/// down via a simple constructor parameter) so tests could substitute a
/// fake `http.Client` without any DI framework.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.apiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('$_baseUrl$path').replace(queryParameters: query);
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = response.body;
      try {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
          detail = decoded['detail'].toString();
        }
      } catch (_) {
        // response body wasn't JSON; fall back to raw text above.
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, String>? query,
  }) async {
    final http.Response response;
    try {
      response = await _client.get(_uri(path, query)).timeout(AppConfig.apiTimeout);
    } catch (e) {
      throw ApiException('Could not reach the server: $e');
    }
    return parse(_decode(response));
  }

  Future<T> _post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(Map<String, dynamic>) parse,
  ) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(AppConfig.apiTimeout);
    } catch (e) {
      throw ApiException('Could not reach the server: $e');
    }
    return parse(_decode(response));
  }

  /// `POST /classify` — classify a pasted/shared message as scam, suspicious
  /// or safe. `strategy` overrides the backend's default classifier; leave
  /// null to use whatever `CLASSIFIER_STRATEGY` the server is configured with.
  Future<ClassifyResponse> classify(String text, {String? strategy}) {
    return _post(
      '/classify',
      <String, dynamic>{
        'text': text,
        if (strategy != null) 'strategy': strategy,
      },
      ClassifyResponse.fromJson,
    );
  }

  /// `GET /numbers/{msisdn}` — number reputation lookup. Accepts local
  /// (0771234567) or international (+263771234567) formats; the backend
  /// normalizes.
  Future<NumberReputation> lookupNumber(String msisdn) {
    return _get('/numbers/${Uri.encodeComponent(msisdn)}', NumberReputation.fromJson);
  }

  /// `GET /numbers/flagged/sync` — the publicly-flagged number set, for the
  /// on-device call/SMS blocklist.
  ///
  /// Pass the [knownVersion] currently stored on the device; if the server's
  /// set still hashes to the same value it replies with `unchanged: true` and
  /// no payload, which keeps a routine sync down to a few hundred bytes on a
  /// metered connection.
  Future<FlaggedNumbersSync> syncFlaggedNumbers({String? knownVersion}) {
    return _get(
      '/numbers/flagged/sync',
      FlaggedNumbersSync.fromJson,
      query: <String, String>{
        if (knownVersion != null && knownVersion.isNotEmpty) 'known_version': knownVersion,
      },
    );
  }

  /// `POST /reports` — report a number for a scam category.
  Future<ReportResponse> submitReport(ReportCreate report) {
    return _post('/reports', report.toJson(), ReportResponse.fromJson);
  }

  /// `GET /feed` — seeded editorial/aggregated trending-scam entries.
  Future<List<FeedItem>> getFeed() async {
    final http.Response response;
    try {
      response = await _client.get(_uri('/feed')).timeout(AppConfig.apiTimeout);
    } catch (e) {
      throw ApiException('Could not reach the server: $e');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.body, statusCode: response.statusCode);
    }
    final List<dynamic> decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.map((dynamic e) => FeedItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// `GET /feed/trending?window_days=` — live weighted-rules trending
  /// categories + province hotspot map. Explicitly NOT an AI model — see
  /// `TrendingFeedResponse.methodNote`.
  Future<TrendingFeedResponse> getTrendingFeed({int windowDays = 7}) {
    return _get(
      '/feed/trending',
      TrendingFeedResponse.fromJson,
      query: <String, String>{'window_days': '$windowDays'},
    );
  }

  /// `POST /sentinel/analyze` — multipart CSV upload (field name `file`) for
  /// the Agent Fraud Sentinel B2B anomaly detector.
  Future<SentinelAnalyzeResponse> analyzeSentinel(Uint8List fileBytes, String filename) async {
    final http.MultipartRequest request = http.MultipartRequest('POST', _uri('/sentinel/analyze'))
      ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

    final http.StreamedResponse streamed;
    try {
      streamed = await _client.send(request).timeout(AppConfig.apiTimeout);
    } catch (e) {
      throw ApiException('Could not reach the server: $e');
    }
    final http.Response response = await http.Response.fromStream(streamed);
    return SentinelAnalyzeResponse.fromJson(_decode(response));
  }

  void dispose() => _client.close();
}
