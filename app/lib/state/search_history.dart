import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Phrases searched before, everywhere and per book, offered again while
/// typing. Kept on the device only.
class SearchHistory {
  SearchHistory._();

  static const _key = 'searchHistory';
  static const _global = '*';
  static const _maxGlobal = 40;
  static const _maxBook = 20;
  static SharedPreferences? _prefs;
  static Map<String, List<String>> _lists = {};

  static Future<void> open() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_key);
      if (raw != null) {
        _lists = {for (final e in (jsonDecode(raw) as Map).entries) '${e.key}': [for (final q in e.value as List) '$q']};
      }
    } catch (_) {
      _lists = {};
    }
  }

  static void _save() => _prefs?.setString(_key, jsonEncode(_lists));

  /// Arabic letters compared without diacritics and letter variants.
  static String fold(String s) => s
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[إأآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .toLowerCase();

  static void _push(String list, String q, int max) {
    final items = _lists.putIfAbsent(list, () => []);
    items.removeWhere((x) => fold(x) == fold(q));
    items.insert(0, q);
    if (items.length > max) items.removeRange(max, items.length);
  }

  /// Remembers a search; one made inside a book is kept for that book too.
  static void add(String query, {String? bookId}) {
    final q = query.trim();
    if (q.isEmpty || q.length > 120) return;
    _push(_global, q, _maxGlobal);
    if (bookId != null) _push(bookId, q, _maxBook);
    _save();
  }

  static void remove(String query, {String? bookId}) {
    for (final list in [_global, ?bookId]) {
      _lists[list]?.removeWhere((x) => fold(x) == fold(query));
    }
    _save();
  }

  /// Earlier searches that contain what is typed (all recent ones when the
  /// field is empty): this book's first, then the rest; each marked with
  /// whether it came from the book.
  static List<({String text, bool inBook})> suggest(String typed, {String? bookId, int max = 6}) {
    final t = fold(typed);
    final seen = <String>{};
    final out = <({String text, bool inBook})>[];
    void take(List<String>? list, bool inBook) {
      for (final q in list ?? const <String>[]) {
        final f = fold(q);
        if (out.length >= max) return;
        if (f == t || (t.isNotEmpty && !f.contains(t)) || !seen.add(f)) continue;
        out.add((text: q, inBook: inBook));
      }
    }

    if (bookId != null) take(_lists[bookId], true);
    take(_lists[_global], false);
    return out;
  }

  /// For tests.
  static void reset() => _lists = {};
}
