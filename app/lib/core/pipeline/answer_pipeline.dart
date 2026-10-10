// Grounded answer pipeline (v2) – Dart port of server/src/pipeline.mjs (keep in sync).
//   plan → search (general, per book, per school) → read & rank (+1 follow-up
//   round) → compose with inline quotes → verify every quote.
import 'dart:async';

import '../catalog/catalog_service.dart';
import '../models/answer.dart';
import '../models/library.dart';
import '../models/scope.dart';
import '../turath/excerpt.dart';
import 'prompts.dart';
import 'quote_verifier.dart';

const insufficientMessages = {
  'ps': 'په موندل شویو منابعو کې د دې پوښتنې لپاره مستند ځواب ونه موندل شو. مهرباني وکړئ پوښتنه په بل ډول ولیکئ، یا د لټون ساحه (کتاب، مؤلف یا ډله) بدله کړئ.',
  'ar': 'لم يُعثر في المصادر المسترجعة على جواب موثَّق لهذا السؤال. جرّب صياغة أخرى للسؤال أو غيّر نطاق البحث (كتاب أو مؤلف أو تصنيف).',
  'fa': 'در منابع یافت‌شده پاسخ مستندی برای این پرسش پیدا نشد. لطفاً پرسش را به شکل دیگری بنویسید یا دامنهٔ جست‌وجو (کتاب، مؤلف یا دسته) را تغییر دهید.',
  'en': 'No documented answer to this question was found in the retrieved sources. Try rephrasing the question or changing the search scope (book, author or category).',
};

const madhhabCategory = {'hanafi': '14', 'maliki': '15', 'shafii': '16', 'hanbali': '17'};

final _madhhabNames = {
  'hanafi': RegExp('حنف|احناف|أحناف|hanaf', caseSensitive: false),
  'maliki': RegExp('مالكي|مالكية|malik(?:i|ite)', caseSensitive: false),
  'shafii': RegExp('شافع|shafi', caseSensitive: false),
  'hanbali': RegExp('حنبل|hanbal', caseSensitive: false),
};

/// Schools the question names explicitly (a safety net for the planner).
List<String> namedMadhhabs(String text) => [for (final e in _madhhabNames.entries) if (e.value.hasMatch(text)) e.key];

/// How widely a question is researched; port of LIMITS / DEPTHS in
/// server/src/pipeline.mjs.
class Limits {
  const Limits({
    this.generalQueries = 6,
    this.hitsPerGeneral = 8,
    this.requestedBooks = 3,
    this.queriesPerRequested = 4,
    this.hitsPerRequested = 4,
    this.referenceBooks = 5,
    this.queriesPerReference = 2,
    this.hitsPerReference = 3,
    this.queriesPerMadhhab = 3,
    this.hitsPerMadhhab = 4,
    this.maxSearches = 40,
    this.maxCandidates = 64,
    this.maxSelected = 14,
    this.continuationPages = 6,
    this.followUpRounds = 1,
  });
  final int generalQueries;
  final int hitsPerGeneral;
  final int requestedBooks;
  final int queriesPerRequested;
  final int hitsPerRequested;
  final int referenceBooks;
  final int queriesPerReference;
  final int hitsPerReference;
  final int queriesPerMadhhab;
  final int hitsPerMadhhab;
  final int maxSearches;
  final int maxCandidates;
  final int maxSelected;
  final int continuationPages;
  final int followUpRounds;

  static const excerptChars = 650;
  static const sourceChars = 2400;

  static const standard = Limits();
  static const quick = Limits(
      generalQueries: 3, hitsPerGeneral: 6, referenceBooks: 3, queriesPerMadhhab: 2, maxSearches: 18, maxCandidates: 32, maxSelected: 6, continuationPages: 2, followUpRounds: 0);
  static const deep = Limits(
      generalQueries: 8,
      hitsPerGeneral: 10,
      referenceBooks: 6,
      queriesPerReference: 3,
      queriesPerMadhhab: 4,
      hitsPerMadhhab: 5,
      maxSearches: 64,
      maxCandidates: 96,
      maxSelected: 18,
      continuationPages: 10,
      followUpRounds: 2);

