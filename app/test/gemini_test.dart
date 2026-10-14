import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manabi/core/gemini/gemini_client.dart';
import 'package:manabi/core/pipeline/answer_pipeline.dart';

const _models = [
  {'name': 'models/gemini-2.5-flash', 'supportedGenerationMethods': ['generateContent']},
  {'name': 'models/gemini-3.0-flash', 'supportedGenerationMethods': ['generateContent']},
  {'name': 'models/gemini-3.0-flash-lite', 'supportedGenerationMethods': ['generateContent']},
  {'name': 'models/text-embedding-004', 'supportedGenerationMethods': ['embedContent']},
];

http.Response _json(int status, Object body) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('models are ranked per tier', () {
    expect(rankModels(_models), ['gemini-3.0-flash', 'gemini-2.5-flash', 'gemini-3.0-flash-lite']);
    expect(rankModels(_models, ModelTier.fast).first, 'gemini-3.0-flash-lite');
  });

  test('an exhausted daily quota moves on to the next model', () async {
    final calls = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/models')) return _json(200, {'models': _models});
      final name = Uri.decodeComponent(path.split('/models/').last.split(':').first);
      calls.add(name);
      if (name == 'gemini-3.0-flash') {
        return _json(429, {
          'error': {'message': 'You exceeded your current quota. limit: 20'}
        });
      }
      return _json(200, {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode({'ok': name})}
              ]
            }
          }
        ]
      });
    });
    final gemini = GeminiClient(apiKey: 'k', client: client);
    final first = await gemini.generateJson(system: 's', prompt: 'p', schema: const {});
    expect(first.model, 'gemini-2.5-flash');
    expect(calls, ['gemini-3.0-flash', 'gemini-2.5-flash']);
    await gemini.generateJson(system: 's', prompt: 'p', schema: const {});
    expect(calls.last, 'gemini-2.5-flash');
    expect(await gemini.resolveModel(), 'gemini-2.5-flash');
  });

  List<Map<String, Object>> listed(List<String> names) => [
        for (final n in names) {'name': 'models/$n', 'supportedGenerationMethods': ['generateContent']}
      ];
  http.Response ok() => _json(200, {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': '{"ok":true}'}
              ]
            }
          }
        ]
      });

  test('quota, retired and overloaded models are skipped until a working one answers', () async {
    // Seen live: every Flash model out of quota or overloaded, an old one
    // retired, Flash-Lite fine. Switching must not run out of attempts.
    final models = listed(['gemini-3.8-flash', 'gemini-3.7-flash', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-2.5-flash', 'gemini-3.5-flash-lite']);
    final calls = <String>[];
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/models')) return _json(200, {'models': models});
      final name = Uri.decodeComponent(path.split('/models/').last.split(':').first);
      calls.add(name);
      if (name == 'gemini-3.6-flash') {
        return _json(503, {
          'error': {'message': 'This model is currently experiencing high demand.'}
        });
      }
      if (name == 'gemini-2.5-flash') {
        return _json(404, {
          'error': {'message': 'This model models/gemini-2.5-flash is no longer available to new users.'}
        });
      }
      if (name.endsWith('-flash')) {
        return _json(429, {
          'error': {'message': 'You exceeded your current quota'}
        });
      }
      return ok();
    });
    final gemini = GeminiClient(apiKey: 'k', client: client);
    final out = await gemini.generateJson(system: 's', prompt: 'p', schema: const {});
    expect(out.model, 'gemini-3.5-flash-lite');
    expect(calls, ['gemini-3.8-flash', 'gemini-3.7-flash', 'gemini-3.6-flash', 'gemini-3.5-flash', 'gemini-2.5-flash', 'gemini-3.5-flash-lite']);
    calls.clear();
    await gemini.generateJson(system: 's', prompt: 'p', schema: const {});
    expect(calls, ['gemini-3.5-flash-lite'], reason: 'failed models stay benched');
  });

  test('a model that times out is skipped for the next one', () async {
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/models')) return _json(200, {'models': listed(['gemini-3.8-flash', 'gemini-3.5-flash-lite'])});
      if (request.url.path.contains('3.8-flash')) await Future<void>.delayed(const Duration(seconds: 2));
      return ok();
    });
    const quick = TierLimits(Duration(milliseconds: 100), Duration(seconds: 5));
    final gemini = GeminiClient(apiKey: 'k', client: client, limits: const {ModelTier.main: quick, ModelTier.fast: quick});
    final out = await gemini.generateJson(system: 's', prompt: 'p', schema: const {});
    expect(out.model, 'gemini-3.5-flash-lite');
  });

  test('a call frozen while the app was in the background is reported as interrupted, and no model stays benched', () async {
    var slow = true;
    final client = MockClient((request) async {
      if (request.url.path.endsWith('/models')) return _json(200, {'models': listed(['gemini-3.8-flash', 'gemini-3.5-flash-lite'])});
      if (slow) {
        GeminiClient.appPaused();
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      return ok();
    });
    const quick = TierLimits(Duration(milliseconds: 100), Duration(seconds: 5));
    final gemini = GeminiClient(apiKey: 'k', client: client, limits: const {ModelTier.main: quick, ModelTier.fast: quick});
    await expectLater(gemini.generateJson(system: 's', prompt: 'p', schema: const {}), throwsA(isA<GeminiException>().having((e) => e.code, 'code', 'NETWORK')));
    GeminiClient.appResumed();
    slow = false;
    final out = await gemini.generateJson(system: 's', prompt: 'p', schema: const {});
    expect(out.model, 'gemini-3.8-flash', reason: 'the best model is used again once the app is back');
  });

  test('when every model is out of quota the quota error is reported', () async {
    final client = MockClient((request) async => request.url.path.endsWith('/models')
        ? _json(200, {'models': listed(['gemini-3.8-flash', 'gemini-3.5-flash-lite'])})
        : _json(429, {
            'error': {'message': 'You exceeded your current quota'}
          }));
    final gemini = GeminiClient(apiKey: 'k', client: client);
    expect(gemini.generateJson(system: 's', prompt: 'p', schema: const {}), throwsA(isA<GeminiException>().having((e) => e.code, 'code', 'QUOTA')));
  });
}
