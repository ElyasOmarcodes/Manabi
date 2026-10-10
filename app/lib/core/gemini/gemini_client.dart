// Gemini REST client (generateContent with a JSON schema).
// Used only in direct mode with the user's own key, stored in secure storage.
// Port of server/src/gemini.mjs.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pipeline/answer_pipeline.dart' show JsonModel;

const _api = 'https://generativelanguage.googleapis.com/v1beta';
const fallbackModel = 'gemini-2.5-flash';

class GeminiException implements Exception {
  const GeminiException(this.code, this.message, {this.retryable = false});

  /// AUTH, QUOTA, MODEL_NOT_FOUND, BLOCKED, BAD_OUTPUT, TIMEOUT, NETWORK, HTTP
  final String code;
  final String message;
  final bool retryable;
  @override
  String toString() => 'GeminiException($code): $message';
}

/// Newest stable `gemini-X.Y-flash` (preferred) or `-pro` model.
String? pickModel(List<Map<String, dynamic>> models) {
  final re = RegExp(r'^models/gemini-(\d+)(?:\.(\d+))?-(flash|pro)$');
  final candidates = <(int, String)>[];
  for (final m in models) {
    final methods = (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? const [];
    final name = m['name'] as String? ?? '';
    final match = re.firstMatch(name);
    if (match == null || !methods.contains('generateContent')) continue;
    final score = (match.group(3) == 'flash' ? 1000000 : 0) + int.parse(match.group(1)!) * 1000 + int.parse(match.group(2) ?? '0');
    candidates.add((score, name.substring('models/'.length)));
  }
  candidates.sort((a, b) => b.$1.compareTo(a.$1));
  return candidates.isEmpty ? null : candidates.first.$2;
}

class GeminiClient implements JsonModel {
  GeminiClient({required this.apiKey, this.model, http.Client? client, this.timeout = const Duration(seconds: 90)})
      : _http = client ?? http.Client();

  final String apiKey;
  final String? model;
  final Duration timeout;
  final http.Client _http;
  String? _resolved;

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
    if (res.statusCode == 429) throw GeminiException('QUOTA', message, retryable: true);
    throw GeminiException('HTTP', message, retryable: res.statusCode >= 500);
  }

  Future<String> resolveModel() async {
    if (model != null && model!.isNotEmpty) return model!;
    if (_resolved != null) return _resolved!;
    try {
      final body = await _call('GET', '$_api/models?pageSize=1000');
      final models = (body['models'] as List?)?.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList() ?? const [];
      _resolved = pickModel(models) ?? fallbackModel;
    } on GeminiException catch (e) {
      if (e.code == 'AUTH') rethrow;
      _resolved = fallbackModel;
    }
    return _resolved!;
  }

  /// Validates the key with a cheap call (lists models).
  Future<String> check() async {
    _resolved = null;
    return resolveModel();
  }

  @override
  Future<({Map<String, dynamic> data, String model})> generateJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.2,
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
    for (var attempt = 0; attempt < 3; attempt++) {
      final name = await resolveModel();
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
        if (e.code == 'MODEL_NOT_FOUND' && (model == null || model!.isEmpty)) {
          _resolved = _resolved == fallbackModel ? null : fallbackModel;
          continue;
        }
        if (!e.retryable) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 800 * (1 << attempt)));
      }
    }
    throw last!;
  }
}
