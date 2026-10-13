// Grounded answer pipeline (v2) – Dart port of server/src/pipeline.mjs (keep in sync).
//   plan → search (general, per book, per school) → read & rank (+1 follow-up
//   round) → compose with inline quotes → verify every quote.
import 'dart:async';
import 'dart:math';

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
    this.requestedAuthors = 2,
    this.focusBooks = 2,
    this.chapterPages = 4,
    this.relatedWorks = 2,
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
  final int requestedAuthors;

  /// Books whose own chapter on the topic is read, pages read from it, and
  /// works built on them (abridgements, commentaries) searched too.
  final int focusBooks;
  final int chapterPages;
  final int relatedWorks;

  static const excerptChars = 650;
  static const sourceChars = 2400;

  static const standard = Limits();
  static const quick = Limits(
      generalQueries: 3, hitsPerGeneral: 6, referenceBooks: 3, queriesPerMadhhab: 2, maxSearches: 18, maxCandidates: 32, maxSelected: 6, continuationPages: 2, followUpRounds: 0, focusBooks: 1, chapterPages: 2, relatedWorks: 0);
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
      followUpRounds: 2,
      chapterPages: 8,
      relatedWorks: 3);

  static Limits forDepth(String? depth) => switch (depth) {
        'quick' => quick,
        'deep' => deep,
        _ => standard,
      };
}

/// `fast` is used for planning and ranking, `main` for writing the answer.
enum ModelTier { fast, main }

/// A model reply: the parsed JSON, the model that wrote it and its tokens.
typedef ModelReply = ({Map<String, dynamic> data, String model, TokenUsage usage});

abstract interface class JsonModel {
  /// With [onText] the reply is streamed and its raw text reported as it grows.
  Future<ModelReply> generateJson(
      {required String system,
      required String prompt,
      required Map<String, dynamic> schema,
      double temperature = 0.2,
      ModelTier tier = ModelTier.main,
      void Function(String text)? onText,
      String? prefer});
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
  Future<BookDetails> getBook(String bookId);
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
    this.model,
    this.memory = const [],
  });
  final String question;

  /// The user's remembered wishes, followed in every answer.
  final List<String> memory;
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

  /// The model the user picked for writing the answer; null = automatic.
  final String? model;

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
        'model': ?model,
        if (memory.isNotEmpty) 'memory': memory,
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

/// Resolves scholars' names to catalog author ids (best match per name).
List<String> resolveAuthors(List<String> names, CatalogService catalog, {int max = 2}) {
  final ids = <String>[];
  for (final name in names) {
    var found = catalog.findAuthors(name, limit: 3);
    // "أبو حامد محمد الغزالي" → "الغزالي": the name most books are filed under.
    final last = name.trim().split(RegExp(r'\s+')).last;
    if (found.isEmpty && last.isNotEmpty && last != name.trim()) found = catalog.findAuthors(last, limit: 3);
    if (found.isNotEmpty && !ids.contains(found.first.id)) ids.add(found.first.id);
  }
  return ids.take(max).toList();
}

/// The books whose own chapter on the topic should be read: the books the
/// user asked for, then the books of the scholars asked about that the
/// search found most often (main works before abridgements).
List<String> focusBooks({List<String> requestedBookIds = const [], List<String> authorIds = const [], List<({String bookId, String bookTitle, String? authorId})> candidates = const [], int max = 2}) {
  final out = requestedBookIds.take(max).toList();
  if (authorIds.isNotEmpty) {
    final counts = <String, int>{};
    for (final c in candidates) {
      if (!authorIds.contains(c.authorId) || _derivative.hasMatch(_strip(c.bookTitle))) continue;
      counts[c.bookId] = (counts[c.bookId] ?? 0) + 1;
    }
    final ranked = counts.entries.toList()..sort((a, b) => b.value - a.value);
    for (final e in ranked) {
      if (out.length < max && !out.contains(e.key)) out.add(e.key);
    }
  }
  return out;
}

final _chapterLead = RegExp(r'^(كتاب|باب|القول في|فصل في|ربع|الباب)');

