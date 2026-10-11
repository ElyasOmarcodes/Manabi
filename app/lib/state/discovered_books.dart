import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/catalog/catalog_service.dart';
import '../core/models/answer.dart';
import '../core/models/library.dart';

/// Turath books outside the bundled catalog snapshot, found while using the
/// app (search results, answers, opened links, the server's shared list).
/// They are kept on the device and join the library: its lists, authors and
/// title search.
class DiscoveredBooks {
  DiscoveredBooks._();

  static Box<String>? _box;
  static CatalogService? _catalog;

  static Future<void> open(CatalogService catalog) async {
    _catalog = catalog;
    try {
      _box = await Hive.openBox<String>('discovered_books');
      catalog.addBooks([
        for (final raw in _box!.values) ?_decode(raw),
      ]);
    } catch (e) {
      debugPrint('discovered_books: $e');
    }
  }

  static ({CatalogBook book, String? authorName})? _decode(String raw) {
    try {
      final j = jsonDecode(raw) as Map;
      return (book: CatalogBook('${j['id']}', '${j['title']}', '${j['authorId'] ?? ''}', '${j['categoryId'] ?? ''}'), authorName: j['author'] as String?);
    } catch (_) {
      return null;
    }
  }

  static void note(String id, String title, {String? authorId, String? authorName, String? categoryId}) {
    final catalog = _catalog;
    if (catalog == null || id.isEmpty || title.trim().isEmpty || catalog.book(id) != null) return;
    final book = CatalogBook(id, title.trim(), authorId ?? '', categoryId ?? '');
    if (catalog.addBooks([(book: book, authorName: authorName)]) == 0) return;
    _box?.put(id, jsonEncode({'id': id, 'title': book.title, 'authorId': ?authorId, 'author': ?authorName, 'categoryId': ?categoryId})).catchError((Object _) {});
  }

  static void notePassages(Iterable<PagePassage> passages) {
    for (final p in passages) {
      note(p.bookId, p.bookTitle, authorId: p.authorId, authorName: p.authorName, categoryId: p.categoryId);
    }
  }

  static void noteSources(Iterable<AnswerSource> sources) {
    for (final s in sources) {
      note(s.bookId, s.bookTitle, authorId: s.authorId, authorName: s.authorName, categoryId: s.categoryId);
    }
  }

  static void noteBook(BookDetails d, {String? authorName}) => note(d.id, d.title, authorId: d.authorId, authorName: authorName, categoryId: d.categoryId);

  /// Books from the server's shared list: [id, title, authorId, categoryId, authorName].
  static void noteRows(List<dynamic> rows) {
    for (final r in rows) {
      if (r is! List || r.length < 2) continue;
      note('${r[0]}', '${r[1]}', authorId: r.length > 2 ? '${r[2]}' : null, categoryId: r.length > 3 ? '${r[3]}' : null, authorName: r.length > 4 && r[4] != null ? '${r[4]}' : null);
    }
  }
}
