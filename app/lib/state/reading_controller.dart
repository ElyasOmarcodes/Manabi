import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/turath/text_layers.dart' show MatnRules;

/// A saved page in a book.
class Bookmark {
  const Bookmark({required this.bookId, required this.bookTitle, required this.page, this.volume, this.printed, this.heading, required this.savedAt});
  final String bookId;
  final String bookTitle;
  final int page;
  final String? volume;
  final int? printed;
  final String? heading;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'bookTitle': bookTitle,
        'page': page,
        if (volume != null) 'volume': volume,
        if (printed != null) 'printed': printed,
        if (heading != null) 'heading': heading,
        'savedAt': savedAt.toIso8601String(),
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        bookId: '${j['bookId']}',
        bookTitle: j['bookTitle'] as String? ?? '',
        page: (j['page'] as num?)?.toInt() ?? 1,
        volume: j['volume'] as String?,
        printed: (j['printed'] as num?)?.toInt(),
        heading: j['heading'] as String?,
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// A passage the reader highlighted on a page.
class Highlight {
  const Highlight({required this.bookId, required this.bookTitle, required this.page, required this.text, this.color = 0, this.note, required this.savedAt, this.part, this.start});
  final String bookId;
  final String bookTitle;
  final int page;
  final String text;

  /// Index into [highlightColors].
  final int color;
  final String? note;
  final DateTime savedAt;

  /// Where on the page: 'title', 'body' or 'notes', and the offset of the
  /// text there counted without diacritics (see highlight_anchor.dart).
  /// Older highlights have neither.
  final String? part;
  final int? start;

  /// The same mark (same page, text and place).
  bool sameAs(Highlight o) => o.bookId == bookId && o.page == page && o.text == text && o.part == part && o.start == start;

  Map<String, dynamic> toJson() => {
        'bookId': bookId,
        'bookTitle': bookTitle,
        'page': page,
        'text': text,
        'color': color,
        if (note != null) 'note': note,
        'savedAt': savedAt.toIso8601String(),
        if (part != null) 'part': part,
        if (start != null) 'start': start,
      };

  factory Highlight.fromJson(Map<String, dynamic> j) => Highlight(
        bookId: '${j['bookId']}',
        bookTitle: j['bookTitle'] as String? ?? '',
        page: (j['page'] as num?)?.toInt() ?? 1,
        text: j['text'] as String? ?? '',
        color: (j['color'] as num?)?.toInt() ?? 0,
        note: j['note'] as String?,
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
        part: j['part'] as String?,
        start: (j['start'] as num?)?.toInt(),
      );
}

/// How one book's text is layered: whether its matn (the base text of a
/// commentary) is set apart, by which delimiters, and whether braces hold
/// verses in it.
class BookLayers {
  const BookLayers({
    this.enabled = false,
    this.matn = const [],
    this.verified = const [],
    this.block = false,
    this.bracesAreVerses = false,
    this.source = 'manual',
    this.aiPages = false,
    this.agreement,
    this.note = '',
  });
  final bool enabled;

  /// Delimiters whose content is always matn.
  final List<String> matn;

  /// Delimiters whose content is matn when its words are in the matn.
  final List<String> verified;

  /// The text above the ــ line on top of a page is matn.
  final bool block;
  final bool bracesAreVerses;

  /// 'manual', 'auto' (detected from the pages) or 'ai'.
  final String source;

  /// The AI marks the matn of every page read (most precise).
  final bool aiPages;

  /// How closely the rules matched the AI's marking of sample pages (0…1).
  final double? agreement;
  final String note;

  MatnRules get rules => MatnRules(block: block, always: matn, verified: verified);

  BookLayers copyWith({
    bool? enabled,
    List<String>? matn,
    List<String>? verified,
    bool? block,
    bool? bracesAreVerses,
    String? source,
    bool? aiPages,
    double? agreement,
    String? note,
  }) =>
      BookLayers(
        enabled: enabled ?? this.enabled,
        matn: matn ?? this.matn,
        verified: verified ?? this.verified,
        block: block ?? this.block,
        bracesAreVerses: bracesAreVerses ?? this.bracesAreVerses,
        source: source ?? this.source,
        aiPages: aiPages ?? this.aiPages,
        agreement: agreement ?? this.agreement,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'matn': matn,
        'verified': verified,
        'block': block,
        'braces': bracesAreVerses,
        'source': source,
        'aiPages': aiPages,
        'agreement': ?agreement,
        if (note.isNotEmpty) 'note': note,
      };

