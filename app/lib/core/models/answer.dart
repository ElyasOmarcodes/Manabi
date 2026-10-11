/// Result of one grounded question. The JSON shape is shared with the
/// Manabi server (`server/src/pipeline.mjs`).
library;

enum AnswerStatus { answered, partial, insufficient }

AnswerStatus _status(Object? v) => switch (v) {
      'answered' => AnswerStatus.answered,
      'partial' => AnswerStatus.partial,
      _ => AnswerStatus.insufficient,
    };

String? _str(Object? v) => v is String && v.isNotEmpty ? v : null;
int? _int(Object? v) => v is int ? v : (v is num ? v.toInt() : (v is String ? int.tryParse(v) : null));

class SourceQuote {
  const SourceQuote({required this.text, required this.exact, this.relevance});

  /// Verbatim text cut from the Turath page (never model generated).
  final String text;

  /// True when the model's quote matched the page exactly (after removing
  /// diacritics); false when it matched closely and the page text was used.
  final bool exact;
  final String? relevance;

  factory SourceQuote.fromJson(Map<String, dynamic> j) =>
      SourceQuote(text: j['text'] as String, exact: j['exact'] == true, relevance: _str(j['relevance']));

  Map<String, dynamic> toJson() => {'text': text, 'exact': exact, if (relevance != null) 'relevance': relevance};
}

class AnswerSource {
  const AnswerSource({
    required this.n,
    required this.bookId,
    required this.bookTitle,
    required this.url,
    this.authorId,
    this.authorName,
    this.categoryId,
    this.categoryTitle,
    this.volume,
    this.printedPage,
    this.internalPage,
    this.headings = const [],
    this.shamelaUrl,
    this.citation,
    this.quotes = const [],
    this.excerpt = '',
  });

  final int n;
  final String bookId;
  final String bookTitle;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final String? categoryTitle;
  final String? volume;
  final int? printedPage;
  final int? internalPage;
  final List<String> headings;
  final String url;
  final String? shamelaUrl;
  final String? citation;
  final List<SourceQuote> quotes;
  final String excerpt;

  bool get verified => quotes.isNotEmpty;

  factory AnswerSource.fromJson(Map<String, dynamic> j) => AnswerSource(
        n: _int(j['n']) ?? 0,
        bookId: '${j['bookId']}',
        bookTitle: j['bookTitle'] as String? ?? '',
        authorId: _str(j['authorId']?.toString()),
        authorName: _str(j['authorName']),
        categoryId: _str(j['categoryId']?.toString()),
        categoryTitle: _str(j['categoryTitle']),
        volume: _str(j['volume']?.toString()),
        printedPage: _int(j['printedPage']),
        internalPage: _int(j['internalPage']),
        headings: (j['headings'] as List?)?.whereType<String>().toList() ?? const [],
        url: j['url'] as String? ?? '',
        shamelaUrl: _str(j['shamelaUrl']),
        citation: _str(j['citation']),
        quotes: (j['quotes'] as List?)
                ?.whereType<Map>()
                .map((q) => SourceQuote.fromJson(q.cast<String, dynamic>()))
                .toList() ??
            const [],
        excerpt: j['excerpt'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'n': n,
        'bookId': bookId,
        'bookTitle': bookTitle,
        if (authorId != null) 'authorId': authorId,
        if (authorName != null) 'authorName': authorName,
        if (categoryId != null) 'categoryId': categoryId,
        if (categoryTitle != null) 'categoryTitle': categoryTitle,
        if (volume != null) 'volume': volume,
        if (printedPage != null) 'printedPage': printedPage,
        if (internalPage != null) 'internalPage': internalPage,
        'headings': headings,
        'url': url,
        if (shamelaUrl != null) 'shamelaUrl': shamelaUrl,
        if (citation != null) 'citation': citation,
        'quotes': quotes.map((q) => q.toJson()).toList(),
        'excerpt': excerpt,
      };
}

class Opinion {
  const Opinion({required this.holder, required this.view, required this.sources});
  final String holder;
  final String view;
  final List<int> sources;

  factory Opinion.fromJson(Map<String, dynamic> j) => Opinion(
        holder: j['holder'] as String? ?? '',
        view: j['view'] as String? ?? '',
        sources: (j['sources'] as List?)?.map(_int).whereType<int>().toList() ?? const [],
      );

  Map<String, dynamic> toJson() => {'holder': holder, 'view': view, 'sources': sources};
}

/// Gemini tokens spent on one answer (all calls added up).
class TokenUsage {
  const TokenUsage({this.input = 0, this.output = 0, this.thoughts = 0, this.calls = 0, this.peak = 0});
  final int input;
  final int output;
  final int thoughts;
  final int calls;

  /// Input tokens of the largest single call: how full the context window got.
  final int peak;

