/// Library records (Turath catalog and live Turath data).
library;

class CatalogCategory {
  const CatalogCategory(this.id, this.title, this.bookCount);
  final String id;
  final String title;
  final int bookCount;
}

class CatalogAuthor {
  const CatalogAuthor(this.id, this.name, this.bookCount);
  final String id;
  final String name;
  final int bookCount;
}

class CatalogBook {
  const CatalogBook(this.id, this.title, this.authorId, this.categoryId);
  final String id;
  final String title;
  final String authorId;
  final String categoryId;
}

class TocEntry {
  const TocEntry({required this.title, this.level = 1, this.page});
  final String title;
  final int level;
  final int? page;
}

class BookDetails {
  const BookDetails({
    required this.id,
    required this.title,
    this.authorId,
    this.categoryId,
    this.description,
    this.toc = const [],
    this.volumes = const [],
    this.hasPdf = false,
    this.pageMap = const [],
    this.volumeBounds = const {},
  });
  final String id;
  final String title;
  final String? authorId;
  final String? categoryId;
  final String? description;
  final List<TocEntry> toc;
  final List<String> volumes;
  final bool hasPdf;

  /// Turath page map: entry i is internal page i + 1 as "volume,printed page".
  final List<String> pageMap;

  /// Volume → first and last internal page.
  final Map<String, (int, int)> volumeBounds;

  String get url => 'https://app.turath.io/book/$id';

  /// Number of internal pages, when known.
  int? get pageCount => pageMap.isNotEmpty ? pageMap.length : (volumeBounds.isEmpty ? null : volumeBounds.values.map((b) => b.$2).reduce((a, b) => a > b ? a : b));

  /// Volume and printed page of an internal page.
  ({String? volume, int? printed}) locate(int internal) {
    if (internal < 1 || internal > pageMap.length) return (volume: null, printed: null);
    final parts = pageMap[internal - 1].split(',');
    return (volume: parts.first, printed: parts.length > 1 ? int.tryParse(parts[1]) : null);
  }

  /// Internal page of a volume and printed page (the nearest one at or after it).
  int? internalFor(String volume, int printed) {
    int? best;
    for (var i = 0; i < pageMap.length; i++) {
      final parts = pageMap[i].split(',');
      if (parts.first != volume || parts.length < 2) continue;
      final p = int.tryParse(parts[1]);
      if (p == null) continue;
      if (p == printed) return i + 1;
      if (p > printed && best == null) best = i + 1;
    }
    return best ?? volumeBounds[volume]?.$1;
  }

  /// The table-of-contents entry a page belongs to.
  TocEntry? headingFor(int internal) {
    TocEntry? found;
    for (final e in toc) {
      if (e.page != null && e.page! <= internal) found = e;
    }
    return found;
  }

  /// The chain of headings above a page, outermost first
  /// (e.g. كتاب الإيمان ← باب أمور الإيمان).
  List<TocEntry> headingPath(int internal) {
    final here = headingFor(internal);
    if (here == null) return const [];
    final path = [here];
    var level = here.level;
    for (var i = toc.indexOf(here) - 1; i >= 0 && level > 1; i--) {
      if (toc[i].level < level) {
        path.insert(0, toc[i]);
        level = toc[i].level;
      }
    }
    return path;
  }

  static Map<String, (int, int)> parseBounds(Object? raw) {
    final out = <String, (int, int)>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is List && v.length >= 2 && v[0] is num && v[1] is num) out['$k'] = ((v[0] as num).toInt(), (v[1] as num).toInt());
      });
    }
    return out;
  }

  /// Accepts both the Nusus-normalized shape (server) and is produced by the
  /// direct client in the same shape.
  factory BookDetails.fromJson(Map<String, dynamic> j) => BookDetails(
        id: '${j['id']}',
        title: j['title'] as String? ?? '',
        authorId: (j['author'] as Map?)?['id']?.toString(),
        categoryId: (j['category'] as Map?)?['id']?.toString(),
        description: j['description'] as String?,
        toc: (j['toc'] as List?)
                ?.whereType<Map>()
                .map((e) => TocEntry(title: '${e['title']}', level: (e['level'] as num?)?.toInt() ?? 1, page: (e['page'] as num?)?.toInt()))
                .toList() ??
            const [],
        volumes: (j['volumes'] as List?)?.whereType<String>().toList() ?? const [],
        hasPdf: j['hasPdf'] == true,
        pageMap: (j['pageMap'] as List?)?.map((e) => '$e').toList() ?? const [],
        volumeBounds: parseBounds(j['volumeBounds']),
      );
}