  factory BookLayers.fromJson(Map<String, dynamic> j) => BookLayers(
        enabled: j['enabled'] == true,
        matn: [for (final m in j['matn'] as List? ?? const []) '$m'],
        verified: [for (final m in j['verified'] as List? ?? const []) '$m'],
        block: j['block'] == true,
        bracesAreVerses: j['braces'] == true,
        source: j['source'] as String? ?? 'manual',
        aiPages: j['aiPages'] == true,
        agreement: (j['agreement'] as num?)?.toDouble(),
        note: j['note'] as String? ?? '',
      );
}

/// A book the reader starred.
class FavoriteBook {
  const FavoriteBook({required this.bookId, required this.title, required this.at});
  final String bookId;
  final String title;
  final DateTime at;
}

/// Where the reader left a book.
class ReadingPosition {
  const ReadingPosition({required this.bookId, required this.bookTitle, required this.page, required this.at});
  final String bookId;
  final String bookTitle;
  final int page;
  final DateTime at;
}

/// Bookmarks, highlights, favourite books, reading history and reader
/// settings, kept on the device.
class ReadingController extends ChangeNotifier {
  SharedPreferences? _prefs;
  final List<Bookmark> bookmarks = [];
  final List<Highlight> highlights = [];
  final List<FavoriteBook> favorites = [];
  final Map<String, ReadingPosition> _positions = {};

  /// Matn / verse layers per book.
  final Map<String, BookLayers> _layers = {};

  /// Per book: PDF page minus printed page, when the scan's numbering differs.
  final Map<String, int> _pdfOffsets = {};

  /// Pages visited per book, newest first (the reader's "history" tab).
  final Map<String, List<int>> _visited = {};

  /// Reader text size (multiplies the Arabic text size) and line spacing.
  double fontScale = defaultFontScale;

  /// 90% on phones, 95% on larger screens.
  static double get defaultFontScale => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS ? 0.9 : 0.95;
  double lineHeight = 2.1;

  /// 'paper' (warm page), 'sepia' (yellow page), 'plain' (follows the app
  /// theme) or 'night'.
  String paper = 'plain';

  /// 'scroll' (continuous pages, like Turath) or 'pages' (swipe page by page).
  String readingMode = 'scroll';

  /// Arabic face of the book text: 'amiri', 'naskh', 'scheherazade', 'plex' or 'vazir'.
  String fontFamily = 'plex';

  /// Justify lines (Arabic books are typeset justified).
  bool justify = true;

  /// Hide harakat while reading; search and copy keep the full text.
  bool hideDiacritics = false;

  /// Show the footnotes under each page.
  bool showFootnotes = true;

  /// Keep the screen awake in the reader.
  bool keepAwake = false;

  /// Page numbers in Arabic-Indic (٠١٢) or Latin (012) digits.
  String digits = 'arabic';

  /// Default highlight colour (index into [highlightColors]).
  int highlightColor = 0;

  /// The library tab opened first: 'books', 'authors', 'categories', 'search'.
  String libraryTab = 'books';

  /// Verses (﴿…﴾) in the Quran face and colour.
  bool styleQuran = true;
  int quranColor = 0;

  /// 'quran' (Amiri Quran) or 'book' (the book face).
  String quranFont = 'quran';

