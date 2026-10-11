import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/library.dart';

/// Offline Turath catalog (books, authors, categories) exported from the
/// Nusus SDK snapshot by `server/scripts/export-catalog.mjs`.
class CatalogService {
  CatalogService._(this.scannedAt, this.categories, this.authors, this.books)
      : _authorById = {for (final a in authors) a.id: a},
        _bookById = {for (final b in books) b.id: b},
        _categoryById = {for (final c in categories) c.id: c},
        _bookKeys = [for (final b in books) normalizeForSearch(b.title)],
        _authorKeys = [for (final a in authors) normalizeForSearch(a.name)];

  final String scannedAt;
  final List<CatalogCategory> categories;
  final List<CatalogAuthor> authors;
  final List<CatalogBook> books;
  final Map<String, CatalogAuthor> _authorById;
  final Map<String, CatalogBook> _bookById;
  final Map<String, CatalogCategory> _categoryById;
  final List<String> _bookKeys;
  final List<String> _authorKeys;

  static Future<CatalogService> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/catalog/catalog.json');
    return compute(parse, raw);
  }

  @visibleForTesting
  static CatalogService parse(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final books = [
      for (final b in j['books'] as List) CatalogBook('${b[0]}', b[1] as String, '${b[2]}', '${b[3]}'),
    ];
    final authorCounts = <String, int>{};
    final categoryCounts = <String, int>{};
    for (final b in books) {
      authorCounts[b.authorId] = (authorCounts[b.authorId] ?? 0) + 1;
      categoryCounts[b.categoryId] = (categoryCounts[b.categoryId] ?? 0) + 1;
    }
    return CatalogService._(
      j['scannedAt'] as String? ?? '',
      [for (final c in j['categories'] as List) CatalogCategory('${c[0]}', c[1] as String, categoryCounts['${c[0]}'] ?? 0)],
      [for (final a in j['authors'] as List) CatalogAuthor('${a[0]}', a[1] as String, authorCounts['${a[0]}'] ?? 0)],
      books,
    );
  }

  /// Books added after the snapshot (found on Turath while using the app).
  int discovered = 0;

  /// Adds books the snapshot lacks (with their authors when named). Returns
  /// how many were new.
  int addBooks(Iterable<({CatalogBook book, String? authorName})> found) {
    var added = 0;
    for (final (:book, :authorName) in found) {
      if (book.id.isEmpty || book.title.trim().isEmpty || _bookById.containsKey(book.id)) continue;
      books.add(book);
      _bookById[book.id] = book;
      _bookKeys.add(normalizeForSearch(book.title));
      final name = authorName?.trim() ?? '';
      if (book.authorId.isNotEmpty && name.isNotEmpty && !_authorById.containsKey(book.authorId)) {
        final a = CatalogAuthor(book.authorId, name, 1);
        authors.add(a);
        _authorById[a.id] = a;
        _authorKeys.add(normalizeForSearch(name));
      }
      added++;
    }
    discovered += added;
    return added;
  }

  CatalogAuthor? author(String? id) => id == null ? null : _authorById[id];
  CatalogBook? book(String? id) => id == null ? null : _bookById[id];
  CatalogCategory? category(String? id) => id == null ? null : _categoryById[id];

  List<CatalogBook> booksByAuthor(String authorId) => books.where((b) => b.authorId == authorId).toList()
    ..sort((a, b) => a.title.compareTo(b.title));

  /// Title search with the same ranking as Nusus: exact, prefix, contains, all words.
  List<CatalogBook> findBooks(String query, {String? authorId, String? categoryId, int limit = 60}) {
    final needle = normalizeForSearch(query);
    final words = needle.isEmpty ? const <String>[] : needle.split(' ');
    final scored = <(int, CatalogBook)>[];
    for (var i = 0; i < books.length; i++) {
      final b = books[i];
      if (authorId != null && b.authorId != authorId) continue;
      if (categoryId != null && b.categoryId != categoryId) continue;
      final score = needle.isEmpty ? 0 : _score(_bookKeys[i], needle, words);
      if (score >= 0) scored.add((score, b));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.title.compareTo(b.$2.title));
    return scored.take(limit).map((e) => e.$2).toList();
  }

  List<CatalogAuthor> findAuthors(String query, {int limit = 60}) {
    final needle = normalizeForSearch(query);
    if (needle.isEmpty) {
      final sorted = [...authors]..sort((a, b) => b.bookCount.compareTo(a.bookCount));
      return sorted.take(limit).toList();
    }
    final words = needle.split(' ');
    final scored = <(int, CatalogAuthor)>[];
    for (var i = 0; i < authors.length; i++) {
      final score = _score(_authorKeys[i], needle, words);
      if (score >= 0) scored.add((score, authors[i]));
    }
    scored.sort((a, b) => a.$1 != b.$1 ? a.$1.compareTo(b.$1) : b.$2.bookCount.compareTo(a.$2.bookCount));
    return scored.take(limit).map((e) => e.$2).toList();
  }

  static int _score(String candidate, String needle, List<String> words) {
    if (candidate == needle) return 0;
    if (candidate.startsWith(needle)) return 1;
    if (candidate.contains(needle)) return 2;
    if (words.every(candidate.contains)) return 3;
    return -1;
  }
}

final _searchDiacritics = RegExp('[ً-ٰٟـ]');

/// Lenient normalization for catalog lookups (also maps Persian/Pashto
/// letter forms so users can type with their own keyboard).
String normalizeForSearch(String value) => value
    .replaceAll(_searchDiacritics, '')
    .replaceAll(RegExp('[أإآٱ]'), 'ا')
    .replaceAll(RegExp('[ىیۍې]'), 'ي')
    .replaceAll('ک', 'ك')
    .replaceAll('ة', 'ه')
    // Punctuation and brackets («» ( ) … - ،) do not matter for titles.
    .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();
