// Gemini REST client (generateContent with a JSON schema).
// Used only in direct mode with the user's own key, stored in secure storage.
// Port of server/src/gemini.mjs.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/answer.dart' show TokenUsage;
import '../pipeline/answer_pipeline.dart' show JsonModel, ModelReply, ModelTier;

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
  const TierLimits(this.call, this.total, [this.idle = const Duration(seconds: 30)]);
  final Duration call;
  final Duration total;

  /// Longest silence (no bytes) before a call counts as stalled: a dead
  /// connection is noticed in seconds, not at the end of [call].
  final Duration idle;
  static const defaults = {
    ModelTier.fast: TierLimits(Duration(seconds: 40), Duration(seconds: 90), Duration(seconds: 20)),
    ModelTier.main: TierLimits(Duration(seconds: 60), Duration(seconds: 150), Duration(seconds: 35)),
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

/// A text model the key can call, with a rough token-cost class.
class ModelInfo {
  const ModelInfo(this.id, this.name, {this.cost = 'medium', this.input = 0, this.output = 0});
  final String id;
  final String name;

  /// 'high', 'medium' or 'low'.
  final String cost;
  final int input;
  final int output;

  factory ModelInfo.fromJson(Map<String, dynamic> m) {
    final id = '${m['id'] ?? ''}';
    int n(Object? v) => v is num ? v.toInt() : 0;
    return ModelInfo(id, '${m['name'] ?? id}', cost: m['cost'] is String ? m['cost'] as String : modelCost(id), input: n(m['input']), output: n(m['output']));
  }
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'cost': cost, 'input': input, 'output': output};
}

/// Rough token cost of a model, from its name.
String modelCost(String id) {
  if (RegExp(r'gemma|flash-lite|nano|-8b\b').hasMatch(id)) return 'low';
  if (RegExp(r'pro|ultra|deep-?think').hasMatch(id)) return 'high';
  return 'medium';
}

/// Gemma takes no system instruction or JSON schema: both go in the prompt.
bool isGemma(String id) => RegExp(r'^(?:models/)?gemma').hasMatch(id);

final _notChat = RegExp(r'embed|aqa|imagen|veo|tts|image|audio|live|learnlm|robotics|computer-use|lyria|banana|gemini-diffusion');

