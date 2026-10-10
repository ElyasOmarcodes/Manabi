import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// Where the reader left a book.
class ReadingPosition {
  const ReadingPosition({required this.bookId, required this.bookTitle, required this.page, required this.at});
  final String bookId;
  final String bookTitle;
  final int page;
  final DateTime at;
}

/// Bookmarks, last-read pages and reader display settings, kept on the device.
class ReadingController extends ChangeNotifier {
  SharedPreferences? _prefs;
  final List<Bookmark> bookmarks = [];
  final Map<String, ReadingPosition> _positions = {};

  /// Reader text size (multiplies the Arabic text size) and line spacing.
  double fontScale = 1.0;
  double lineHeight = 2.1;

  /// 'paper' (warm page), 'plain' (follows the app theme) or 'night'.
  String paper = 'paper';

  Future<void> load() async {
    final prefs = _prefs = await SharedPreferences.getInstance();
    try {
      final list = jsonDecode(prefs.getString('bookmarks') ?? '[]') as List;
      bookmarks
        ..clear()
        ..addAll(list.whereType<Map>().map((m) => Bookmark.fromJson(m.cast<String, dynamic>())));
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
    fontScale = prefs.getDouble('readerFontScale') ?? 1.0;
    lineHeight = prefs.getDouble('readerLineHeight') ?? 2.1;
    paper = prefs.getString('readerPaper') ?? 'paper';
    notifyListeners();
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

  Future<void> savePosition(String bookId, String title, int page) async {
    _positions[bookId] = ReadingPosition(bookId: bookId, bookTitle: title, page: page, at: DateTime.now());
    // Keep the most recent 40 books.
    final keep = recent.take(40).map((p) => p.bookId).toSet();
    _positions.removeWhere((k, _) => !keep.contains(k));
    await _prefs?.setString(
        'readingPositions', jsonEncode({for (final p in _positions.values) p.bookId: {'title': p.bookTitle, 'page': p.page, 'at': p.at.toIso8601String()}}));
    notifyListeners();
  }

  Future<void> setFontScale(double v) async {
    fontScale = v;
    await _prefs?.setDouble('readerFontScale', v);
    notifyListeners();
  }

  Future<void> setLineHeight(double v) async {
    lineHeight = v;
    await _prefs?.setDouble('readerLineHeight', v);
    notifyListeners();
  }

  Future<void> setPaper(String v) async {
    paper = v;
    await _prefs?.setString('readerPaper', v);
    notifyListeners();
  }
}
