// Direct Turath client – a Dart port of the retrieval parts of the Nusus SDK
// (https://github.com/mwijanarko1/nusus, MIT). Used in "direct" mode on
// native platforms. Browsers cannot call api.turath.io (no CORS headers),
// so the web build always goes through the Manabi server, which uses the
// Nusus SDK itself.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/library.dart';
import '../pipeline/answer_pipeline.dart' show PassageRetriever;
import 'excerpt.dart';

class TurathException implements Exception {
  const TurathException(this.code, this.message);

  /// NOT_FOUND, INVALID_ARGUMENT, RATE_LIMITED, HTTP_ERROR, INVALID_RESPONSE, TIMEOUT
  final String code;
  final String message;
  @override
  String toString() => 'TurathException($code): $message';
}

String _plainText(String value) =>
    value.replaceAll(RegExp(r'<br\s*/?\s*>', caseSensitive: false), '\n').replaceAll(RegExp(r'</?[a-z][^>]*>', caseSensitive: false), '');

String sourceUrl(String bookId, int? internalPage) =>
    internalPage == null ? 'https://app.turath.io/book/$bookId' : 'https://app.turath.io/book/$bookId?page=$internalPage';

String? shamelaUrl(String bookId, int? internalPage) => internalPage == null ? null : 'https://shamela.ws/book/$bookId/$internalPage';

/// Same format as Nusus `formatCitation`.
String formatCitation({String? authorName, required String bookTitle, String? volume, int? printedPage, int? internalPage, required String bookId}) {
  final parts = <String>[
    if (authorName != null && authorName.isNotEmpty) authorName,
    if (bookTitle.isNotEmpty) bookTitle,
    if (volume != null && volume.isNotEmpty) 'ج $volume',
    if (printedPage != null) 'ص $printedPage',
    if (internalPage != null) 'صفحة تراث $internalPage',
    'تراث $bookId',
  ];
  return parts.join('، ');
}

