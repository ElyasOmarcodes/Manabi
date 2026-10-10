// Gemini REST client (generateContent with a JSON schema).
// Used only in direct mode with the user's own key, stored in secure storage.
// Port of server/src/gemini.mjs.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../pipeline/answer_pipeline.dart' show JsonModel, ModelTier;

const _api = 'https://generativelanguage.googleapis.com/v1beta';

class GeminiException implements Exception {
  const GeminiException(this.code, this.message, {this.retryable = false, this.status});

  /// AUTH, QUOTA, MODEL_NOT_FOUND, BLOCKED, BAD_OUTPUT, TIMEOUT, NETWORK, HTTP, UNAVAILABLE
  final String code;
  final String message;
  final bool retryable;
  final int? status;
  @override
  String toString() => 'GeminiException($code): $message';
}

/// Only used when the model list cannot be read.
const _fallback = {
  ModelTier.main: ['gemini-flash-latest', 'gemini-flash-lite-latest'],
  ModelTier.fast: ['gemini-flash-lite-latest', 'gemini-flash-latest'],
};

/// Per-call time limit and overall budget of one generation, per tier.
class TierLimits {
  const TierLimits(this.call, this.total);
  final Duration call;
  final Duration total;
  static const defaults = {
    ModelTier.fast: TierLimits(Duration(seconds: 45), Duration(seconds: 100)),
    ModelTier.main: TierLimits(Duration(seconds: 70), Duration(seconds: 200)),
  };
}

/// How long a model is skipped after failing in a way another model can avoid.
const _cooldown = {
  'QUOTA': Duration(hours: 1),
  'MODEL_NOT_FOUND': Duration(hours: 24),
  'OVERLOADED': Duration(minutes: 3),
  'TIMEOUT': Duration(minutes: 5),
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
  GeminiClient({required this.apiKey, this.model, http.Client? client, this.limits = TierLimits.defaults}) : _http = client ?? http.Client();

  final String apiKey;
  final String? model;
  final Map<ModelTier, TierLimits> limits;
  final http.Client _http;
  List<Map<String, dynamic>>? _listed;

  /// Models skipped until a time, with the error that benched them.
  final _benched = <String, ({DateTime until, GeminiException error})>{};

  bool get _pinned => model != null && model!.isNotEmpty;

  Future<Map<String, dynamic>> _call(String method, String url, {Object? body, Duration timeout = const Duration(seconds: 30)}) async {
    final uri = Uri.parse(url);
    final headers = {'content-type': 'application/json', 'x-goog-api-key': apiKey};
    http.Response res;
    try {
      res = await (method == 'GET' ? _http.get(uri, headers: headers) : _http.post(uri, headers: headers, body: jsonEncode(body))).timeout(timeout);
    } on TimeoutException {
      throw GeminiException('TIMEOUT', 'Gemini did not answer within ${timeout.inSeconds}s', retryable: true);
    } catch (e) {
      throw const GeminiException('NETWORK', 'Could not reach Gemini', retryable: true);
    }
    Map<String, dynamic> json;
    try {
      json = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
    } catch (_) {
      json = const {};
    }
    final status = res.statusCode;
    if (status >= 200 && status < 300) return json;
    final message = (json['error'] as Map?)?['message'] as String? ?? 'Gemini HTTP $status';
    if ((status == 400 && message.toLowerCase().contains('api key')) || status == 401 || status == 403) {
      throw GeminiException('AUTH', message, status: status);
    }
    if (status == 404) throw GeminiException('MODEL_NOT_FOUND', message, status: status);
    if (status == 429) throw GeminiException('QUOTA', message, retryable: !_isExhausted(message), status: status);
    throw GeminiException('HTTP', message, retryable: status >= 500, status: status);
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

  /// Candidate models for a tier, best first, without benched ones.
  Future<List<String>> _candidates(ModelTier tier) async {
    if (_pinned) return [model!];
    final listed = await _listModels();
    final unique = {...rankModels(listed, tier), if (listed.isEmpty) ..._fallback[tier]!}.toList();
    final now = DateTime.now();
    return unique.where((m) => !(_benched[m]?.until.isAfter(now) ?? false)).toList();
  }

  Future<String> resolveModel([ModelTier tier = ModelTier.main]) async {
    final c = await _candidates(tier);
    return c.isNotEmpty ? c.first : _fallback[tier]!.first;
  }

  /// Validates the key with a cheap call (lists models).
  Future<String> check() async {
    _listed = null;
    return resolveModel();
  }

  /// Why a model should be skipped in favour of the next one, or null.
  static String? _benchReason(GeminiException e) {
    if (e.code == 'MODEL_NOT_FOUND') return 'MODEL_NOT_FOUND';
    if (e.code == 'QUOTA' && !e.retryable) return 'QUOTA';
    if (e.code == 'TIMEOUT') return 'TIMEOUT';
    if (e.code == 'HTTP' && (e.status ?? 0) >= 500) return 'OVERLOADED';
    return null;
  }

  /// Runs one JSON-schema constrained generation. A model that is slow,
  /// overloaded, out of quota or retired is skipped for a while and the next
  /// one is tried at once; switching does not use up the retry budget, and
  /// the whole call has a time limit.
  @override
  Future<({Map<String, dynamic> data, String model})> generateJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.2,
    ModelTier tier = ModelTier.main,
  }) async {
    final budget = limits[tier] ?? TierLimits.defaults[tier]!;
    final deadline = DateTime.now().add(budget.total);
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
    var retries = 0;
    while (true) {
      final name = (await _candidates(tier)).where((m) => !tried.contains(m)).firstOrNull;
      if (name == null) {
        // Nothing left: report the most telling reason (quota beats the rest).
        final stored = [for (final b in _benched.values) b.error];
        throw stored.where((e) => e.code == 'QUOTA').firstOrNull ??
            last ??
            stored.firstOrNull ??
            const GeminiException('UNAVAILABLE', 'No Gemini model is available right now');
      }
      try {
        final left = deadline.difference(DateTime.now());
        final remaining = left < const Duration(seconds: 5) ? const Duration(seconds: 5) : left;
        final timeout = remaining < budget.call ? remaining : budget.call;
        final result = await _call('POST', '$_api/models/${Uri.encodeComponent(name)}:generateContent', body: body, timeout: timeout);
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
      } on GeminiException catch (raw) {
        // Keep the model name with the error so the UI can show what failed.
        final e = GeminiException(raw.code, '${raw.message} [$name]', retryable: raw.retryable, status: raw.status);
        last = e;
        final reason = _pinned ? null : _benchReason(raw);
        if (reason != null) {
          _benched[name] = (until: DateTime.now().add(_cooldown[reason]!), error: e);
          tried.add(name);
        } else if (!raw.retryable) {
          throw e; // bad key, blocked prompt, invalid request: another model will not help
        } else if (retries < 2) {
          retries++;
          await Future<void>.delayed(Duration(milliseconds: 800 * (1 << retries)));
        } else if (_pinned || raw.code == 'NETWORK') {
          throw e; // a pinned model, or no connection at all
        } else {
          // The same model kept failing (e.g. malformed output): try the next one.
          tried.add(name);
          retries = 0;
        }
        if (DateTime.now().isAfter(deadline)) throw e;
      }
    }
  }
}