/// Finds where a book treats a topic in its table of contents: the highest
/// heading that names one of [terms], and the sections under it.
({TocEntry chapter, List<TocEntry> sections})? findChapter(List<TocEntry> toc, List<String> terms) {
  final words = [for (final t in terms) _strip(t).replaceFirst(RegExp(r'^(كتاب|باب|فصل)\s+'), '')].where((t) => t.length >= 2).toList();
  if (words.isEmpty) return null;
  int? best;
  double bestScore = 0;
  for (var i = 0; i < toc.length; i++) {
    final e = toc[i];
    if (e.page == null) continue;
    final t = _strip(e.title);
    if (!words.any(t.contains)) continue;
    final score = e.level * 3 + (_chapterLead.hasMatch(t) ? 0 : 2) + t.length / 30;
    if (best == null || score < bestScore) {
      best = i;
      bestScore = score;
    }
  }
  if (best == null) return null;
  final chapter = toc[best];
  final sections = <TocEntry>[];
  for (var j = best + 1; j < toc.length && toc[j].level > chapter.level; j++) {
    sections.add(toc[j]);
  }
  return (chapter: chapter, sections: sections);
}

/// Pages to read from a chapter: its opening, then the start of each section.
List<int> chapterPages(({TocEntry chapter, List<TocEntry> sections}) found, int n) {
  final pages = <int>[];
  void add(int? p) {
    if (p != null && p > 0 && !pages.contains(p) && pages.length < n) pages.add(p);
  }

  add(found.chapter.page);
  add(found.chapter.page! + 1);
  final top = found.sections.isEmpty ? 0 : found.sections.map((x) => x.level).reduce(min);
  for (final x in found.sections) {
    if (x.level == top) add(x.page);
  }
  for (final x in found.sections) {
    add(x.page);
  }
  return pages..sort();
}

// Indexes and studies of a book are not its abridgements or explanations.
final _notRelated = RegExp(r'^(تخريج|فهرس|فهارس|دراسة)');