/// Text models from a model listing, Gemini first, newest and strongest first.
List<ModelInfo> chatModels(List<Map<String, dynamic>> models) {
  double version(String id) => double.tryParse(RegExp(r'-(\d+(?:\.\d+)?)').firstMatch(id)?.group(1) ?? '') ?? 0;
  const rank = {'high': 0, 'medium': 1, 'low': 2};
  final out = <ModelInfo>[];
  for (final m in models) {
    final methods = (m['supportedGenerationMethods'] as List?)?.cast<String>() ?? const ['generateContent'];
    final id = '${m['name'] ?? ''}'.replaceFirst('models/', '');
    if (!methods.contains('generateContent') || !RegExp(r'^(gemini|gemma)-').hasMatch(id) || _notChat.hasMatch(id)) continue;
    int n(Object? v) => v is num ? v.toInt() : 0;
    out.add(ModelInfo(id, '${m['displayName'] ?? id}', cost: modelCost(id), input: n(m['inputTokenLimit']), output: n(m['outputTokenLimit'])));
  }
  int fam(ModelInfo x) => x.id.startsWith('gemma') ? 1 : 0;
  out.sort((a, b) {
    if (fam(a) != fam(b)) return fam(a) - fam(b);
    final v = version(b.id).compareTo(version(a.id));
    if (v != 0) return v;
    final c = rank[a.cost]! - rank[b.cost]!;
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out;
}

/// The JSON object in a reply, also when it is wrapped in prose or fences.
Map<String, dynamic> parseJsonReply(String text) {
  try {
    return (jsonDecode(text) as Map).cast<String, dynamic>();
  } catch (_) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start >= 0 && end > start) return (jsonDecode(text.substring(start, end + 1)) as Map).cast<String, dynamic>();
    rethrow;
  }
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
    final json = _json(utf8.decode(res.bodyBytes));
    final status = res.statusCode;
    if (status >= 200 && status < 300) return json;
    throw _failure(status, json);
  }

  static Map<String, dynamic> _json(String text) {
    try {
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } catch (_) {
      return const {};
    }
  }

  static GeminiException _failure(int status, Map<String, dynamic> json) {
    final message = (json['error'] as Map?)?['message'] as String? ?? 'Gemini HTTP $status';
    if ((status == 400 && message.toLowerCase().contains('api key')) || status == 401 || status == 403) {
      return GeminiException('AUTH', message, status: status);
    }
    if (status == 404) return GeminiException('MODEL_NOT_FOUND', message, status: status);
    if (status == 429) return GeminiException('QUOTA', message, retryable: !_isExhausted(message), status: status);
    return GeminiException('HTTP', message, retryable: status >= 500, status: status);
  }

  /// A streamed (alt=sse) call; [onText] gets the answer text as it grows.
  Future<({String text, Map<String, dynamic>? usage, String? blockReason, bool finished})> _stream(
      String url, Object body, Duration timeout, void Function(String text) onText, {Duration idle = const Duration(seconds: 30)}) async {
    final request = http.Request('POST', Uri.parse(url))
      ..headers.addAll({'content-type': 'application/json', 'x-goog-api-key': apiKey})
      ..body = jsonEncode(body);
    Future<({String text, Map<String, dynamic>? usage, String? blockReason, bool finished})> run() async {
      final http.StreamedResponse res;
      try {
        res = await _http.send(request).timeout(idle);
      } on TimeoutException {
        throw GeminiException('TIMEOUT', 'Gemini did not start answering within ${idle.inSeconds}s', retryable: true);
      } catch (_) {
        throw const GeminiException('NETWORK', 'Could not reach Gemini', retryable: true);
      }
      if (res.statusCode < 200 || res.statusCode >= 300) throw _failure(res.statusCode, _json(await res.stream.bytesToString()));
      final text = StringBuffer();
      Map<String, dynamic>? usage;
      String? blocked;
      var finished = false;
      try {
        // Silence longer than [idle] means a stalled connection.
        void take(Map<String, dynamic> chunk) {
          if (chunk['usageMetadata'] is Map) usage = (chunk['usageMetadata'] as Map).cast<String, dynamic>();
          final reason = (chunk['promptFeedback'] as Map?)?['blockReason'];
          if (reason != null) blocked = '$reason';
          final candidates = chunk['candidates'] as List?;
          if (candidates == null || candidates.isEmpty) return;
          finished = true;
          final parts = ((candidates.first as Map)['content'] as Map?)?['parts'] as List? ?? const [];
          final piece = parts.whereType<Map>().where((p) => p['text'] is String && p['thought'] != true).map((p) => p['text']).join();
          if (piece.isNotEmpty) {
            text.write(piece);
            onText(text.toString());
          }
        }

        // Server-sent events; a plain JSON body (some proxies) is read whole.
        final plain = StringBuffer();
        var events = 0;
        await for (final line in res.stream.timeout(idle).transform(utf8.decoder).transform(const LineSplitter())) {
          if (!line.startsWith('data:')) {
            if (events == 0) plain.writeln(line);
            continue;
          }
          events++;
          take(_json(line.substring(5).trim()));
        }
        if (events == 0 && plain.toString().trim().isNotEmpty) {
          final whole = jsonDecode(plain.toString());
          for (final c in whole is List ? whole : [whole]) {
            if (c is Map) take(c.cast<String, dynamic>());
          }
        }
      } on GeminiException {
        rethrow;
      } on TimeoutException {
        throw GeminiException('TIMEOUT', 'Gemini stopped sending for ${idle.inSeconds}s', retryable: true);
      } catch (_) {
        throw const GeminiException('NETWORK', 'The connection to Gemini was interrupted', retryable: true);
      }
      return (text: text.toString(), usage: usage, blockReason: blocked, finished: finished);
    }

    try {
      return await run().timeout(timeout);
    } on TimeoutException {
      throw GeminiException('TIMEOUT', 'Gemini did not answer within ${timeout.inSeconds}s', retryable: true);
    }
  }

  /// Thinking kept short on Flash models: most of the latency was thinking.
  final _noThinking = <String>{};
  Map<String, dynamic>? _thinkingFor(String name) {
    final m = RegExp(r'^gemini-(\d+)(?:\.(\d+))?-(flash-lite|flash|pro)$').firstMatch(name);
    if (m == null || m.group(3) != 'flash' || _noThinking.contains(name)) return null;
    final major = int.parse(m.group(1)!);
    final minor = int.parse(m.group(2) ?? '0');
    if (major >= 3) return {'thinkingLevel': 'low'};
    if (major == 2 && minor >= 5) return {'thinkingBudget': 1024};
    return null;
  }

  static TokenUsage _usage(Object? meta) {
    final m = meta is Map ? meta : const {};
    int n(Object? v) => v is num ? v.toInt() : 0;
    return TokenUsage(input: n(m['promptTokenCount']), output: n(m['candidatesTokenCount']), thoughts: n(m['thoughtsTokenCount']), calls: 1, peak: n(m['promptTokenCount']));
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
  Future<List<String>> _candidates(ModelTier tier, [String? prefer]) async {
    if (_pinned) return [model!];
    final listed = await _listModels();
    // A model the user picked (and the key can call) comes first.
    final picked = prefer != null && chatModels(listed).any((m) => m.id == prefer);
    final unique = {if (picked) prefer, ...rankModels(listed, tier), if (listed.isEmpty) ..._fallback[tier]!}.toList();
    final now = DateTime.now();
    return unique.where((m) => !(_benched[m]?.until.isAfter(now) ?? false)).toList();
  }

  Future<String> resolveModel([ModelTier tier = ModelTier.main]) async {
    final c = await _candidates(tier);
    return c.isNotEmpty ? c.first : _fallback[tier]!.first;
  }

  /// The text models the key can call (empty when they cannot be listed).
  Future<List<ModelInfo>> chatModelList() async => chatModels(await _listModels());

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
  /// the whole call has a time limit. With [onText] the reply is streamed.
  @override
  Future<ModelReply> generateJson({
    required String system,
    required String prompt,
    required Map<String, dynamic> schema,
    double temperature = 0.2,
    ModelTier tier = ModelTier.main,
    void Function(String text)? onText,
    String? prefer,
  }) async {
    final budget = limits[tier] ?? TierLimits.defaults[tier]!;
    final deadline = DateTime.now().add(budget.total);
    Map<String, dynamic> bodyFor(String name) {
      if (isGemma(name)) {
        final text = '$system\n\n$prompt\n\nReply with one JSON object only (no prose, no code fences) that follows this JSON schema:\n${jsonEncode(schema)}';
        return {
          'contents': [
            {
              'role': 'user',
              'parts': [
                {'text': text}
              ]
            }
          ],
          'generationConfig': {'temperature': temperature},
        };
      }
      final thinking = _thinkingFor(name);
      return {
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
        'generationConfig': {
          'temperature': temperature,
          'responseMimeType': 'application/json',
          'responseSchema': schema,
          'thinkingConfig': ?thinking,
        },
      };
    }

    GeminiException? last;
    final tried = <String>{};
    var retries = 0;
    while (true) {
      final name = (await _candidates(tier, prefer)).where((m) => !tried.contains(m)).firstOrNull;
      if (name == null) {
        // Nothing left: report the most telling reason (quota beats the rest).
        final stored = [for (final b in _benched.values) b.error];
        throw stored.where((e) => e.code == 'QUOTA').firstOrNull ??
            last ??
            stored.firstOrNull ??
            const GeminiException('UNAVAILABLE', 'No Gemini model is available right now');
      }
      final body = bodyFor(name);
      try {
        final left = deadline.difference(DateTime.now());
        final remaining = left < const Duration(seconds: 5) ? const Duration(seconds: 5) : left;
        final timeout = remaining < budget.call ? remaining : budget.call;
        final model = Uri.encodeComponent(name);
        String text;
        Object? usage;
        // Always streamed, so a stalled call is caught by the idle watchdog.
        {
          final out = await _stream('$_api/models/$model:streamGenerateContent?alt=sse', body, timeout, onText ?? (_) {}, idle: budget.idle);
          if (!out.finished) {
            throw GeminiException('BLOCKED', out.blockReason != null ? 'Gemini blocked the request: ${out.blockReason}' : 'Gemini returned no answer');
          }
          text = out.text;
          usage = out.usage;
        }
        try {
          return (data: parseJsonReply(text), model: name, usage: _usage(usage));
        } catch (_) {
          throw const GeminiException('BAD_OUTPUT', 'Gemini returned malformed JSON', retryable: true);
        }
      } on GeminiException catch (raw) {
        // A model that does not accept the thinking setting: ask again without it.
        final config = body['generationConfig'] as Map;
        if (raw.status == 400 && config.containsKey('thinkingConfig') && raw.message.toLowerCase().contains('think')) {
          _noThinking.add(name);
          continue;
        }
        // The picked model refused the request: the usual models take over.
        if (name == prefer && raw.status == 400) {
          tried.add(name);
          continue;
        }
        // Keep the model name with the error so the UI can show what failed.
        final e = GeminiException(raw.code, '${raw.message} [$name]', retryable: raw.retryable, status: raw.status);
        last = e;
        final reason = _pinned ? null : _benchReason(raw);
        if (reason != null) {
          _benched[name] = (until: DateTime.now().add(_cooldown[reason]!), error: e);
          tried.add(name);
        } else if (!raw.retryable) {
          throw e; // bad key, blocked prompt, invalid request: another model will not help
        } else if (retries < (raw.code == 'NETWORK' ? 4 : 2)) {
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
