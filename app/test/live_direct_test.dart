// Live check of the app's direct mode (the phone's own pipeline) with a real
// key. Runs only with MANABI_LIVE=1 and GEMINI_API_KEY (see diagnose.yml).
// ignore_for_file: avoid_print
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/catalog/catalog_service.dart';
import 'package:manabi/core/gemini/gemini_client.dart';
import 'package:manabi/core/models/answer.dart';
import 'package:manabi/core/models/scope.dart';
import 'package:manabi/core/pipeline/answer_pipeline.dart';
import 'package:manabi/core/turath/turath_client.dart';

class TimedModel implements JsonModel {
  TimedModel(this.inner);
  final GeminiClient inner;
  @override
  Future<({Map<String, dynamic> data, String model})> generateJson(
      {required String system, required String prompt, required Map<String, dynamic> schema, double temperature = 0.2, ModelTier tier = ModelTier.main}) async {
    final watch = Stopwatch()..start();
    try {
      final out = await inner.generateJson(system: system, prompt: prompt, schema: schema, temperature: temperature, tier: tier);
      print('gemini ok tier=${tier.name} model=${out.model} ${watch.elapsedMilliseconds}ms');
      return out;
    } catch (e) {
      print('gemini FAIL tier=${tier.name} ${watch.elapsedMilliseconds}ms $e');
      rethrow;
    }
  }
}

void main() {
  final key = Platform.environment['GEMINI_API_KEY'] ?? '';
  final live = Platform.environment['MANABI_LIVE'] == '1' && key.isNotEmpty;
  test('direct mode answers the reported Hanafi question', () async {
    final catalog = CatalogService.parse(File('assets/catalog/catalog.json').readAsStringSync());
    final pipeline = AnswerPipeline(model: TimedModel(GeminiClient(apiKey: key)), turath: TurathClient(), catalog: catalog);
    final watch = Stopwatch()..start();
    final events = <AskEvent>[];
    try {
      await for (final e in pipeline.ask(const AskRequest(
        question: 'د حنفي فقهې او فتاوی له نظره میت یعني مړي ته د غسل پر وخت د اوبو په وسیله استنجاء څه حکم لري، او د لوټې(مَدَر) پر وسیله څه حکم لري؟',
        language: 'ps',
        depth: 'quick',
        scope: SearchScope(categoryId: '14', categoryTitle: 'الفقه الحنفي'),
      ))) {
        events.add(e);
        if (e is AskStageEvent) print('stage ${e.stage.name} +${watch.elapsedMilliseconds}ms');
      }
    } catch (e) {
      print('pipeline error after ${watch.elapsedMilliseconds}ms: $e');
      rethrow;
    }
    final result = events.whereType<AskResultEvent>().single.result;
    print('status=${result.status.name} sources=${result.sources.length} model=${result.model} ${watch.elapsedMilliseconds}ms');
    for (final s in result.sources) {
      print('  ${s.bookTitle} · ${s.authorName} · ج${s.volume} ص${s.printedPage}');
    }
  }, skip: live ? false : 'live only', timeout: const Timeout(Duration(minutes: 8)));
}