class AuthorDetails {
  const AuthorDetails({required this.id, required this.name, this.biography, this.deathYear});
  final String id;
  final String name;
  final String? biography;
  final String? deathYear;

  factory AuthorDetails.fromJson(Map<String, dynamic> j) => AuthorDetails(
        id: '${j['id']}',
        name: j['name'] as String? ?? '',
        biography: j['biography'] as String?,
        deathYear: j['deathYear'] as String?,
      );
}

/// One Turath page or search hit with its citation data.
class PagePassage {
  const PagePassage({
    required this.bookId,
    required this.bookTitle,
    required this.text,
    required this.url,
    this.authorId,
    this.authorName,
    this.categoryId,
    this.internalPage,
    this.printedPage,
    this.volume,
    this.headings = const [],
    this.snippet,
    this.citation,
    this.shamelaUrl,
  });

  final String bookId;
  final String bookTitle;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final int? internalPage;
  final int? printedPage;
  final String? volume;
  final List<String> headings;
  final String text;
  final String? snippet;
  final String url;
  final String? citation;
  final String? shamelaUrl;

  /// Parses the Nusus `Passage` JSON shape.
  factory PagePassage.fromJson(Map<String, dynamic> j) {
    final book = (j['book'] as Map?) ?? const {};
    final author = (j['author'] as Map?) ?? const {};
    final location = (j['location'] as Map?) ?? const {};
    return PagePassage(
      bookId: '${book['id']}',
      bookTitle: book['title'] as String? ?? '',
      authorId: author['id']?.toString(),
      authorName: author['name'] as String?,
      categoryId: (j['category'] as Map?)?['id']?.toString(),
      internalPage: (location['internalPage'] as num?)?.toInt(),
      printedPage: (location['printedPage'] as num?)?.toInt(),
      volume: location['volume']?.toString(),
      headings: (j['headings'] as List?)?.whereType<String>().toList() ?? const [],
      text: j['text'] as String? ?? '',
      snippet: j['snippet'] as String?,
      url: j['url'] as String? ?? '',
      citation: j['citation'] as String?,
      shamelaUrl: (j['alternateUrls'] as Map?)?['shamela'] as String?,
    );
  }

  PagePassage copyWith({String? text, String? authorName, String? authorId, String? categoryId}) => PagePassage(
        bookId: bookId,
        bookTitle: bookTitle,
        text: text ?? this.text,
        url: url,
        authorId: authorId ?? this.authorId,
        authorName: authorName ?? this.authorName,
        categoryId: categoryId ?? this.categoryId,
        internalPage: internalPage,
        printedPage: printedPage,
        volume: volume,
        headings: headings,
        snippet: snippet,
        citation: citation,
        shamelaUrl: shamelaUrl,
      );
}

class SearchResultPage {
  const SearchResultPage({required this.items, required this.totalMatches, required this.page, this.effectiveQuery});
  final List<PagePassage> items;
  final int totalMatches;
  final int page;
  final String? effectiveQuery;

  factory SearchResultPage.fromJson(Map<String, dynamic> j) => SearchResultPage(
        items: (j['items'] as List?)?.whereType<Map>().map((e) => PagePassage.fromJson(e.cast<String, dynamic>())).toList() ?? const [],
        totalMatches: (j['totalMatches'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
        effectiveQuery: j['effectiveQuery'] as String?,
      );
}
