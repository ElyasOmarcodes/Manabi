// Grounded answer pipeline – Dart port of server/src/pipeline.mjs (keep in sync).
//   plan → search Turath → compose from sources only → verify quotes.
import 'dart:async';

import '../catalog/catalog_service.dart';
import '../models/answer.dart';
import '../models/library.dart';
import '../models/scope.dart';
import '../turath/turath_client.dart';
import 'prompts.dart';
import 'quote_verifier.dart';

const insufficientMessages = {
  'ps': 'په موندل شویو منابعو کې د دې پوښتنې لپاره مستند ځواب ونه موندل شو. مهرباني وکړئ پوښتنه په بل ډول ولیکئ، یا د لټون ساحه (کتاب، مؤلف یا ډله) بدله کړئ.',
  'ar': 'لم يُعثر في المصادر المسترجعة على جواب موثَّق لهذا السؤال. جرّب صياغة أخرى للسؤال أو غيّر نطاق البحث (كتاب أو مؤلف أو تصنيف).',
  'fa': 'در منابع یافت‌شده پاسخ مستندی برای این پرسش پیدا نشد. لطفاً پرسش را به شکل دیگری بنویسید یا دامنهٔ جست‌وجو (کتاب، مؤلف یا دسته) را تغییر دهید.',
  'en': 'No documented answer to this question was found in the retrieved sources. Try rephrasing the question or changing the search scope (book, author or category).',
};

const _madhhabCategories = ['14', '15', '16', '17'];

abstract interface class JsonModel {
  Future<({Map<String, dynamic> data, String model})> generateJson(
      {required String system, required String prompt, required Map<String, dynamic> schema, double temperature = 0.2});
}

abstract interface class PassageRetriever {
  Future<RetrievedPassages> retrieve(String query, {int maxPassages = 4, int maxChars = 1600, String? bookId, String? authorId, String? categoryId});
}

class PipelineException implements Exception {
  const PipelineException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'PipelineException($code): $message';
}

class AskRequest {
  const AskRequest({required this.question, this.language = 'auto', this.fallbackLanguage = 'en', this.scope = SearchScope.all, this.history = const [], this.maxSources = 10});
  final String question;
  final String language;
  final String fallbackLanguage;
  final SearchScope scope;
  final List<HistoryTurn> history;
  final int maxSources;

  Map<String, dynamic> toJson() => {
        'question': question,
        'language': language,
        'fallbackLanguage': fallbackLanguage,
        'scope': scope.toRequest(),
        'history': [
          for (final h in history) {'question': h.question, 'summary': h.summary}
        ],
        'maxSources': maxSources,
      };
}

