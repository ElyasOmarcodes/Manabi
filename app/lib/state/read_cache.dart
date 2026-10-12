import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/models/library.dart';

/// Every page and book index read online is kept on the device (like
/// Turath), so it opens again without a connection. The oldest are dropped
/// past a limit; books saved for offline reading are kept separately.
class ReadCache {
  ReadCache._();

  static const maxPages = 5000;
  static const maxBooks = 300;
  static LazyBox<String>? _pages;
  static LazyBox<String>? _books;
  static Box<int>? _at; // key → when it was last read (ms)

  static Future<void> open() async {
    try {
      _pages = await Hive.openLazyBox<String>('read_pages');
      _books = await Hive.openLazyBox<String>('read_books');
      _at = await Hive.openBox<int>('read_at');
    } catch (e) {
      debugPrint('read cache: $e');
    }
  }

  static int get pageCount => _pages?.length ?? 0;

  static String _pageKey(String bookId, int page) => '$bookId:$page';

  static Future<void> putPage(PagePassage p) async {
    final box = _pages;
    if (box == null || p.text.isEmpty || p.internalPage == null) return;
    final key = _pageKey(p.bookId, p.internalPage!);
    try {
      await box.put(key, jsonEncode(p.toJson()));
      await _at?.put('p:$key', DateTime.now().millisecondsSinceEpoch);
      if (box.length > maxPages + 200) await _trim(box, 'p:', maxPages);
    } catch (_) {}
  }

  static Future<PagePassage?> page(String bookId, int page) async {
    try {
      final raw = await _pages?.get(_pageKey(bookId, page));
      return raw == null ? null : PagePassage.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  static Future<void> putBook(BookDetails b) async {
    final box = _books;
    if (box == null) return;
    try {
      await box.put(b.id, jsonEncode(b.toJson()));
      await _at?.put('b:${b.id}', DateTime.now().millisecondsSinceEpoch);
      if (box.length > maxBooks + 20) await _trim(box, 'b:', maxBooks);
    } catch (_) {}
  }

  static Future<BookDetails?> book(String id) async {
    try {
      final raw = await _books?.get(id);
      return raw == null ? null : BookDetails.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  /// Keeps the [keep] most recently read entries of [box].
  static Future<void> _trim(LazyBox<String> box, String prefix, int keep) async {
    final at = _at;
    if (at == null) return;
    final keys = box.keys.map((k) => '$k').toList()..sort((a, b) => (at.get('$prefix$b') ?? 0).compareTo(at.get('$prefix$a') ?? 0));
    final drop = keys.skip(keep).toList();
    await box.deleteAll(drop);
    await at.deleteAll([for (final k in drop) '$prefix$k']);
  }

  static Future<void> clear() async {
    await _pages?.clear();
    await _books?.clear();
    await _at?.clear();
  }
}
