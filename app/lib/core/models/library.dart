/// Library records (Turath catalog and live Turath data).
library;

import '../turath/html_text.dart';

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

/// Turath's scanned edition: `files.turath.io/pdf/<root><file>`, per volume.
class PdfLinks {
  const PdfLinks(this.root, this.files);
  final String root;

  /// "01_54495.pdf", or with a part label: "01_54495p2.pdf|#3|المقدمة".
  final List<String> files;

  static PdfLinks? parse(Object? raw) {
    if (raw is! Map || raw['files'] is! List) return null;
    final files = [for (final f in raw['files'] as List) if (f is String && f.trim().isNotEmpty) f];
    return files.isEmpty ? null : PdfLinks(raw['root'] is String ? raw['root'] as String : '', files);
  }

  Map<String, dynamic> toJson() => {'root': root, 'files': files};

  /// The volume number in a file name: the leading number ("04_54497.pdf")
  /// or, failing that, the last one ("roohm_04.pdf"); 0 is the introduction.
  static int? _volumeOf(String file) {
    final f = file.split('|').first;
    final lead = RegExp(r'^(\d+)[_\-. ]').firstMatch(f);
    final tail = RegExp(r'(\d+)\.pdf$', caseSensitive: false).firstMatch(f);
    return int.tryParse((lead ?? tail)?.group(1) ?? '');
  }

  /// The whole-volume file for [volume] (parts are only used as a fallback).
  String url([String? volume]) {
    String name(String f) => f.split('|').first;
    final whole = files.where((f) => !f.contains('|')).toList();
    String? pick;
    final v = int.tryParse(volume ?? '');
    if (v != null) {
      pick = whole.where((f) => _volumeOf(f) == v).firstOrNull ?? files.where((f) => _volumeOf(f) == v).firstOrNull;
      // Files numbered from 1 with no introduction file, in volume order.
      if (pick == null && whole.every((f) => _volumeOf(f) == null) && v >= 1 && v <= whole.length) pick = whole[v - 1];
    } else if (volume != null && volume.trim().isNotEmpty) {
      // A named volume such as المقدمة is the "00" file.
      pick = whole.where((f) => _volumeOf(f) == 0).firstOrNull;
    }
    pick ??= (whole.length == 1 ? whole.first : null) ?? whole.where((f) => _volumeOf(f) != 0).firstOrNull ?? files.first;
    final path = '$root/${name(pick)}'.replaceAll(RegExp(r'/+'), '/');
    return 'https://files.turath.io/pdf/${path.startsWith('/') ? path.substring(1) : path}';
  }
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
    this.pdf,
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

  /// The scanned edition, when Turath has one.
  final PdfLinks? pdf;

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

  /// The shape [BookDetails.fromJson] reads (kept with offline books).
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': {'id': ?authorId},
        'category': {'id': ?categoryId},
        'description': ?description,
        'toc': [for (final e in toc) {'title': e.title, 'level': e.level, 'page': ?e.page}],
        'volumes': volumes,
        'hasPdf': hasPdf,
        'pageMap': pageMap,
        'volumeBounds': {for (final e in volumeBounds.entries) e.key: [e.value.$1, e.value.$2]},
        'pdf': ?pdf?.toJson(),
      };

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
        pdf: PdfLinks.parse(j['pdf']),
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
    this.narrators = const [],
  });

  final String bookId;
  final String bookTitle;

  /// Narrators linked in the page (hadith chains), in order: id and name as
  /// written on the page.
  final List<({String id, String name})> narrators;
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
      text: decodeHtmlEntities(j['text'] as String? ?? ''),
      snippet: j['snippet'] == null ? null : decodeHtmlEntities('${j['snippet']}'),
      url: j['url'] as String? ?? '',
      citation: j['citation'] as String?,
      shamelaUrl: (j['alternateUrls'] as Map?)?['shamela'] as String?,
      narrators: [
        for (final n in j['narrators'] as List? ?? const [])
          if (n is Map && n['id'] != null) (id: '${n['id']}', name: '${n['name'] ?? ''}'),
      ],
    );
  }

  /// The same shape [PagePassage.fromJson] reads (used to keep pages offline).
  Map<String, dynamic> toJson() => {
        'book': {'id': bookId, 'title': bookTitle},
        'author': {'id': ?authorId, 'name': ?authorName},
        'category': {'id': ?categoryId},
        'location': {'internalPage': ?internalPage, 'printedPage': ?printedPage, 'volume': ?volume},
        'headings': headings,
        'text': text,
        'snippet': ?snippet,
        'url': url,
        'citation': ?citation,
        'alternateUrls': {'shamela': ?shamelaUrl},
        if (narrators.isNotEmpty) 'narrators': [for (final n in narrators) {'id': n.id, 'name': n.name}],
      };

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
        narrators: narrators,
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

/// The model's reading of a book's layers: which delimiters hold the matn
/// (base text of a commentary) and which hold Quran verses.
class LayersGuess {
  const LayersGuess({this.isCommentary = false, this.pages = const [], this.quran = const [], this.note = ''});
  final bool isCommentary;

  /// Per sample page: matn stretches by their first and last words.
  final List<List<(String, String)>> pages;
  final List<String> quran;
  final String note;

  factory LayersGuess.fromJson(Map<String, dynamic> j) => LayersGuess(
        isCommentary: j['isCommentary'] == true,
        pages: [
          for (final p in j['pages'] as List? ?? const [])
            [
              if (p is Map)
                for (final m in p['matn'] as List? ?? const [])
                  if (m is Map && '${m['start'] ?? ''}'.trim().isNotEmpty) ('${m['start']}', '${m['end'] ?? m['start']}'),
            ],
        ],
        quran: [for (final m in j['quranMarkers'] as List? ?? const []) '$m'],
        note: j['note'] as String? ?? '',
      );
}

/// One of Turath's 18,000+ narrators (رواة).
class Narrator {
  const Narrator({required this.id, required this.name, this.fullName = '', this.death, this.deathText = '', this.rank = '', this.summary = const []});
  final String id;
  final String name;
  final String fullName;
  final int? death;
  final String deathText;

  /// The critics' grading (e.g. ثقة، صحابي).
  final String rank;

  /// Biography facts as label/value pairs (only when fetched one by one).
  final List<(String, String)> summary;

  factory Narrator.fromJson(Map<String, dynamic> j) => Narrator(
        id: '${j['id']}',
        name: '${j['name'] ?? ''}'.trim(),
        fullName: '${j['full_name'] ?? ''}'.trim(),
        death: (j['death'] as num?)?.toInt(),
        deathText: '${j['death_text'] ?? ''}'.trim(),
        rank: '${j['rank'] ?? ''}'.trim(),
        summary: [
          for (final row in j['summary'] as List? ?? const [])
            if (row is List && row.length >= 2 && '${row[1]}'.trim().isNotEmpty) ('${row[0]}', '${row[1]}'),
        ],
      );
}

class NarratorPage {
  const NarratorPage({required this.items, required this.count, required this.page});
  final List<Narrator> items;
  final int count;
  final int page;

  factory NarratorPage.fromJson(Map<String, dynamic> j) => NarratorPage(
        items: [for (final n in j['data'] as List? ?? const []) if (n is Map) Narrator.fromJson(n.cast<String, dynamic>())],
        count: (j['count'] as num?)?.toInt() ?? 0,
        page: (j['page'] as num?)?.toInt() ?? 1,
      );
}