List<String> searchFallbacks(String query) {
  final normalized = query
      .replaceAll('ٰ', 'ا')
      .replaceAll(RegExp(r'\p{M}', unicode: true), '')
      .replaceAll(RegExp('[إآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ـ', '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final variants = <String>[normalized];
  if (RegExp('[ءؤئ]').hasMatch(normalized)) {
    for (final h in ['ء', 'ؤ', 'ئ']) {
      variants.add(normalized.replaceAll(RegExp('[ءؤئ]'), h));
    }
  }
  return variants.toSet().where((c) => c.isNotEmpty && c != query).toList();
}

class RetrievedPassages {
  const RetrievedPassages(this.passages, this.totalMatches);
  final List<PagePassage> passages;
  final int totalMatches;
}

class TurathClient implements PassageRetriever {
  TurathClient({http.Client? client, this.baseUrl = 'https://api.turath.io/', this.timeout = const Duration(seconds: 15)})
      : _http = client ?? http.Client();

  final http.Client _http;
  final String baseUrl;
  final Duration timeout;
  final Map<String, Future<PagePassage>> _pageCache = {};

  Future<Object?> _get(String path, Map<String, Object?> params) async {
    final uri = Uri.parse(baseUrl).resolve(path).replace(queryParameters: {
      for (final e in params.entries)
        if (e.value != null) e.key: '${e.value}',
    });
    http.Response res;
    try {
      res = await _http.get(uri, headers: {'accept': 'application/json'}).timeout(timeout);
    } on TimeoutException {
      throw const TurathException('TIMEOUT', 'Turath request timed out');
    } catch (e) {
      throw TurathException('HTTP_ERROR', 'Turath request failed: $e');
    }
    if (res.statusCode == 404) throw const TurathException('NOT_FOUND', 'Not found');
    if (res.statusCode == 429) throw const TurathException('RATE_LIMITED', 'Turath rate limit');
    if (res.statusCode < 200 || res.statusCode >= 300) throw TurathException('HTTP_ERROR', 'Turath HTTP ${res.statusCode}');
    try {
      return jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      throw const TurathException('INVALID_RESPONSE', 'Turath returned invalid JSON');
    }
  }

  static Map<String, dynamic> _meta(Object? raw) {
    if (raw is! String) throw const TurathException('INVALID_RESPONSE', 'missing meta');
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } catch (_) {
      throw const TurathException('INVALID_RESPONSE', 'invalid meta');
    }
  }

  static PagePassage _passage(Map<String, dynamic> meta, String bookId, String text,
      {String? authorId, String? categoryId, String? snippet}) {
    final bookTitle = meta['book_name'];
    if (bookTitle is! String) throw const TurathException('INVALID_RESPONSE', 'missing book name');
    final internal = (meta['page_id'] as num?)?.toInt();
    final printed = (meta['page'] as num?)?.toInt();
    final volume = meta['vol'] is String ? meta['vol'] as String : null;
    final authorName = meta['author_name'] is String ? meta['author_name'] as String : null;
    return PagePassage(
      bookId: bookId,
      bookTitle: bookTitle,
      authorId: authorId,
      authorName: authorName,
      categoryId: categoryId,
      internalPage: internal,
      printedPage: printed,
      volume: volume,
      headings: (meta['headings'] as List?)?.whereType<String>().toList() ?? const [],
      text: _plainText(text),
      snippet: snippet == null ? null : _plainText(snippet),
      url: sourceUrl(bookId, internal),
      shamelaUrl: shamelaUrl(bookId, internal),
      citation: formatCitation(
          authorName: authorName, bookTitle: bookTitle, volume: volume, printedPage: printed, internalPage: internal, bookId: bookId),
    );
  }

  Future<PagePassage> getPage(String bookId, int page) {
    final key = '$bookId:$page';
    return _pageCache[key] ??= () async {
      try {
        final raw = await _get('page', {'book_id': bookId, 'pg': page, 'ver': 3});
        if (raw is! Map || raw.isEmpty) throw TurathException('NOT_FOUND', 'Book $bookId, page $page not found');
        final text = raw['text'];
        if (text is! String) throw const TurathException('INVALID_RESPONSE', 'invalid page');
        return _passage(_meta(raw['meta']), bookId, text);
      } catch (_) {
        _pageCache.remove(key);
        rethrow;
      }
    }();
  }

  Future<BookDetails> getBook(String bookId) async {
    final raw = await _get('book', {'id': bookId, 'include': 'indexes', 'ver': 3});
    final meta = raw is Map ? raw['meta'] : null;
    if (meta is! Map || meta['name'] is! String) throw const TurathException('INVALID_RESPONSE', 'invalid book');
    final indexes = (raw as Map)['indexes'];
    final toc = <TocEntry>[];
    var volumes = <String>[];
    if (indexes is Map) {
      for (final h in (indexes['headings'] as List? ?? const [])) {
        if (h is Map && h['title'] is String) {
          toc.add(TocEntry(title: h['title'] as String, level: (h['level'] as num?)?.toInt() ?? 1, page: (h['page'] as num?)?.toInt()));
        }
      }
      volumes = (indexes['volumes'] as List?)?.whereType<String>().toList() ?? const [];
    }
    return BookDetails(
      id: '${meta['id']}',
      title: meta['name'] as String,
      authorId: meta['author_id']?.toString(),
      categoryId: meta['cat_id']?.toString(),
      description: meta['info'] as String?,
      toc: toc,
      volumes: volumes,
      hasPdf: meta['pdf_links'] != null && meta['pdf_links'] != false && meta['pdf_links'] != '',
    );
  }

  Future<AuthorDetails> getAuthor(String authorId) async {
    final raw = await _get('author', {'id': authorId, 'ver': 3});
    if (raw is! Map || raw.isEmpty) throw TurathException('NOT_FOUND', 'Author $authorId not found');
    if (raw['name'] is! String) throw const TurathException('INVALID_RESPONSE', 'invalid author');
    return AuthorDetails(
      id: '${raw['id']}',
      name: raw['name'] as String,
      biography: raw['biography'] as String?,
      deathYear: raw['death'] is String ? raw['death'] as String : raw['death']?.toString(),
    );
  }

  Future<(SearchResultPage, List<String?>)> _searchRaw(String query,
      {int page = 1, String? bookId, String? authorId, String? categoryId}) async {
    if (query.trim().isEmpty) throw const TurathException('INVALID_ARGUMENT', 'query must not be empty');
    Future<Map> run(String q) async {
      final raw = await _get('search', {
        'q': q,
        'ver': 3,
        'page': page,
        'author': authorId,
        'book': bookId,
        'cat_id': categoryId,
      });
      if (raw is! Map || raw['count'] is! num || raw['data'] is! List) {
        throw const TurathException('INVALID_RESPONSE', 'invalid search response');
      }
      return raw;
    }

    var effective = query;
    var response = await run(query);
    if (response['count'] == 0) {
      for (final fallback in searchFallbacks(query)) {
        final candidate = await run(fallback);
        if (candidate['count'] == 0) continue;
        effective = fallback;
        response = candidate;
        break;
      }
    }
    final items = <PagePassage>[];
    final snips = <String?>[];
    for (final hit in response['data'] as List) {
      if (hit is! Map || hit['book_id'] is! num || hit['text'] is! String) continue;
      final snip = hit['snip'] is String ? hit['snip'] as String : null;
      items.add(_passage(_meta(hit['meta']), '${hit['book_id']}', hit['text'] as String,
          authorId: hit['author_id']?.toString(), categoryId: hit['cat_id']?.toString(), snippet: snip));
      snips.add(snip);
    }
    return (
      SearchResultPage(
          items: items, totalMatches: (response['count'] as num).toInt(), page: page, effectiveQuery: effective == query ? null : effective),
      snips
    );
  }

  Future<SearchResultPage> search(String query, {int page = 1, String? bookId, String? authorId, String? categoryId}) async =>
      (await _searchRaw(query, page: page, bookId: bookId, authorId: authorId, categoryId: categoryId)).$1;

  /// Like Nusus `retrieve()`: top hits, each as the full page text bounded
  /// to a match-centred window.
  @override
  Future<RetrievedPassages> retrieve(String query,
      {int maxPassages = 4, int maxChars = 1600, String? bookId, String? authorId, String? categoryId}) async {
    final (first, snips) = await _searchRaw(query, bookId: bookId, authorId: authorId, categoryId: categoryId);
    final hits = first.items.take(maxPassages).toList();
    final hitSnips = snips.take(maxPassages).toList();
    final passages = await Future.wait([
      for (var i = 0; i < hits.length; i++)
        () async {
          final hit = hits[i];
          var page = hit;
          if (hit.internalPage != null) {
            try {
              page = await getPage(hit.bookId, hit.internalPage!);
            } on TurathException catch (e) {
              if (e.code != 'NOT_FOUND') rethrow;
            }
          }
          final bounded = boundText(page.text, maxChars, hitSnips[i] ?? hit.snippet);
          return page.copyWith(
            text: bounded,
            authorId: hit.authorId ?? page.authorId,
            authorName: page.authorName ?? hit.authorName,
            categoryId: hit.categoryId ?? page.categoryId,
          );
        }(),
    ]);
    return RetrievedPassages(passages, first.totalMatches);
  }
}