List<String> cleanQueries(Object? queries) {
  final seen = <String>{};
  final out = <String>[];
  for (final raw in queries is List ? queries : const []) {
    if (raw is! String) continue;
    final q = raw
        .replaceAll(RegExp('[ً-ٰٟ]'), '')
        .replaceAll(RegExp('["\'«»()\\[\\]{}]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (q.isEmpty || q.length > 60 || !seen.add(q)) continue;
    out.add(q);
  }
  return out.take(5).toList();
}

class PipelineSource {
  PipelineSource(this.key, this.passage, this.authorId, this.authorName, this.categoryId, this.categoryTitle);
  final String key;
  final PagePassage passage;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final String? categoryTitle;

  AnswerSource toPublic(int n, List<SourceQuote> quotes) => AnswerSource(
        n: n,
        bookId: passage.bookId,
        bookTitle: passage.bookTitle,
        authorId: authorId,
        authorName: authorName,
        categoryId: categoryId,
        categoryTitle: categoryTitle,
        volume: passage.volume,
        printedPage: passage.printedPage,
        internalPage: passage.internalPage,
        headings: passage.headings,
        url: passage.url,
        shamelaUrl: passage.shamelaUrl,
        citation: passage.citation,
        quotes: quotes,
        excerpt: (passage.snippet?.isNotEmpty == true ? passage.snippet! : passage.text).characters600,
      );
}

extension on String {
  String get characters600 => length <= 600 ? this : substring(0, 600);
}

final _marker = RegExp(r'\[\s*(S\d+(?:\s*[,،;]\s*S?\d+)*)\s*\]', caseSensitive: false);

/// Verifies citations and renumbers markers. Pure – unit tested.
AnswerResult finalizeAnswer({required Map<String, dynamic> composed, required List<PipelineSource> sources, required String language}) {
  final byKey = {for (final s in sources) s.key: s};
  final quotes = <String, List<SourceQuote>>{};
  for (final c in (composed['citations'] as List? ?? const []).whereType<Map>()) {
    final key = '${c['sourceId'] ?? ''}'.trim().toUpperCase();
    final source = byKey[key];
    if (source == null) continue;
    final located = locateQuote(source.passage.text, c['quote'] as String?);
    if (located == null) continue;
    final list = quotes.putIfAbsent(key, () => []);
    if (list.length < 2 && !list.any((q) => q.text == located.text)) {
      list.add(SourceQuote(text: located.text, exact: located.exact, relevance: c['relevance'] as String?));
    }
  }
  final status = composed['status'];
  final related = [for (var i = 0; i < sources.length && i < 6; i++) sources[i].toPublic(i + 1, const [])];
  if (status == 'insufficient' || !(status == 'answered' || status == 'partial') || quotes.isEmpty) {
    return AnswerResult(
      status: AnswerStatus.insufficient,
      answer: insufficientMessages[language] ?? insufficientMessages['en']!,
      detail: status == 'insufficient' && composed['answer'] is String ? (composed['answer'] as String).trim() : '',
      related: related,
    );
  }

  final order = <String>[];
  int? number(String key) {
    if (!byKey.containsKey(key)) return null;
    var n = order.indexOf(key);
    if (n < 0) {
      order.add(key);
      n = order.length - 1;
    }
    return n + 1;
  }

  final answer = '${composed['answer'] ?? ''}'.replaceAllMapped(_marker, (m) {
    final nums = <int>{};
    for (var part in m.group(1)!.split(RegExp('[,،;]'))) {
      part = part.trim().toUpperCase();
      final n = number(part.startsWith('S') ? part : 'S$part');
      if (n != null) nums.add(n);
    }
    return nums.map((n) => '[$n]').join();
  }).trim();
  for (final key in quotes.keys) {
    number(key);
  }
  final keyToNumber = {for (var i = 0; i < order.length; i++) order[i]: i + 1};
  final opinions = <Opinion>[];
  for (final o in (composed['opinions'] as List? ?? const []).whereType<Map>()) {
    final holder = '${o['holder'] ?? ''}'.trim();
    final view = '${o['view'] ?? ''}'.trim();
    final ids = (o['sourceIds'] as List? ?? const []).map((id) => keyToNumber['$id'.trim().toUpperCase()]).whereType<int>().toList();
    if (holder.isNotEmpty && view.isNotEmpty && ids.isNotEmpty) opinions.add(Opinion(holder: holder, view: view, sources: ids));
  }
  return AnswerResult(
    status: status == 'partial' ? AnswerStatus.partial : AnswerStatus.answered,
    answer: answer,
    summary: composed['summary'] is String ? (composed['summary'] as String).trim() : '',
    notes: composed['notes'] is String ? (composed['notes'] as String).trim() : '',
    sources: [for (var i = 0; i < order.length; i++) byKey[order[i]]!.toPublic(i + 1, quotes[order[i]] ?? const [])],
    opinions: opinions,
  );
}

class AnswerPipeline {
  AnswerPipeline({required this.model, required this.turath, required this.catalog});

  final JsonModel model;
  final PassageRetriever turath;
  final CatalogService catalog;

  String _scopeLabel(SearchScope scope) => [
        if (scope.bookId != null) 'book "${catalog.book(scope.bookId)?.title ?? scope.bookTitle ?? scope.bookId}"',
        if (scope.authorId != null) 'author "${catalog.author(scope.authorId)?.name ?? scope.authorName ?? scope.authorId}"',
        if (scope.categoryId != null) 'category "${catalog.category(scope.categoryId)?.title ?? scope.categoryTitle ?? scope.categoryId}"',
      ].join(', ');

  Future<(List<PipelineSource>, int)> _gather(List<String> queries, SearchScope scope, String? questionType, int maxSources) async {
    final streams = <({String query, String? bookId, String? authorId, String? categoryId, int max})>[
      for (final q in queries) (query: q, bookId: scope.bookId, authorId: scope.authorId, categoryId: scope.categoryId, max: 4),
    ];
    if (questionType == 'fiqh' && scope.isAll) {
      for (final c in _madhhabCategories) {
        for (final q in queries.take(2)) {
          streams.add((query: q, bookId: null, authorId: null, categoryId: c, max: 1));
        }
      }
    }
    // Bounded concurrency (4) like the server.
    final results = List<RetrievedPassages?>.filled(streams.length, null);
    final errors = <Object>[];
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < streams.length) {
        final i = cursor++;
        final s = streams[i];
        try {
          results[i] = await turath.retrieve(s.query, maxPassages: s.max, maxChars: 1600, bookId: s.bookId, authorId: s.authorId, categoryId: s.categoryId);
        } catch (e) {
          errors.add(e);
        }
      }
    }

    await Future.wait(List.generate(streams.length < 4 ? streams.length : 4, (_) => worker()));
    final lists = results.map((r) => r?.passages ?? const <PagePassage>[]).toList();
    final total = results.fold<int>(0, (sum, r) => sum + (r?.totalMatches ?? 0));
    final seen = <String>{};
    final picked = <PagePassage>[];
    for (var round = 0; picked.length < maxSources; round++) {
      var any = false;
      for (final list in lists) {
        if (round >= list.length) continue;
        any = true;
        final p = list[round];
        final id = '${p.bookId}:${p.internalPage ?? p.text.substring(0, p.text.length < 40 ? p.text.length : 40)}';
        if (!seen.add(id)) continue;
        picked.add(p);
        if (picked.length >= maxSources) break;
      }
      if (!any) break;
    }
    if (picked.isEmpty && errors.isNotEmpty && errors.length == streams.length) {
      throw const PipelineException('TURATH_UNAVAILABLE', 'The Turath library could not be reached');
    }
    final sources = <PipelineSource>[];
    for (var i = 0; i < picked.length; i++) {
      final p = picked[i];
      final book = catalog.book(p.bookId);
      final authorId = p.authorId ?? book?.authorId;
      final categoryId = p.categoryId ?? book?.categoryId;
      sources.add(PipelineSource('S${i + 1}', p, authorId, p.authorName ?? catalog.author(authorId)?.name, categoryId, catalog.category(categoryId)?.title));
    }
    return (sources, total);
  }

  Stream<AskEvent> ask(AskRequest request) async* {
    final started = DateTime.now();
    final question = request.question.trim();
    if (question.isEmpty) throw const PipelineException('INVALID_ARGUMENT', 'question must not be empty');
    if (question.length > 2000) throw const PipelineException('INVALID_ARGUMENT', 'question is too long');

    yield const AskStageEvent(AskStage.planning);
    final plan = await model.generateJson(
      system: planSystem,
      prompt: planPrompt(question: question, history: request.history, scopeLabel: _scopeLabel(request.scope)),
      schema: planSchema,
      temperature: 0.1,
    );
    final queries = cleanQueries(plan.data['queries']);
    final detected = plan.data['detectedLanguage'];
    final language = languageNames.containsKey(request.language)
        ? request.language
        : languageNames.containsKey(detected)
            ? detected as String
            : (languageNames.containsKey(request.fallbackLanguage) ? request.fallbackLanguage : 'en');
    yield AskPlanEvent(queries);

    AnswerResult withMeta(AnswerResult r, {int? total, String? modelName}) => AnswerResult(
          status: r.status,
          answer: r.answer,
          summary: r.summary,
          notes: r.notes,
          detail: r.detail,
          sources: r.sources,
          related: r.related,
          opinions: r.opinions,
          queries: queries,
          language: language,
          model: modelName ?? plan.model,
          totalMatches: total,
          elapsedMs: DateTime.now().difference(started).inMilliseconds,
        );

    if (queries.isEmpty) {
      yield AskResultEvent(withMeta(finalizeAnswer(composed: const {'status': 'insufficient'}, sources: const [], language: language)));
      return;
    }

    yield const AskStageEvent(AskStage.searching);
    final (sources, total) = await _gather(queries, request.scope, plan.data['questionType'] as String?, request.maxSources.clamp(3, 16));
    yield AskSourcesEvent(sources.length, total);
    if (sources.isEmpty) {
      yield AskResultEvent(withMeta(finalizeAnswer(composed: const {'status': 'insufficient'}, sources: const [], language: language), total: total));
      return;
    }

    yield const AskStageEvent(AskStage.composing);
    final languageName = languageNames[language]!;
    final composed = await model.generateJson(
      system: composeSystem(languageName),
      prompt: composePrompt(
        question: (plan.data['standaloneQuestion'] as String?)?.trim().isNotEmpty == true ? plan.data['standaloneQuestion'] as String : question,
        history: request.history,
        sources: [
          for (final s in sources)
            PromptSource(
                key: s.key,
                bookTitle: s.passage.bookTitle,
                authorName: s.authorName,
                volume: s.passage.volume,
                printedPage: s.passage.printedPage,
                headings: s.passage.headings,
                text: s.passage.text),
        ],
        languageName: languageName,
      ),
      schema: composeSchema,
      temperature: 0.2,
    );
    yield const AskStageEvent(AskStage.verifying);
    yield AskResultEvent(withMeta(finalizeAnswer(composed: composed.data, sources: sources, language: language), total: total, modelName: composed.model));
  }
}
