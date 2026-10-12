/// One picked book, author or category, with its name for labels.
typedef ScopeRef = ({String id, String name});

/// One search Turath can run: at most one book, author and category.
typedef ScopeTarget = ({String? bookId, String? authorId, String? categoryId});

/// Where a question or a search looks: any number of books, authors and
/// categories. Turath filters one of each per search, so a scope stands for
/// several searches ([targets]): every chosen book, plus every chosen author
/// within every chosen category. Empty lists mean the whole library.
class SearchScope {
  const SearchScope({this.books = const [], this.authors = const [], this.categories = const []});

  /// One book, author and/or category, searched together (one search).
  factory SearchScope.single({String? bookId, String? bookTitle, String? authorId, String? authorName, String? categoryId, String? categoryTitle}) => SearchScope(
        books: [if (bookId != null) (id: bookId, name: bookTitle ?? '')],
        authors: [if (authorId != null) (id: authorId, name: authorName ?? '')],
        categories: [if (categoryId != null) (id: categoryId, name: categoryTitle ?? '')],
      );

  static const all = SearchScope();

  /// Most searches a scope may stand for.
  static const maxTargets = 12;

  final List<ScopeRef> books;
  final List<ScopeRef> authors;
  final List<ScopeRef> categories;

  bool get isAll => books.isEmpty && authors.isEmpty && categories.isEmpty;

  /// The one book when the scope is exactly one book (else null).
  String? get bookId => books.length == 1 && authors.isEmpty && categories.isEmpty ? books.first.id : null;
  String? get bookTitle => books.length == 1 ? books.first.name : null;
  String? get authorName => authors.length == 1 ? authors.first.name : null;
  String? get categoryTitle => categories.length == 1 ? categories.first.name : null;

  /// The searches this scope stands for; one empty target for the whole
  /// library.
  List<ScopeTarget> get targets {
    if (isAll) return const [(bookId: null, authorId: null, categoryId: null)];
    // One book with its author or category: the book alone.
    final out = <ScopeTarget>[for (final b in books) (bookId: b.id, authorId: null, categoryId: null)];
    final singleBook = books.length == 1 && authors.length <= 1 && categories.length <= 1;
    if (!singleBook && (authors.isNotEmpty || categories.isNotEmpty)) {
      for (final a in authors.isEmpty ? const <ScopeRef?>[null] : authors) {
        for (final c in categories.isEmpty ? const <ScopeRef?>[null] : categories) {
          out.add((bookId: null, authorId: a?.id, categoryId: c?.id));
        }
      }
    }
    return out.take(maxTargets).toList();
  }

  /// Names for a pill: "A · B +2".
  String label({int show = 2}) {
    final names = [for (final r in [...books, ...authors, ...categories]) r.name.isEmpty ? r.id : r.name];
    if (names.length <= show) return names.join(' · ');
    return '${names.take(show).join(' · ')} +${names.length - show}';
  }

  SearchScope copyWith({List<ScopeRef>? books, List<ScopeRef>? authors, List<ScopeRef>? categories}) =>
      SearchScope(books: books ?? this.books, authors: authors ?? this.authors, categories: categories ?? this.categories);

  /// Replaces the books (the older single-pick calls).
  SearchScope withBook(String? id, String? title) => copyWith(books: [if (id != null) (id: id, name: title ?? '')]);
  SearchScope withAuthor(String? id, String? name) => copyWith(authors: [if (id != null) (id: id, name: name ?? '')]);
  SearchScope withCategory(String? id, String? title) => copyWith(categories: [if (id != null) (id: id, name: title ?? '')]);

  /// The request shape understood by the server: comma-separated ids.
  Map<String, String> toRequest() => isAll
      ? const {}
      : {
          'bookIds': books.map((r) => r.id).join(','),
          'authorIds': authors.map((r) => r.id).join(','),
          'categoryIds': categories.map((r) => r.id).join(','),
          // Older servers read only these.
          if (books.length == 1) 'bookId': books.first.id,
          if (authors.length == 1 && books.isEmpty) 'authorId': authors.first.id,
          if (categories.length == 1 && books.isEmpty) 'categoryId': categories.first.id,
        };

  static List<ScopeRef> _refs(Object? raw) => [
        for (final r in raw is List ? raw : const [])
          if (r is Map && r['id'] != null) (id: '${r['id']}', name: '${r['name'] ?? ''}'),
      ];

  factory SearchScope.fromJson(Map<String, dynamic>? j) {
    if (j == null) return all;
    if (j.containsKey('books') || j.containsKey('authors') || j.containsKey('categories')) {
      return SearchScope(books: _refs(j['books']), authors: _refs(j['authors']), categories: _refs(j['categories']));
    }
    // Saved before scopes held lists.
    return SearchScope.single(
      bookId: j['bookId'] as String?,
      bookTitle: j['bookTitle'] as String?,
      authorId: j['authorId'] as String?,
      authorName: j['authorName'] as String?,
      categoryId: j['categoryId'] as String?,
      categoryTitle: j['categoryTitle'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        if (books.isNotEmpty) 'books': [for (final r in books) {'id': r.id, 'name': r.name}],
        if (authors.isNotEmpty) 'authors': [for (final r in authors) {'id': r.id, 'name': r.name}],
        if (categories.isNotEmpty) 'categories': [for (final r in categories) {'id': r.id, 'name': r.name}],
      };

  static String _ids(List<ScopeRef> r) => r.map((x) => x.id).join(',');

  @override
  bool operator ==(Object other) =>
      other is SearchScope && _ids(other.books) == _ids(books) && _ids(other.authors) == _ids(authors) && _ids(other.categories) == _ids(categories);

  @override
  int get hashCode => Object.hash(_ids(books), _ids(authors), _ids(categories));
}

/// Options of Turath's full-text search (as on app.turath.io).
class TextSearchOptions {
  const TextSearchOptions({this.precision = 2, this.stem = true, this.notes = true, this.toc = false});
  static const standard = TextSearchOptions();

  /// 1: some of the words, 2: all the words, 3: the words in order.
  final int precision;

  /// Other forms of the words too (Turath's "البحث الموسع").
  final bool stem;

  /// Footnotes and editors' introductions too.
  final bool notes;

  /// Search the books' tables of contents instead of their text.
  final bool toc;

  bool get isStandard => precision == 2 && stem && notes && !toc;

  TextSearchOptions copyWith({int? precision, bool? stem, bool? notes, bool? toc}) =>
      TextSearchOptions(precision: precision ?? this.precision, stem: stem ?? this.stem, notes: notes ?? this.notes, toc: toc ?? this.toc);

  /// Query parameters for the Manabi server.
  Map<String, String> toRequest() => {
        if (precision != 2) 'precision': '$precision',
        if (!stem) 'stem': '0',
        if (!notes) 'notes': '0',
        if (toc) 'toc': '1',
      };

  /// Parameters of Turath's own API.
  Map<String, Object> toTurath() => {
        'precision': precision,
        if (!stem) 'stem': 0,
        if (!notes) 'non_author': 0,
        if (toc) 'scope': 'toc',
      };

  Map<String, dynamic> toJson() => {'precision': precision, 'stem': stem, 'notes': notes, 'toc': toc};
  factory TextSearchOptions.fromJson(Map<String, dynamic>? j) => j == null
      ? standard
      : TextSearchOptions(
          precision: (j['precision'] as num?)?.toInt() ?? 2,
          stem: j['stem'] != false,
          notes: j['notes'] != false,
          toc: j['toc'] == true,
        );
}