  /// Colour and weight of the matn in commentaries.
  int matnColor = 0;
  bool matnBold = true;

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    try {
      final list = jsonDecode(prefs.getString('bookmarks') ?? '[]') as List;
      bookmarks
        ..clear()
        ..addAll(list.whereType<Map>().map((m) => Bookmark.fromJson(m.cast<String, dynamic>())));
      final marks = jsonDecode(prefs.getString('highlights') ?? '[]') as List;
      highlights
        ..clear()
        ..addAll(marks.whereType<Map>().map((m) => Highlight.fromJson(m.cast<String, dynamic>())));
      final favs = jsonDecode(prefs.getString('favoriteBooks') ?? '[]') as List;
      favorites
        ..clear()
        ..addAll(favs.whereType<Map>().map((m) => FavoriteBook(
              bookId: '${m['id']}',
              title: m['title'] as String? ?? '',
              at: DateTime.tryParse(m['at'] as String? ?? '') ?? DateTime.now(),
            )));
      final layers = jsonDecode(prefs.getString('bookLayers') ?? '{}') as Map;
      layers.forEach((k, v) {
        if (v is Map) _layers['$k'] = BookLayers.fromJson(v.cast<String, dynamic>());
      });
      final offsets = jsonDecode(prefs.getString('pdfOffsets') ?? '{}') as Map;
      offsets.forEach((k, v) {
        if (v is num) _pdfOffsets['$k'] = v.toInt();
      });
      final visited = jsonDecode(prefs.getString('visitedPages') ?? '{}') as Map;
      visited.forEach((k, v) {
        if (v is List) _visited['$k'] = [for (final p in v) if (p is num) p.toInt()];
      });
      final pos = jsonDecode(prefs.getString('readingPositions') ?? '{}') as Map;
      pos.forEach((k, v) {
        if (v is Map) {
          _positions['$k'] = ReadingPosition(
            bookId: '$k',
            bookTitle: v['title'] as String? ?? '',
            page: (v['page'] as num?)?.toInt() ?? 1,
            at: DateTime.tryParse(v['at'] as String? ?? '') ?? DateTime.now(),
          );
        }
      });
    } catch (_) {
      // Corrupt data is ignored rather than blocking the reader.
    }
    fontScale = prefs.getDouble('readerFontScale') ?? defaultFontScale;
    lineHeight = prefs.getDouble('readerLineHeight') ?? 2.1;
    paper = prefs.getString('readerPaper') ?? 'plain';
    readingMode = prefs.getString('readerMode') ?? 'scroll';
    fontFamily = prefs.getString('readerFont') ?? 'plex';
    justify = prefs.getBool('readerJustify') ?? true;
    hideDiacritics = prefs.getBool('readerHideDiacritics') ?? false;
    showFootnotes = prefs.getBool('readerFootnotes') ?? true;
    keepAwake = prefs.getBool('readerKeepAwake') ?? false;
    digits = prefs.getString('readerDigits') ?? 'arabic';
    highlightColor = prefs.getInt('readerHighlightColor') ?? 0;
    libraryTab = prefs.getString('libraryTab') ?? 'books';
    styleQuran = prefs.getBool('readerStyleQuran') ?? true;
    quranColor = prefs.getInt('readerQuranColor') ?? 0;
    quranFont = prefs.getString('readerQuranFont') ?? 'quran';
    matnColor = prefs.getInt('readerMatnColor') ?? 0;
    matnBold = prefs.getBool('readerMatnBold') ?? true;
    notifyListeners();
  }

  // ── Text layers ────────────────────────────────────────────────────

  BookLayers layersOf(String bookId) => _layers[bookId] ?? const BookLayers();

  /// Has the book's layering been set, by the reader or by detection?
  bool hasLayers(String bookId) => _layers.containsKey(bookId);

  Future<void> setLayers(String bookId, BookLayers value) async {
    _layers[bookId] = value;
    await _prefs?.setString('bookLayers', jsonEncode({for (final e in _layers.entries) e.key: e.value.toJson()}));
    notifyListeners();
  }

  int pdfOffsetOf(String bookId) => _pdfOffsets[bookId] ?? 0;

  Future<void> setPdfOffset(String bookId, int value) async {
    if (value == 0) {
      _pdfOffsets.remove(bookId);
    } else {
      _pdfOffsets[bookId] = value;
    }
    await _prefs?.setString('pdfOffsets', jsonEncode(_pdfOffsets));
    notifyListeners();
  }

  Future<void> setStyleQuran(bool v) => _setBool('readerStyleQuran', v, () => styleQuran = v);
  Future<void> setQuranFont(String v) => _setString('readerQuranFont', v, () => quranFont = v);
  Future<void> setMatnBold(bool v) => _setBool('readerMatnBold', v, () => matnBold = v);

  Future<void> setQuranColor(int v) async {
    quranColor = v;
    await _prefs?.setInt('readerQuranColor', v);
    notifyListeners();
  }

  Future<void> setMatnColor(int v) async {
    matnColor = v;
    await _prefs?.setInt('readerMatnColor', v);
    notifyListeners();
  }

  // ── Favourite books ────────────────────────────────────────────────

  bool isFavorite(String bookId) => favorites.any((f) => f.bookId == bookId);

