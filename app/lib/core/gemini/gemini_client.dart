// Gemini REST client (generateContent with a JSON schema).
// Used only in direct mode with the user's own key, stored in secure storage.
// Port of server/src/gemini.mjs.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pipeline/answer_pipeline.dart' show JsonModel, ModelTier;

const _api = 'https://generativelanguage.googleapis.com/v1beta';

class GeminiException implements Exception {
  const GeminiException(this.code, this.message, {this.retryable = false});

  /// AUTH, QUOTA, MODEL_NOT_FOUND, BLOCKED, BAD_OUTPUT, TIMEOUT, NETWORK, HTTP
  final String code;
  final String message;
  final bool retryable;
  @override
  String toString() => 'GeminiException($code): $message';
}

const _fallback = {
  ModelTier.main: ['gemini-2.5-flash', 'gemini-2.5-flash-lite'],
  ModelTier.fast: ['gemini-2.5-flash-lite', 'gemini-2.5-flash'],
};

/// Usable models for a tier, newest first, preferred kind first
/// (flash-lite for [ModelTier.fast], flash for [ModelTier.main]).
List<String> rankModels(List<Map<String, dynamic>> models, [ModelTier tier = ModelTier.main]) {
  final prefer = tier == ModelTier.fast ? const ['flash-lite', 'flash'] : const ['flash', 'flash-lite'];
  final re = RegExp(r'^(?:models/)?gemini-(\d+)(?:\.(\d+))?-(flash-lite|flash|pro)$');
  final ranked = <(int, int, int, String)>[];
  for (final m in models) {
    final methods = (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? const ['generateContent'];
    final name = m['name'] as String? ?? '';
    final match = re.firstMatch(name);
    if (match == null || !methods.contains('generateContent') || !prefer.contains(match.group(3))) continue;
    ranked.add((prefer.indexOf(match.group(3)!), int.parse(match.group(1)!), int.parse(match.group(2) ?? '0'), name.replaceFirst('models/', '')));
  }
  ranked.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2 != b.$2 ? b.$2.compareTo(a.$2) : b.$3.compareTo(a.$3));
  return [for (final r in ranked) r.$4];
}

/// Kept for compatibility: the best main model.
String? pickModel(List<Map<String, dynamic>> models) {
  final ranked = rankModels(models);
  return ranked.isEmpty ? null : ranked.first;
}

/// A 429 that names a daily/plan quota (as opposed to a short burst limit).
bool _isExhausted(String message) => RegExp('quota|exceeded your current', caseSensitive: false).hasMatch(message);

class GeminiClient implements JsonModel {
  GeminiClient({required this.apiKey, this.model, http.Client? client, this.timeout = const Duration(seconds: 90)})
      : _http = client ?? http.Client();

  final String apiKey;
  final String? model;
  final Duration timeout;
  final http.Client _http;
  List<Map<String, dynamic>>? _listed;
  final _exhausted = <String, DateTime>{};

  Future<Map<String, dynamic>> _call(String method, String url, [Object? body]) async {
    final uri = Uri.parse(url);
    final headers = {'content-type': 'application/json', 'x-goog-api-key': apiKey};
    http.Response res;
    try {
      res = await (method == 'GET' ? _http.get(uri, headers: headers) : _http.post(uri, headers: headers, body: jsonEncode(body)))
          .timeout(timeout);
    } on TimeoutException {
      throw const GeminiException('TIMEOUT', 'Gemini request timed out', retryable: true);
    } catch (e) {
      throw const GeminiException('NETWORK', 'Could not reach Gemini', retryable: true);
    }
    Map<String, dynamic> json;
    try {
      json = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      json = const {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final message = (json['error'] as Map?)?['message'] as String? ?? 'Gemini HTTP ${res.statusCode}';
    if ((res.statusCode == 400 && message.toLowerCase().contains('api key')) || res.statusCode == 401 || res.statusCode == 403) {
      throw GeminiException('AUTH', message);
    }
    if (res.statusCode == 404) throw GeminiException('MODEL_NOT_FOUND', message);
    if (res.statusCode == 429) throw GeminiException('QUOTA', message, retryable: !_isExhausted(message));
    throw GeminiException('HTTP', message, retryable: res.statusCode >= 500);
  }

  Future<List<Map<String, dynamic>>> _listModels() async {
    if (_listed != null) return _listed!;
    try {
      final body = await _call('GET', '$_api/models?pageSize=1000');
      _listed = (body['models'] as List?)?.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() ?? const [];
    } on GeminiException catch (e) {
      if (e.code == 'AUTH') rethrow;
      _listed = const [];
    }
    return _listed!;
  }

  /// Candidate models for a tier, skipping those whose quota is exhausted.
  Future<List<String>> _candidates(ModelTier tier) async {
    if (model != null && model!.isNotEmpty) return [model!];
    final unique = {...rankModels(await _listModels(), tier), ..._fallback[tier]!}.toList();
    final now = DateTime.now();
    final ready = unique.where((m) => !(_exhausted[m]?.isAfter(now) ?? false)).toList();
    return ready.isNotEmpty ? ready : unique.take(1).toList();
  }

  Future<String> resolveModel([ModelTier tier = ModelTier.main]) async => (await _candidates(tier)).first;

  /// Validates the key with a cheap call (lists models).
  Future<String> check() async {
    _listed = null;
    return resolveModel();
  }

  @override
  Future<({Map<String, dynamic> data, String model})> generateJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.2,
    ModelTier tier = ModelTier.main,
  }) async {
    final body = {
      'systemInstruction': {
        'parts': [
          {'text': system}
        ]
      },
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {'temperature': temperature, 'responseMimeType': 'application/json', 'responseSchema': schema},
    };
    GeminiException? last;
    final tried = <String>{};
    final pinned = model != null && model!.isNotEmpty;
    for (var attempt = 0; attempt < 6; attempt++) {
      final name = await resolveModel(tier);
      try {
        final result = await _call('POST', '$_api/models/${Uri.encodeComponent(name)}:generateContent', body);
        final candidates = result['candidates'] as List?;
        if (candidates == null || candidates.isEmpty) {
          final reason = (result['promptFeedback'] as Map?)?['blockReason'];
          throw GeminiException('BLOCKED', reason != null ? 'Gemini blocked the request: $reason' : 'Gemini returned no answer');
        }
        final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
        final text = parts.whereType<Map>().where((p) => p['text'] is String && p['thought'] != true).map((p) => p['text']).join();
        try {
          return (data: (jsonDecode(text) as Map).cast<String, dynamic>(), model: name);
        } catch (_) {
          throw const GeminiException('BAD_OUTPUT', 'Gemini returned malformed JSON', retryable: true);
        }
      } on GeminiException catch (e) {
        last = e;
        tried.add(name);
        if (!pinned && (e.code == 'MODEL_NOT_FOUND' || (e.code == 'QUOTA' && !e.retryable))) {
          // This model's daily quota is used up (or it is gone): move on to the next one.
          _exhausted[name] = DateTime.now().add(const Duration(hours: 1));
          if ((await _candidates(tier)).every(tried.contains)) rethrow;
          continue;
        }
        if (!e.retryable) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 800 * (1 << attempt)));
      }
    }
    throw last!;
  }
}