  static Limits forDepth(String? depth) => switch (depth) {
        'quick' => quick,
        'deep' => deep,
        _ => standard,
      };
}

/// `fast` is used for planning and ranking, `main` for writing the answer.
enum ModelTier { fast, main }

abstract interface class JsonModel {
  Future<({Map<String, dynamic> data, String model})> generateJson(
      {required String system,
      required String prompt,
      required Map<String, dynamic> schema,
      double temperature = 0.2,
      ModelTier tier = ModelTier.main});
}

class SearchHits {
  const SearchHits(this.items, this.snippets, this.totalMatches);
  final List<PagePassage> items;

  /// Raw Turath snippets (with <em> match markup), parallel to [items].
  final List<String?> snippets;
  final int totalMatches;
}

abstract interface class PassageSearch {
  Future<SearchHits> searchHits(String query, {String? bookId, String? authorId, String? categoryId});
  Future<PagePassage> getPage(String bookId, int page);
}

class PipelineException implements Exception {
  const PipelineException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'PipelineException($code): $message';
}

class AskRequest {
  const AskRequest({
    required this.question,
    this.language = 'auto',
    this.fallbackLanguage = 'en',
    this.scope = SearchScope.all,
    this.history = const [],
    this.maxSources,
    this.depth = 'standard',
    this.requestId,
  });
  final String question;
  final String language;
  final String fallbackLanguage;
  final SearchScope scope;
  final List<HistoryTurn> history;

  /// Optional cap on sources; by default the research depth decides.
  final int? maxSources;

  /// 'quick', 'standard' or 'deep'.
  final String depth;

  /// Lets the server hand back an answer whose stream was interrupted.
  final String? requestId;

  Map<String, dynamic> toJson() => {
        'question': question,
        'language': language,
        'fallbackLanguage': fallbackLanguage,
        'scope': scope.toRequest(),
        'history': [
          for (final h in history) {'question': h.question, 'summary': h.summary, 'books': h.books}
        ],
        'maxSources': ?maxSources,
        'depth': depth,
        'requestId': ?requestId,
      };
}

List<String> cleanQueries(Object? queries, {int max = 8}) {
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
  return out.take(max).toList();
}

List<String> _titles(Object? v, int max) =>
    (v is List ? v : const []).whereType<String>().map((t) => t.trim()).where((t) => t.isNotEmpty).toSet().take(max).toList();