  Future<void> toggleFavorite(String bookId, String title) async {
    final i = favorites.indexWhere((f) => f.bookId == bookId);
    if (i >= 0) {
      favorites.removeAt(i);
    } else {
      favorites.insert(0, FavoriteBook(bookId: bookId, title: title, at: DateTime.now()));
    }
    await _prefs?.setString('favoriteBooks', jsonEncode([for (final f in favorites) {'id': f.bookId, 'title': f.title, 'at': f.at.toIso8601String()}]));
    notifyListeners();
  }

  // ── Highlights ─────────────────────────────────────────────────────

  List<Highlight> highlightsOf(String bookId, [int? page]) =>
      [for (final h in highlights) if (h.bookId == bookId && (page == null || h.page == page)) h];

  Future<void> addHighlight(Highlight h) async {
    highlights.removeWhere(h.sameAs);
    highlights.insert(0, h);
    await _saveHighlights();
  }

  Future<void> removeHighlight(Highlight h) async {
    highlights.removeWhere(h.sameAs);
    await _saveHighlights();
  }

  /// Removes several marks and adds several, saved once.
  Future<void> replaceHighlights({List<Highlight> remove = const [], List<Highlight> add = const []}) async {
    for (final h in [...remove, ...add]) {
      highlights.removeWhere(h.sameAs);
    }
    highlights.insertAll(0, add);
    await _saveHighlights();
  }

  Future<void> _saveHighlights() async {
    await _prefs?.setString('highlights', jsonEncode([for (final x in highlights) x.toJson()]));
    notifyListeners();
  }

  // ── Page history ───────────────────────────────────────────────────

  List<int> visitedOf(String bookId) => _visited[bookId] ?? const [];

  void _visit(String bookId, int page) {
    final list = _visited.putIfAbsent(bookId, () => []);
    list
      ..remove(page)
      ..insert(0, page);
    if (list.length > 40) list.removeRange(40, list.length);
  }

  /// Forgets last-read positions and visited pages (bookmarks, highlights
  /// and favourites stay).
  Future<void> clearHistory() async {
    _positions.clear();
    _visited.clear();
    await _prefs?.remove('readingPositions');
    await _prefs?.remove('visitedPages');
    notifyListeners();
  }

  /// Removes everything the reader saved on this device.
  Future<void> clearAll() async {
    bookmarks.clear();
    highlights.clear();
    favorites.clear();
    for (final k in ['bookmarks', 'highlights', 'favoriteBooks']) {
      await _prefs?.remove(k);
    }
    await clearHistory();
  }

  List<Bookmark> bookmarksOf(String bookId) => [for (final b in bookmarks) if (b.bookId == bookId) b];

  bool isBookmarked(String bookId, int page) => bookmarks.any((b) => b.bookId == bookId && b.page == page);

  Future<void> toggleBookmark(Bookmark b) async {
    final i = bookmarks.indexWhere((x) => x.bookId == b.bookId && x.page == b.page);
    if (i >= 0) {
      bookmarks.removeAt(i);
    } else {
      bookmarks.insert(0, b);
    }
    await _prefs?.setString('bookmarks', jsonEncode([for (final x in bookmarks) x.toJson()]));
    notifyListeners();
  }

  ReadingPosition? positionOf(String bookId) => _positions[bookId];

  /// Recently read books, newest first.
  List<ReadingPosition> get recent => _positions.values.toList()..sort((a, b) => b.at.compareTo(a.at));

  /// With [notify] false (the reader, on every page) listeners are told
  /// later through [notifyPositions], so pages do not rebuild while scrolling.
  Future<void> savePosition(String bookId, String title, int page, {bool notify = true}) async {
    _positions[bookId] = ReadingPosition(bookId: bookId, bookTitle: title, page: page, at: DateTime.now());
    _visit(bookId, page);
    // Keep the most recent 40 books.
    final keep = recent.take(40).map((p) => p.bookId).toSet();
    _positions.removeWhere((k, _) => !keep.contains(k));
    _visited.removeWhere((k, _) => !keep.contains(k));
    await _prefs?.setString('visitedPages', jsonEncode(_visited));
    await _prefs?.setString(
        'readingPositions', jsonEncode({for (final p in _positions.values) p.bookId: {'title': p.bookTitle, 'page': p.page, 'at': p.at.toIso8601String()}}));
    if (notify) notifyListeners();
  }

  void notifyPositions() => notifyListeners();

  Future<void> setFontScale(double v) async {
    fontScale = v;
    notifyListeners();
    await _prefs?.setDouble('readerFontScale', v);
  }

