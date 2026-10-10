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
  const BookDetails({required this.id, required this.title, this.authorId, this.categoryId, this.description, this.toc = const [], this.volumes = const [], this.hasPdf = false});
  final String id;
  final String title;
  final String? authorId;
  final String? categoryId;
  final String? description;
  final List<TocEntry> toc;
  final List<String> volumes;
  final bool hasPdf;

  String get url => 'https://app.turath.io/book/$id';

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