final _derivative = RegExp(r'^(تكملة|مختصر|تهذيب|فهرس|فهارس|تخريج|ترتيب|زوائد|منتخب|تلخيص|قرة عيون|دراسة|التعليق)');
String _strip(String s) => s
    .replaceAll(RegExp('[ً-ٰٟـ]'), '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll('ى', 'ي')
    .trim();

/// Resolves free-text book titles to catalog ids, preferring main works over
/// supplements/abridgements (same ranking as the server).
List<String> resolveBooks(List<String> titles, CatalogService catalog, {int perTitle = 1}) {
  final ids = <String>[];
  for (final title in titles) {
    var found = catalog.findBooks(title, limit: 12);
    if (found.isEmpty) {
      final short = title.replaceFirst(RegExp(r'\s+(ل|لل|لابن|للإمام)\S*(\s+\S+)?$'), '').trim();
      if (short.isNotEmpty && short != title) found = catalog.findBooks(short, limit: 12);
    }
    final wantDerivative = _derivative.hasMatch(_strip(title));
    final ranked = [
      for (var i = 0; i < found.length; i++)
        (
          found[i],
          i + (!wantDerivative && _derivative.hasMatch(_strip(found[i].title)) ? 100 : 0) + ((_strip(found[i].title).length - _strip(title).length).clamp(0, 10000)) / 40
        ),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (b, _) in ranked.take(perTitle)) {
      if (!ids.contains(b.id)) ids.add(b.id);
    }
  }
  return ids;
}

class PlannedSearch {
  const PlannedSearch(this.query, this.take, this.kind, {this.bookId, this.authorId, this.categoryId});
  final String query;
  final int take;
  final String kind;
  final String? bookId;
  final String? authorId;
  final String? categoryId;
}

List<PlannedSearch> searchPlan({
  required List<String> queries,
  SearchScope scope = SearchScope.all,
  List<String> madhhabs = const [],
  List<String> requestedBookIds = const [],
  List<String> referenceBookIds = const [],
  Limits limits = Limits.standard,
}) {
  final userScoped = !scope.isAll;
  final plan = <PlannedSearch>[
    for (final q in queries.take(limits.generalQueries))
      PlannedSearch(q, limits.hitsPerGeneral, 'general', bookId: scope.bookId, authorId: scope.authorId, categoryId: scope.categoryId),
  ];
  if (!userScoped) {
    for (final id in requestedBookIds.take(limits.requestedBooks)) {
      for (final q in queries.take(limits.queriesPerRequested)) {
        plan.add(PlannedSearch(q, limits.hitsPerRequested, 'requested', bookId: id));
      }
    }
    for (final id in referenceBookIds.take(limits.referenceBooks)) {
      for (final q in queries.take(limits.queriesPerReference)) {
        plan.add(PlannedSearch(q, limits.hitsPerReference, 'reference', bookId: id));
      }
    }
    for (final m in madhhabs) {
      final c = madhhabCategory[m];
      if (c == null) continue;
      for (final q in queries.take(limits.queriesPerMadhhab)) {
        plan.add(PlannedSearch(q, limits.hitsPerMadhhab, 'madhhab', categoryId: c));
      }
    }
  }
  return plan.take(limits.maxSearches).toList();
}

/// A retrieved page, as candidate and as numbered source.
class PipelineSource {
  PipelineSource({
    required this.id,
    required this.passage,
    required this.excerpt,
    required this.text,
    this.authorId,
    this.authorName,
    this.categoryId,
    this.categoryTitle,
    this.key = '',
  });
  final String id;
  final PagePassage passage;
  final String excerpt;
  final String text;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final String? categoryTitle;
  String key;

  PipelineSource withKey(String k) => PipelineSource(
      id: id,
      passage: passage,
      excerpt: excerpt,
      text: text,
      authorId: authorId,
      authorName: authorName,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      key: k);

  PromptSource prompt({required bool full}) => PromptSource(
        key: key,
        bookTitle: passage.bookTitle,
        authorName: authorName,
        categoryTitle: categoryTitle,
        volume: passage.volume,
        printedPage: passage.printedPage,
        headings: passage.headings,
        text: full ? text : excerpt,
      );

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
        // The passage around the search match, shown when no quote was verified.
        excerpt: (excerpt.trim().isNotEmpty ? excerpt : text).let((s) => s.length <= 700 ? s : s.substring(0, 700)),
      );
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}

PipelineSource _candidate(PagePassage p, String? rawSnippet, CatalogService catalog) {
  final book = catalog.book(p.bookId);
  final authorId = p.authorId ?? book?.authorId;
  final categoryId = p.categoryId ?? book?.categoryId;
  final snip = rawSnippet ?? p.snippet;
  return PipelineSource(
    id: '${p.bookId}:${p.internalPage ?? p.text.substring(0, p.text.length < 40 ? p.text.length : 40)}',
    passage: p,
    excerpt: boundText(p.text, Limits.excerptChars, snip),
    text: boundText(p.text, Limits.sourceChars, snip),
    authorId: authorId,
    authorName: p.authorName ?? catalog.author(authorId)?.name,
    categoryId: categoryId,
    categoryTitle: catalog.category(categoryId)?.title,
  );
}

final _marker = RegExp(r'\[\s*(S\d+(?:\s*[,،;]\s*S?\d+)*)\s*\]', caseSensitive: false);
final _quoteMarker = RegExp(r'\[\[\s*(Q\d+)\s*\]\]', caseSensitive: false);