  Future<void> setLineHeight(double v) async {
    lineHeight = v;
    notifyListeners();
    await _prefs?.setDouble('readerLineHeight', v);
  }

  Future<void> setPaper(String v) async {
    paper = v;
    await _prefs?.setString('readerPaper', v);
    notifyListeners();
  }

  Future<void> setReadingMode(String v) => _setString('readerMode', v, () => readingMode = v);
  Future<void> setFontFamily(String v) => _setString('readerFont', v, () => fontFamily = v);
  Future<void> setDigits(String v) => _setString('readerDigits', v, () => digits = v);
  Future<void> setLibraryTab(String v) => _setString('libraryTab', v, () => libraryTab = v);
  Future<void> setJustify(bool v) => _setBool('readerJustify', v, () => justify = v);
  Future<void> setHideDiacritics(bool v) => _setBool('readerHideDiacritics', v, () => hideDiacritics = v);
  Future<void> setShowFootnotes(bool v) => _setBool('readerFootnotes', v, () => showFootnotes = v);
  Future<void> setKeepAwake(bool v) => _setBool('readerKeepAwake', v, () => keepAwake = v);

  Future<void> setHighlightColor(int v) async {
    highlightColor = v;
    await _prefs?.setInt('readerHighlightColor', v);
    notifyListeners();
  }

  /// Puts every reader setting back to its default.
  Future<void> resetDisplay() async {
    for (final k in [
      'readerFontScale', 'readerLineHeight', 'readerPaper', 'readerMode', 'readerFont', 'readerJustify', 'readerHideDiacritics', 'readerFootnotes', //
      'readerKeepAwake', 'readerDigits', 'readerHighlightColor', 'readerStyleQuran', 'readerQuranColor', 'readerQuranFont', 'readerMatnColor', 'readerMatnBold',
    ]) {
      await _prefs?.remove(k);
    }
    fontScale = defaultFontScale;
    lineHeight = 2.1;
    paper = 'plain';
    readingMode = 'scroll';
    fontFamily = 'plex';
    justify = true;
    hideDiacritics = false;
    showFootnotes = true;
    keepAwake = false;
    digits = 'arabic';
    highlightColor = 0;
    styleQuran = true;
    quranColor = 0;
    quranFont = 'quran';
    matnColor = 0;
    matnBold = true;
    notifyListeners();
  }

  Future<void> _setString(String key, String v, void Function() apply) async {
    apply();
    await _prefs?.setString(key, v);
    notifyListeners();
  }

  Future<void> _setBool(String key, bool v, void Function() apply) async {
    apply();
    await _prefs?.setBool(key, v);
    notifyListeners();
  }
}

/// Verse colours (light, dark): blue as in Turath, green, teal, violet, ink.
const quranColors = [
  (Color(0xFF1565C0), Color(0xFF82B1FF)),
  (Color(0xFF2E7D32), Color(0xFF81C784)),
  (Color(0xFF00897B), Color(0xFF4DB6AC)),
  (Color(0xFF6C5CE7), Color(0xFFA29BFE)),
  (Color(0xFF2B2620), Color(0xFFE8E1D3)),
];

/// Matn colours (light, dark): the red of printed commentaries, brown, violet, teal, ink.
const matnColors = [
  (Color(0xFFB3261E), Color(0xFFFF8A80)),
  (Color(0xFF8D5524), Color(0xFFE0A86B)),
  (Color(0xFF6C5CE7), Color(0xFFA29BFE)),
  (Color(0xFF00796B), Color(0xFF4DB6AC)),
  (Color(0xFF2B2620), Color(0xFFE8E1D3)),
];

/// Highlight colours: amber, green, blue, rose.
const highlightColors = [Color(0xFFF5C451), Color(0xFF6FD39A), Color(0xFF7CB8F7), Color(0xFFF59AB8)];

final _harakat = RegExp('[\u064B-\u0652\u0670\u0640]');

/// The text without harakat and tatweel.
String stripDiacritics(String text) => text.replaceAll(_harakat, '');

/// Formats a number in the reader's digit style.
String readerDigits(Object n, String style) {
  final s = '$n';
  if (style != 'arabic') return s;
  const ar = '٠١٢٣٤٥٦٧٨٩';
  return s.replaceAllMapped(RegExp('[0-9]'), (m) => ar[int.parse(m[0]!)]);
}