  int get total => input + output + thoughts;
  bool get isEmpty => calls == 0 && total == 0;

  TokenUsage operator +(TokenUsage o) =>
      TokenUsage(input: input + o.input, output: output + o.output, thoughts: thoughts + o.thoughts, calls: calls + o.calls, peak: peak > o.peak ? peak : o.peak);

  factory TokenUsage.fromJson(Object? v) {
    final j = v is Map ? v : const {};
    int n(Object? x) => x is num ? x.toInt() : 0;
    return TokenUsage(input: n(j['input']), output: n(j['output']), thoughts: n(j['thoughts']), calls: n(j['calls']), peak: n(j['peak']));
  }

  Map<String, dynamic> toJson() => {'input': input, 'output': output, 'thoughts': thoughts, 'calls': calls, 'peak': peak};
}

class AnswerResult {
  const AnswerResult({
    required this.status,
    required this.answer,
    this.summary = '',
    this.notes = '',
    this.detail = '',
    this.sources = const [],
    this.related = const [],
    this.opinions = const [],
    this.queries = const [],
    this.language,
    this.model,
    this.totalMatches,
    this.elapsedMs,
    this.usage = const TokenUsage(),
  });

  final AnswerStatus status;

  /// Markdown with numbered citation markers like `[1]`.
  final String answer;
  final String summary;
  final String notes;

  /// For insufficient answers: the model's explanation of what was found.
  final String detail;
  final List<AnswerSource> sources;

  /// Pages that were searched but are not evidence (insufficient answers).
  final List<AnswerSource> related;
  final List<Opinion> opinions;
  final List<String> queries;
  final String? language;
  final String? model;
  final int? totalMatches;
  final int? elapsedMs;
  final TokenUsage usage;

  bool get isDocumented => status != AnswerStatus.insufficient;

  AnswerSource? source(int n) {
    for (final s in sources) {
      if (s.n == n) return s;
    }
    return null;
  }

  static List<AnswerSource> _sources(Object? v) =>
      (v as List?)?.whereType<Map>().map((s) => AnswerSource.fromJson(s.cast<String, dynamic>())).toList() ?? const [];

  factory AnswerResult.fromJson(Map<String, dynamic> j) => AnswerResult(
        status: _status(j['status']),
        answer: j['answer'] as String? ?? '',
        summary: j['summary'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        detail: j['detail'] as String? ?? '',
        sources: _sources(j['sources']),
        related: _sources(j['related']),
        opinions:
            (j['opinions'] as List?)?.whereType<Map>().map((o) => Opinion.fromJson(o.cast<String, dynamic>())).toList() ??
                const [],
        queries: (j['queries'] as List?)?.whereType<String>().toList() ?? const [],
        language: _str(j['language']),
        model: _str(j['model']),
        totalMatches: _int(j['totalMatches']),
        elapsedMs: _int(j['elapsedMs']),
        usage: TokenUsage.fromJson(j['usage']),
      );

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'answer': answer,
        'summary': summary,
        'notes': notes,
        'detail': detail,
        'sources': sources.map((s) => s.toJson()).toList(),
        'related': related.map((s) => s.toJson()).toList(),
        'opinions': opinions.map((o) => o.toJson()).toList(),
        'queries': queries,
        if (language != null) 'language': language,
        if (model != null) 'model': model,
        if (totalMatches != null) 'totalMatches': totalMatches,
        if (elapsedMs != null) 'elapsedMs': elapsedMs,
        if (!usage.isEmpty) 'usage': usage.toJson(),
      };
}

/// Progress events while an answer is being prepared.
enum AskStage { planning, searching, reading, composing, verifying }

sealed class AskEvent {
  const AskEvent();
}

class AskStageEvent extends AskEvent {
  const AskStageEvent(this.stage);
  final AskStage stage;
}

class AskPlanEvent extends AskEvent {
  const AskPlanEvent(this.queries);
  final List<String> queries;
}

class AskSourcesEvent extends AskEvent {
  const AskSourcesEvent(this.count, this.totalMatches);
  final int count;
  final int totalMatches;
}

/// One line of the live research log (a search, a ranking, a page read…).
class AskActivityEvent extends AskEvent {
  const AskActivityEvent(this.kind, this.data, this.elapsedMs);

  /// plan, search, found, rank, ranked, followup, read, compose, verify, resumed, retry
  final String kind;
  final Map<String, dynamic> data;
  final int elapsedMs;
}

/// Tokens spent so far.
class AskUsageEvent extends AskEvent {
  const AskUsageEvent(this.usage);
  final TokenUsage usage;
}

/// The answer text as it is being written (before verification).
class AskDraftEvent extends AskEvent {
  const AskDraftEvent(this.text);
  final String text;
}

class AskResultEvent extends AskEvent {
  const AskResultEvent(this.result);
  final AnswerResult result;
}