/// Verifies citations, renders inline quotes and renumbers markers. Pure – unit tested.
AnswerResult finalizeAnswer({required Map<String, dynamic> composed, required List<PipelineSource> sources, required String language}) {
  final byKey = {for (final s in sources) s.key: s};
  final quotes = <String, List<SourceQuote>>{};
  final inline = <String, ({String key, String text})>{};
  final citations = (composed['citations'] as List? ?? const []).whereType<Map>().toList();
  for (var i = 0; i < citations.length; i++) {
    final c = citations[i];
    final key = '${c['sourceId'] ?? ''}'.trim().toUpperCase();
    final source = byKey[key];
    if (source == null) continue;
    final located = locateQuote(source.text, c['quote'] as String?);
    if (located == null) continue;
    final qid = '${c['id'] ?? 'Q${i + 1}'}'.trim().toUpperCase();
    inline[qid] = (key: key, text: located.text);
    final list = quotes.putIfAbsent(key, () => []);
    if (list.length < 3 && !list.any((q) => q.text == located.text)) {
      list.add(SourceQuote(text: located.text, exact: located.exact, relevance: c['relevance'] as String?));
    }
  }
  final status = composed['status'];
  final related = [for (var i = 0; i < sources.length && i < 6; i++) sources[i].toPublic(i + 1, const [])];
  if (status == 'insufficient' || !(status == 'answered' || status == 'partial') || quotes.isEmpty) {
    return AnswerResult(
      status: AnswerStatus.insufficient,
      answer: insufficientMessages[language] ?? insufficientMessages['en']!,
      detail: status == 'insufficient' && composed['answer'] is String ? (composed['answer'] as String).replaceAll(_quoteMarker, '').trim() : '',
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

  final answer = '${composed['answer'] ?? ''}'
      .replaceAllMapped(_quoteMarker, (m) {
        final q = inline[m.group(1)!.toUpperCase()];
        if (q == null) return '';
        return '\n> ${q.text.replaceAll(RegExp(r'\s*\n\s*'), ' ')} [S${q.key.substring(1)}]\n';
      })
      .replaceAllMapped(_marker, (m) {
        final nums = <int>{};
        for (var part in m.group(1)!.split(RegExp('[,،;]'))) {
          part = part.trim().toUpperCase();
          final n = number(part.startsWith('S') ? part : 'S$part');
          if (n != null) nums.add(n);
        }
        return nums.map((n) => '[$n]').join();
      })
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
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
  final PassageSearch turath;
  final CatalogService catalog;

  String _scopeLabel(SearchScope scope) => [
        if (scope.bookId != null) 'book "${catalog.book(scope.bookId)?.title ?? scope.bookTitle ?? scope.bookId}"',
        if (scope.authorId != null) 'author "${catalog.author(scope.authorId)?.name ?? scope.authorName ?? scope.authorId}"',
        if (scope.categoryId != null) 'category "${catalog.category(scope.categoryId)?.title ?? scope.categoryTitle ?? scope.categoryId}"',
      ].join(', ');

  /// Runs searches (bounded concurrency 6) and merges hits into a de-duplicated pool.
  Future<({List<PipelineSource> candidates, int total, bool failed})> _collect(List<PlannedSearch> plan, {List<PipelineSource> existing = const [], Limits limits = Limits.standard}) async {
    final results = List<SearchHits?>.filled(plan.length, null);
    var failures = 0;
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < plan.length) {
        final i = cursor++;
        final s = plan[i];
        try {
          results[i] = await turath.searchHits(s.query, bookId: s.bookId, authorId: s.authorId, categoryId: s.categoryId);
        } catch (_) {
          failures++;
        }
      }
    }

    await Future.wait(List.generate(plan.length < 6 ? plan.length : 6, (_) => worker()));
    final total = results.fold<int>(0, (sum, r) => sum + (r?.totalMatches ?? 0));
    final order = [for (var i = 0; i < plan.length; i++) i]..sort((a, b) => (plan[b].kind == 'requested' ? 1 : 0) - (plan[a].kind == 'requested' ? 1 : 0));
    final seen = {for (final c in existing) c.id};
    final pool = <PipelineSource>[];
    for (var round = 0; existing.length + pool.length < limits.maxCandidates; round++) {
      var any = false;
      for (final i in order) {
        final r = results[i];
        if (r == null || round >= r.items.length || round >= plan[i].take) continue;
        any = true;
        final c = _candidate(r.items[round], round < r.snippets.length ? r.snippets[round] : null, catalog);
        if (!seen.add(c.id)) continue;
        pool.add(c);
        if (existing.length + pool.length >= limits.maxCandidates) break;
      }
      if (!any) break;
    }
    return (candidates: pool, total: total, failed: plan.isNotEmpty && failures == plan.length);
  }

  /// Adds the page after each of the strongest sources as its own source.
  Future<List<PipelineSource>> _withContinuations(List<PipelineSource> selected, int limit) async {
    final have = {for (final c in selected) c.id};
    final targets = selected.where((c) => c.passage.internalPage != null).take(limit).toList();
    final next = await Future.wait([
      for (final c in targets)
        turath.getPage(c.passage.bookId, c.passage.internalPage! + 1).then<PagePassage?>((p) => p).catchError((Object _) => null),
    ]);
    final out = <PipelineSource>[];
    for (final c in selected) {
      out.add(c);
      final i = targets.indexOf(c);
      final page = i < 0 ? null : next[i];
      if (page == null || page.text.trim().isEmpty) continue;
      final candidate = _candidate(page, null, catalog);
      if (!have.add(candidate.id)) continue;
      out.add(PipelineSource(
        id: candidate.id,
        passage: candidate.passage,
        excerpt: candidate.excerpt,
        text: boundText(page.text, 1600, null),
        authorId: candidate.authorId,
        authorName: candidate.authorName,
        categoryId: candidate.categoryId,
        categoryTitle: candidate.categoryTitle,
      ));
    }
    return out;
  }

  Future<Map<String, dynamic>> _rank(String question, List<PipelineSource> pool, List<String> queries) async => (await model.generateJson(
        system: rerankSystem,
        prompt: rerankPrompt(question: question, candidates: [for (final c in pool) c.prompt(full: false)], queries: queries),
        schema: rerankSchema,
        temperature: 0.1,
      ))
          .data;

  Stream<AskEvent> ask(AskRequest request) async* {
    final started = DateTime.now();
    final question = request.question.trim();
    if (question.isEmpty) throw const PipelineException('INVALID_ARGUMENT', 'question must not be empty');
    if (question.length > 2000) throw const PipelineException('INVALID_ARGUMENT', 'question is too long');
    final scope = request.scope;
    final limits = Limits.forDepth(request.depth);

    // 1. plan
    yield const AskStageEvent(AskStage.planning);
    final plan = await model.generateJson(
      system: planSystem,
      prompt: planPrompt(question: question, history: request.history, scopeLabel: _scopeLabel(scope)),
      schema: planSchema,
      temperature: 0.1,
      tier: ModelTier.fast,
    );
    final p = plan.data;
    final queries = cleanQueries(p['queries']);
    final detected = p['detectedLanguage'];
    final language = languageNames.containsKey(request.language)
        ? request.language
        : languageNames.containsKey(detected)
            ? detected as String
            : (languageNames.containsKey(request.fallbackLanguage) ? request.fallbackLanguage : 'en');
    final madhhabs = {...(p['madhhabs'] as List? ?? const []).whereType<String>(), ...namedMadhhabs(question)}.where(madhhabCategory.containsKey).toList();
    final requestedIds = resolveBooks(_titles(p['requestedBooks'], limits.requestedBooks), catalog, perTitle: 2);
    final referenceIds = resolveBooks(_titles(p['referenceBooks'], 6), catalog).where((id) => !requestedIds.contains(id)).toList();
    final standalone = (p['standaloneQuestion'] as String?)?.trim().isNotEmpty == true ? (p['standaloneQuestion'] as String).trim() : question;
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
    AnswerResult nothing({int? total, List<PipelineSource> related = const []}) =>
        withMeta(finalizeAnswer(composed: const {'status': 'insufficient'}, sources: related, language: language), total: total);

    if (queries.isEmpty) {
      yield AskResultEvent(nothing());
      return;
    }

    // 2. search
    yield const AskStageEvent(AskStage.searching);
    final first = await _collect(
        searchPlan(queries: queries, scope: scope, madhhabs: madhhabs, requestedBookIds: requestedIds, referenceBookIds: referenceIds, limits: limits),
        limits: limits);
    if (first.failed) throw const PipelineException('TURATH_UNAVAILABLE', 'The Turath library could not be reached');
    var candidates = [for (var i = 0; i < first.candidates.length; i++) first.candidates[i].withKey('C${i + 1}')];
    var total = first.total;
    yield AskSourcesEvent(candidates.length, total);
    if (candidates.isEmpty) {
      yield AskResultEvent(nothing(total: total));
      return;
    }

    // 3. read & rank, then follow-up rounds if something is missing
    yield const AskStageEvent(AskStage.reading);
    var used = [...queries];
    var ranking = await _rank(standalone, candidates, used);
    for (var round = 0; round < limits.followUpRounds && ranking['coverage'] != 'full'; round++) {
      final followQueries = cleanQueries(ranking['followUpQueries'], max: 5).where((q) => !used.contains(q)).toList();
      final followBooks = resolveBooks(_titles(ranking['followUpBooks'], 4), catalog);
      if (followQueries.isEmpty && followBooks.isEmpty) break;
      yield const AskStageEvent(AskStage.searching);
      final keepKeys = (ranking['selected'] as List? ?? const []).map((k) => '$k'.toUpperCase()).toSet();
      final keep = candidates.where((c) => keepKeys.contains(c.key)).toList();
      final extra = await _collect(
        searchPlan(queries: followQueries.isNotEmpty ? followQueries : queries.take(3).toList(), scope: scope, requestedBookIds: followBooks, limits: limits),
        existing: keep,
        limits: limits,
      );
      total += extra.total;
      if (extra.candidates.isEmpty) break;
      used = [...used, ...followQueries];
      final merged = [...keep, ...extra.candidates];
      candidates = [for (var i = 0; i < merged.length; i++) merged[i].withKey('C${i + 1}')];
      yield AskSourcesEvent(candidates.length, total);
      yield const AskStageEvent(AskStage.reading);
      ranking = await _rank(standalone, candidates, used);
    }
    final byKey = {for (final c in candidates) c.key: c};
    var selected = (ranking['selected'] as List? ?? const []).map((k) => '$k'.trim().toUpperCase()).toSet().map((k) => byKey[k]).whereType<PipelineSource>().toList();
    if (selected.isEmpty && ranking['coverage'] != 'none') selected = candidates.take(6).toList();
    selected = selected.take((request.maxSources ?? limits.maxSelected).clamp(3, limits.maxSelected)).toList();
    if (selected.isEmpty) {
      yield AskResultEvent(nothing(total: total, related: [for (var i = 0; i < candidates.length && i < 6; i++) candidates[i].withKey('S${i + 1}')]));
      return;
    }
    final expanded = await _withContinuations(selected, limits.continuationPages);
    final sources = [for (var i = 0; i < expanded.length; i++) expanded[i].withKey('S${i + 1}')];

    // 4. compose
    yield const AskStageEvent(AskStage.composing);
    final languageName = languageNames[language]!;
    final composed = await model.generateJson(
      system: composeSystem(languageName),
      prompt: composePrompt(
        question: standalone,
        history: request.history,
        sources: [for (final s in sources) s.prompt(full: true)],
        languageName: languageName,
        missing: ranking['coverage'] == 'full' ? '' : '${ranking['missing'] ?? ''}',
      ),
      schema: composeSchema,
      temperature: 0.2,
    );

    // 5. verify
    yield const AskStageEvent(AskStage.verifying);
    yield AskResultEvent(withMeta(finalizeAnswer(composed: composed.data, sources: sources, language: language), total: total, modelName: composed.model));
  }
}