/// Works built on a book (abridgements, commentaries): their titles contain its title.
List<String> relatedWorks(String bookId, CatalogService catalog, {int max = 2}) {
  final main = catalog.book(bookId);
  final t = _strip(main?.title ?? '');
  if (t.length < 6 || max <= 0) return const [];
  return [
    for (final b in catalog.findBooks(main!.title, limit: 12))
      if (b.id != bookId && _strip(b.title).contains(t) && !_notRelated.hasMatch(_strip(b.title))) b.id,
  ].take(max).toList();
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
  List<String> requestedAuthorIds = const [],
  List<String> referenceBookIds = const [],
  Limits limits = Limits.standard,
}) {
  final userScoped = !scope.isAll;
  // Several scope targets: every target gets the first query before any
  // gets the second, and the hits are shared out between them.
  final targets = scope.targets;
  final take = targets.length > 1 ? max(3, (limits.hitsPerGeneral / min(targets.length, 3)).ceil()) : limits.hitsPerGeneral;
  final plan = <PlannedSearch>[
    for (final q in queries.take(limits.generalQueries))
      for (final t in targets) PlannedSearch(q, take, 'general', bookId: t.bookId, authorId: t.authorId, categoryId: t.categoryId),
  ];
  if (targets.length > 1) return plan.take(max(limits.maxSearches, min(targets.length * 2, 16))).toList();
  if (!userScoped) {
    for (final id in requestedBookIds.take(limits.requestedBooks)) {
      for (final q in queries.take(limits.queriesPerRequested)) {
        plan.add(PlannedSearch(q, limits.hitsPerRequested, 'requested', bookId: id));
      }
    }
    for (final id in requestedAuthorIds.take(limits.requestedAuthors)) {
      for (final q in queries.take(limits.queriesPerRequested)) {
        plan.add(PlannedSearch(q, limits.hitsPerRequested, 'requested', authorId: id));
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
    this.chapterRead = false,
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

  /// Read from the chapter of the book that treats the topic.
  final bool chapterRead;

  PipelineSource asChapter() => PipelineSource(
      id: id,
      passage: passage,
      excerpt: excerpt,
      text: text,
      authorId: authorId,
      authorName: authorName,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      key: key,
      chapterRead: true);

  PipelineSource withKey(String k) => PipelineSource(
      id: id,
      passage: passage,
      excerpt: excerpt,
      text: text,
      authorId: authorId,
      authorName: authorName,
      categoryId: categoryId,
      categoryTitle: categoryTitle,
      key: k,
      chapterRead: chapterRead);

  PromptSource prompt({required bool full}) => PromptSource(
        key: key,
        bookTitle: passage.bookTitle,
        authorName: authorName,
        categoryTitle: categoryTitle,
        volume: passage.volume,
        printedPage: passage.printedPage,
        headings: passage.headings,
        text: full ? text : excerpt,
        chapterRead: chapterRead,
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

List<String> _sourceKeys(String inner) => [
      for (var part in inner.split(RegExp('[,،;]')))
        if ((part = part.trim().toUpperCase()).isNotEmpty) part.startsWith('S') ? part : 'S$part',
    ];

/// Puts each quotation in the part of the answer that cites its source. The
/// writer sometimes numbers its quotations in a different order than the
/// posts or sections they belong to; each heading's part keeps a quote only
/// when its text cites that quote's source, otherwise it takes a still unused
/// quote of a source it does cite. [sourceOf] maps verified quote ids to source keys.
String realignQuotes(String answer, Map<String, String> sourceOf) {
  final parts = [
    for (final text in answer.split(RegExp(r'(?=^#{2,4} )', multiLine: true)))
      (
        text: text,
        cited: {for (final m in _marker.allMatches(text.replaceAll(_quoteMarker, ''))) ..._sourceKeys(m.group(1)!)},
        quotes: [for (final m in _quoteMarker.allMatches(text)) m.group(1)!.toUpperCase()],
      ),
  ];
  final used = {for (final p in parts) ...p.quotes.where((q) => p.cited.contains(sourceOf[q]))};
  return parts
      .map((p) => p.text.replaceAllMapped(_quoteMarker, (m) {
            final q = m.group(1)!.toUpperCase();
            if (p.cited.isEmpty || !sourceOf.containsKey(q) || p.cited.contains(sourceOf[q])) return m.group(0)!;
            final better = sourceOf.entries.where((e) => !used.contains(e.key) && p.cited.contains(e.value)).firstOrNull;
            if (better == null) return m.group(0)!;
            used.add(better.key);
            return '[[${better.key}]]';
          }))
      .join();
}

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

  final answer = realignQuotes('${composed['answer'] ?? ''}', {for (final e in inline.entries) e.key: e.value.key})
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

  String _scopeLabel(SearchScope scope) {
    String names(List<ScopeRef> refs, String? Function(String id) look) => refs.map((r) => '"${look(r.id) ?? (r.name.isEmpty ? r.id : r.name)}"').join(', ');
    return [
      if (scope.books.isNotEmpty) '${scope.books.length > 1 ? 'books' : 'book'} ${names(scope.books, (id) => catalog.book(id)?.title)}',
      if (scope.authors.isNotEmpty) '${scope.authors.length > 1 ? 'authors' : 'author'} ${names(scope.authors, (id) => catalog.author(id)?.name)}',
      if (scope.categories.isNotEmpty) '${scope.categories.length > 1 ? 'categories' : 'category'} ${names(scope.categories, (id) => catalog.category(id)?.title)}',
    ].join('; ');
  }

  /// Runs searches (bounded concurrency 6) and merges hits into a de-duplicated pool.
  Future<({List<PipelineSource> candidates, int total, bool failed})> _collect(List<PlannedSearch> plan,
      {List<PipelineSource> existing = const [], Limits limits = Limits.standard, void Function(PlannedSearch search, SearchHits hits)? onSearch}) async {
    final results = List<SearchHits?>.filled(plan.length, null);
    var failures = 0;
    var cursor = 0;
    Future<void> worker() async {
      while (cursor < plan.length) {
        final i = cursor++;
        final s = plan[i];
        try {
          final hits = results[i] = await turath.searchHits(s.query, bookId: s.bookId, authorId: s.authorId, categoryId: s.categoryId);
          onSearch?.call(s, hits);
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

  /// Reads the chapter where each focus book treats the topic (found in its
  /// table of contents), so the answer rests on the author's own discussion
  /// and not only on pages that happen to match a search word.
  Future<({List<PipelineSource> candidates, List<ChapterOutline> outlines})> _readChapters(List<String> bookIds, List<String> terms, int n,
      {void Function(String book, String chapter, int pages)? onChapter}) async {
    final candidates = <PipelineSource>[];
    final outlines = <ChapterOutline>[];
    if (terms.isEmpty || n <= 0) return (candidates: candidates, outlines: outlines);
    final books = await Future.wait([for (final id in bookIds) turath.getBook(id).then<BookDetails?>((b) => b).catchError((Object _) => null)]);
    for (final (i, book) in books.indexed) {
      if (book == null) continue;
      final found = findChapter(book.toc, terms);
      if (found == null) continue;
      final pages = await Future.wait([
        for (final page in chapterPages(found, n)) turath.getPage(bookIds[i], page).then<PagePassage?>((p) => p).catchError((Object _) => null),
      ]);
      var count = 0;
      for (final page in pages) {
        if (page == null || page.text.trim().isEmpty) continue;
        candidates.add(_candidate(page, null, catalog).asChapter());
        count++;
      }
      if (count == 0) continue;
      outlines.add((book: book.title, chapter: found.chapter.title, sections: [for (final x in found.sections.take(24)) x.title]));
      onChapter?.call(book.title, found.chapter.title, count);
    }
    return (candidates: candidates, outlines: outlines);
  }

  /// Finished steps per request id, so a retry after a dropped connection
  /// resumes where it stopped instead of starting over.
  static final _memos = <String, ({DateTime at, Map<String, Object> steps})>{};

  Map<String, Object> _memoFor(String? requestId) {
    final now = DateTime.now();
    _memos.removeWhere((_, m) => now.difference(m.at) > const Duration(minutes: 20));
    if (requestId == null) return {};
    return _memos.putIfAbsent(requestId, () => (at: now, steps: <String, Object>{})).steps;
  }

  /// Streams progress events, the draft answer and finally the result.
  Stream<AskEvent> ask(AskRequest request) {
    final controller = StreamController<AskEvent>();
    _ask(request, controller.add).then((_) => controller.close(), onError: (Object e, StackTrace st) {
      controller.addError(e, st);
      controller.close();
    });
    return controller.stream;
  }

  Future<void> _ask(AskRequest request, void Function(AskEvent) emit) async {
    final started = DateTime.now();
    final question = request.question.trim();
    if (question.isEmpty) throw const PipelineException('INVALID_ARGUMENT', 'question must not be empty');
    if (question.length > 2000) throw const PipelineException('INVALID_ARGUMENT', 'question is too long');
    final scope = request.scope;
    final limits = Limits.forDepth(request.depth);
    final memo = _memoFor(request.requestId);
    var usage = const TokenUsage();
    int elapsed() => DateTime.now().difference(started).inMilliseconds;
    void act(String kind, [Map<String, dynamic> data = const {}]) => emit(AskActivityEvent(kind, data, elapsed()));

    Future<ModelReply> generate(String key, {required String system, required String prompt, required Map<String, dynamic> schema, double temperature = 0.2, ModelTier tier = ModelTier.main, void Function(String)? onText}) async {
      final kept = memo[key];
      if (kept is ModelReply) {
        act('resumed', {'step': key});
        return kept;
      }
      // The user's model writes the answer; the quick steps keep the fast tier.
      final prefer = tier == ModelTier.main ? request.model : null;
      final reply = await model.generateJson(system: system, prompt: prompt, schema: schema, temperature: temperature, tier: tier, onText: onText, prefer: prefer);
      usage = usage + reply.usage;
      emit(AskUsageEvent(usage));
      memo[key] = reply;
      return reply;
    }

    void onSearch(PlannedSearch s, SearchHits hits) => act('search', {
          'query': s.query,
          'within': s.kind,
          if (s.bookId != null) 'book': catalog.book(s.bookId)?.title,
          'hits': hits.totalMatches,
        });
    Future<({List<PipelineSource> candidates, int total, bool failed})> collect(String key, List<PlannedSearch> plan, {List<PipelineSource> existing = const []}) async {
      final kept = memo[key];
      if (kept is ({List<PipelineSource> candidates, int total, bool failed})) return kept;
      final result = await _collect(plan, existing: existing, limits: limits, onSearch: onSearch);
      if (!result.failed) memo[key] = result;
      return result;
    }

    Future<Map<String, dynamic>> rank(String key, String question, List<PipelineSource> pool, List<String> queries) async {
      act('rank', {'pool': pool.length});
      final ranked = (await generate(key,
              system: rerankSystem,
              prompt: rerankPrompt(question: question, candidates: [for (final c in pool) c.prompt(full: false)], queries: queries),
              schema: rerankSchema,
              temperature: 0.1))
          .data;
      act('ranked', {
        'selected': (ranked['selected'] as List?)?.length ?? 0,
        'coverage': ranked['coverage'],
        if (ranked['missing'] is String) 'missing': ranked['missing'],
      });
      return ranked;
    }

    // 1. plan
    emit(const AskStageEvent(AskStage.planning));
    final plan = await generate(
      'plan',
      system: planSystem,
      prompt: planPrompt(question: question, history: request.history, scopeLabel: _scopeLabel(scope), memory: request.memory),
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
    final authorIds = resolveAuthors(_titles(p['requestedAuthors'], limits.requestedAuthors), catalog, max: limits.requestedAuthors);
    final chapterTerms = _titles(p['chapterTerms'], 3);
    final format = const {'standard', 'posts', 'quotes', 'brief', 'detailed'}.contains(p['answerFormat']) ? p['answerFormat'] as String : 'standard';
    final standalone = (p['standaloneQuestion'] as String?)?.trim().isNotEmpty == true ? (p['standaloneQuestion'] as String).trim() : question;
    emit(AskPlanEvent(queries));
    act('plan', {
      'queries': queries,
      'books': [for (final id in [...requestedIds, ...referenceIds]) ?catalog.book(id)?.title],
      'madhhabs': madhhabs,
      'authors': [for (final id in authorIds) ?catalog.author(id)?.name],
      'format': format,
    });

    // A lasting wish the user just stated, for the app to keep.
    final remember = p['remember'] is String ? (p['remember'] as String).trim() : '';
    AnswerResult withMeta(AnswerResult r, {int? total, String? modelName}) => AnswerResult(
          remember: remember.length > 240 ? remember.substring(0, 240) : remember,
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
          elapsedMs: elapsed(),
          usage: usage,
        );
    AnswerResult nothing({int? total, List<PipelineSource> related = const []}) =>
        withMeta(finalizeAnswer(composed: const {'status': 'insufficient'}, sources: related, language: language), total: total);

    // Conversation ("who are you?", thanks): answered at once, nothing to research.
    final chatReply = p['chatReply'] is String ? (p['chatReply'] as String).trim() : '';
    if (chatReply.isNotEmpty && queries.isEmpty) {
      emit(AskResultEvent(withMeta(AnswerResult(
        status: AnswerStatus.answered,
        answer: chatReply,
        summary: chatReply.length > 200 ? chatReply.substring(0, 200) : chatReply,
      ))));
      return;
    }
    if (queries.isEmpty) {
      emit(AskResultEvent(nothing()));
      return;
    }

    // 2. search
    emit(const AskStageEvent(AskStage.searching));
    final first = await collect(
        'search0',
        searchPlan(
            queries: queries, scope: scope, madhhabs: madhhabs, requestedBookIds: requestedIds, requestedAuthorIds: authorIds, referenceBookIds: referenceIds, limits: limits));
    if (first.failed) throw const PipelineException('TURATH_UNAVAILABLE', 'The Turath library could not be reached');
    var total = first.total;

    // 2b. the author's own chapter on the topic, and the works built on his book
    final focus = !scope.isAll
        ? [for (final b in scope.books.take(limits.focusBooks)) b.id]
        : focusBooks(
            requestedBookIds: requestedIds,
            authorIds: authorIds,
            candidates: [for (final c in first.candidates) (bookId: c.passage.bookId, bookTitle: c.passage.bookTitle, authorId: c.authorId)],
            max: limits.focusBooks);
    var chapters = (candidates: <PipelineSource>[], outlines: <ChapterOutline>[]);
    if (focus.isNotEmpty && chapterTerms.isNotEmpty) {
      final kept = memo['chapters'];
      chapters = kept is ({List<PipelineSource> candidates, List<ChapterOutline> outlines})
          ? kept
          : await _readChapters(focus, chapterTerms, limits.chapterPages, onChapter: (book, chapter, pages) => act('chapter', {'book': book, 'chapter': chapter, 'pages': pages}));
      memo['chapters'] = chapters;
    }
    final relatedIds = !scope.isAll ? const <String>[] : {for (final id in focus) ...relatedWorks(id, catalog, max: limits.relatedWorks)}.where((id) => !referenceIds.contains(id)).take(limits.relatedWorks).toList();
    var relatedFound = const <PipelineSource>[];
    if (relatedIds.isNotEmpty) {
      final r = await collect('search0b', [for (final id in relatedIds) for (final q in queries.take(2)) PlannedSearch(q, 3, 'reference', bookId: id)],
          existing: [...chapters.candidates, ...first.candidates]);
      total += r.total;
      relatedFound = r.candidates;
    }
    final seenIds = <String>{};
    final pool = [...chapters.candidates, ...first.candidates, ...relatedFound].where((c) => seenIds.add(c.id)).toList();
    var candidates = [for (var i = 0; i < pool.length; i++) pool[i].withKey('C${i + 1}')];
    emit(AskSourcesEvent(candidates.length, total));
    act('found', {'count': candidates.length, 'total': total});
    if (candidates.isEmpty) {
      emit(AskResultEvent(nothing(total: total)));
      return;
    }

    // 3. read & rank, then follow-up rounds if something is missing
    emit(const AskStageEvent(AskStage.reading));
    var used = [...queries];
    var ranking = await rank('rank0', standalone, candidates, used);
    for (var round = 0; round < limits.followUpRounds && ranking['coverage'] != 'full'; round++) {
      final followQueries = cleanQueries(ranking['followUpQueries'], max: 5).where((q) => !used.contains(q)).toList();
      final followBooks = resolveBooks(_titles(ranking['followUpBooks'], 4), catalog);
      if (followQueries.isEmpty && followBooks.isEmpty) break;
      emit(const AskStageEvent(AskStage.searching));
      act('followup', {'queries': followQueries, 'books': [for (final id in followBooks) ?catalog.book(id)?.title]});
      final keepKeys = (ranking['selected'] as List? ?? const []).map((k) => '$k'.toUpperCase()).toSet();
      final keep = candidates.where((c) => keepKeys.contains(c.key) || c.chapterRead).toList();
      final extra = await collect(
        'search${round + 1}',
        searchPlan(queries: followQueries.isNotEmpty ? followQueries : queries.take(3).toList(), scope: scope, requestedBookIds: followBooks, limits: limits),
        existing: keep,
      );
      total += extra.total;
      if (extra.candidates.isEmpty) break;
      used = [...used, ...followQueries];
      final merged = [...keep, ...extra.candidates];
      candidates = [for (var i = 0; i < merged.length; i++) merged[i].withKey('C${i + 1}')];
      emit(AskSourcesEvent(candidates.length, total));
      emit(const AskStageEvent(AskStage.reading));
      ranking = await rank('rank${round + 1}', standalone, candidates, used);
    }
    final byKey = {for (final c in candidates) c.key: c};
    var selected = (ranking['selected'] as List? ?? const []).map((k) => '$k'.trim().toUpperCase()).toSet().map((k) => byKey[k]).whereType<PipelineSource>().toList();
    if (selected.isEmpty && ranking['coverage'] != 'none') selected = candidates.take(6).toList();
    final maxSources = (request.maxSources ?? limits.maxSelected).clamp(3, limits.maxSelected);
    selected = selected.take(maxSources).toList();
    // The opening of the chapter asked about is always read.
    final opening = candidates.where((c) => c.chapterRead && !selected.contains(c)).take(max(0, 2 - selected.where((c) => c.chapterRead).length)).toList();
    if (opening.isNotEmpty) selected = [...opening, ...selected].take(max(maxSources, opening.length)).toList();
    if (selected.isEmpty) {
      emit(AskResultEvent(nothing(total: total, related: [for (var i = 0; i < candidates.length && i < 6; i++) candidates[i].withKey('S${i + 1}')])));
      return;
    }
    final expanded = await _withContinuations(selected, limits.continuationPages);
    final sources = [for (var i = 0; i < expanded.length; i++) expanded[i].withKey('S${i + 1}')];
    act('read', {'books': {for (final s in sources) s.passage.bookTitle}.take(8).toList(), 'pages': sources.length});

    // 4. compose (streamed: the draft is shown while it is written)
    emit(const AskStageEvent(AskStage.composing));
    act('compose', {'sources': sources.length});
    final languageName = languageNames[language]!;
    var lastDraft = DateTime.fromMillisecondsSinceEpoch(0);
    final composed = await generate(
      'compose',
      system: composeSystem(languageName),
      prompt: composePrompt(
        question: standalone,
        history: request.history,
        sources: [for (final s in sources) s.prompt(full: true)],
        languageName: languageName,
        missing: ranking['coverage'] == 'full' ? '' : '${ranking['missing'] ?? ''}',
        format: format,
        outlines: chapters.outlines,
        memory: request.memory,
      ),
      schema: composeSchema,
      temperature: 0.2,
      onText: (text) {
        final now = DateTime.now();
        if (now.difference(lastDraft) < const Duration(milliseconds: 350)) return;
        lastDraft = now;
        final draft = partialJsonString(text, 'answer');
        if (draft != null && draft.isNotEmpty) emit(AskDraftEvent(draft));
      },
    );

    // 5. verify
    emit(const AskStageEvent(AskStage.verifying));
    act('verify');
    emit(AskResultEvent(withMeta(finalizeAnswer(composed: composed.data, sources: sources, language: language), total: total, modelName: composed.model)));
  }
}

const _escapes = {'"': '"', r'\': r'\', '/': '/', 'b': '\b', 'f': '\f', 'n': '\n', 'r': '\r', 't': '\t'};

/// Reads one string field out of JSON that is still being streamed (the
/// closing quote may not have arrived yet).
String? partialJsonString(String text, String key) {
  final at = text.indexOf('"$key"');
  if (at < 0) return null;
  var i = text.indexOf(':', at + key.length + 2);
  if (i < 0) return null;
  i++;
  while (i < text.length && text[i].trim().isEmpty) {
    i++;
  }
  if (i >= text.length || text[i] != '"') return null;
  i++;
  final out = StringBuffer();
  while (i < text.length) {
    final c = text[i];
    if (c == '"') return out.toString();
    if (c != r'\') {
      out.write(c);
      i++;
      continue;
    }
    if (i + 1 >= text.length) break;
    final e = text[i + 1];
    if (e == 'u') {
      if (i + 6 > text.length) break;
      final code = int.tryParse(text.substring(i + 2, i + 6), radix: 16);
      if (code == null) break;
      out.writeCharCode(code);
      i += 6;
    } else {
      out.write(_escapes[e] ?? e);
      i += 2;
    }
  }
  return out.toString();
}
