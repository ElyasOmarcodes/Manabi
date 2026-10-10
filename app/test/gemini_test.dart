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
}
