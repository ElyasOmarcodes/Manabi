import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/backend/backend.dart';
import '../core/models/answer.dart';
import '../core/models/library.dart';
import '../core/models/scope.dart';
import '../core/pipeline/answer_pipeline.dart' show AskRequest;
import 'discovered_books.dart';

/// A book kept on the device for offline reading.
class SavedBook {
  const SavedBook({required this.bookId, required this.title, this.authorId, this.categoryId, required this.pages, required this.total, required this.bytes, required this.savedAt});
  final String bookId;
  final String title;
  final String? authorId;
  final String? categoryId;

  /// Pages stored so far, out of [total].
  final int pages;
  final int total;
  final int bytes;
  final DateTime savedAt;

  bool get complete => total > 0 && pages >= total;

  Map<String, dynamic> toJson() => {
        'id': bookId,
        'title': title,
        'authorId': ?authorId,
        'categoryId': ?categoryId,
        'pages': pages,
        'total': total,
        'bytes': bytes,
        'savedAt': savedAt.toIso8601String(),
      };

  factory SavedBook.fromJson(Map<String, dynamic> j) => SavedBook(
        bookId: '${j['id']}',
        title: j['title'] as String? ?? '',
        authorId: j['authorId'] as String?,
        categoryId: j['categoryId'] as String?,
        pages: (j['pages'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
        bytes: (j['bytes'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Saves whole books page by page (five at a time, a few requests in
/// parallel) into a local Hive box per book. Interrupted downloads resume
/// from the pages already stored.
class DownloadController extends ChangeNotifier {
  DownloadController._();

  /// Without a store (tests, or when it cannot be opened): nothing is saved.
  factory DownloadController.empty() => DownloadController._();

  /// Set once the store is open (in the app); null in tests.
  static DownloadController? instance;

  static Future<DownloadController> open() async {
    final c = DownloadController._();
    try {
      c._meta = await Hive.openBox<String>('downloads');
      for (final raw in c._meta!.values) {
        try {
          final b = SavedBook.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
          c._books[b.bookId] = b;
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('downloads: $e');
    }
    return instance = c;
  }

  Box<String>? _meta;
  final Map<String, SavedBook> _books = {};
  final Map<String, LazyBox<String>> _boxes = {};
  final Map<String, double> _progress = {};
  final Set<String> _cancelled = {};

  /// Largest book that can be saved (pages).
  static const maxPages = 12000;

  List<SavedBook> get books => _books.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));
  int get totalBytes => _books.values.fold(0, (sum, b) => sum + b.bytes);

  SavedBook? saved(String bookId) => _books[bookId];
  bool isSaved(String bookId) => _books[bookId]?.complete ?? false;

  /// 0…1 while downloading, null otherwise.
  double? progressOf(String bookId) => _progress[bookId];

  Future<LazyBox<String>> _box(String bookId) async => _boxes[bookId] ??= await Hive.openLazyBox<String>('book_$bookId');

  Future<void> _store(SavedBook b) async {
    _books[b.bookId] = b;
    await _meta?.put(b.bookId, jsonEncode(b.toJson()));
  }

  /// Downloads (or resumes) a book. Throws [BackendException] on failure.
  Future<void> download(ManabiBackend backend, String bookId, String title) async {
    if (_progress.containsKey(bookId) || _meta == null) return;
    _cancelled.remove(bookId);
    _progress[bookId] = 0;
    notifyListeners();
    try {
      final details = await backend.book(bookId);
      final total = details.pageCount;
      if (total == null || total < 1) throw const BackendException('NOT_FOUND', 'The book has no page index');
      if (total > maxPages) throw const BackendException('INVALID_ARGUMENT', 'The book is too large to save');
      final box = await _box(bookId);
      await box.put('details', jsonEncode(details.toJson()));
      final have = {for (final k in box.keys) if (k is String && k != 'details') int.tryParse(k)}..remove(null);
      var bytes = _books[bookId]?.bytes ?? 0;
      var stored = have.length;
      final chunks = <(int, int)>[
        for (var from = 1; from <= total; from += 5)
          if (List.generate((from + 4 > total ? total : from + 4) - from + 1, (i) => from + i).any((p) => !have.contains(p))) (from, from + 4 > total ? total : from + 4),
      ];
      var next = 0;
      var lastNote = DateTime.now();
      Future<void> worker() async {
        while (next < chunks.length && !_cancelled.contains(bookId)) {
          final (from, to) = chunks[next++];
          List<PagePassage> pages = const [];
          for (var attempt = 0; attempt < 3; attempt++) {
            try {
              pages = await backend.pages(bookId, from, to);
              break;
            } catch (e) {
              if (attempt == 2) rethrow;
              await Future<void>.delayed(Duration(milliseconds: 800 * (attempt + 1)));
            }
          }
          for (final p in pages) {
            final n = p.internalPage;
            if (n == null) continue;
            final raw = jsonEncode(p.toJson());
            await box.put('$n', raw);
            bytes += raw.length * 2;
            stored++;
          }
          _progress[bookId] = (stored / total).clamp(0, 1);
          if (DateTime.now().difference(lastNote) > const Duration(milliseconds: 250)) {
            lastNote = DateTime.now();
            notifyListeners();
          }
        }
      }

      await Future.wait(List.generate(3, (_) => worker()));
      // Pages Turath does not have count as done, so the book can complete.
      final complete = !_cancelled.contains(bookId);
      await _store(SavedBook(
        bookId: bookId,
        title: details.title.isEmpty ? title : details.title,
        authorId: details.authorId,
        categoryId: details.categoryId,
        pages: complete ? total : stored,
        total: total,
        bytes: bytes,
        savedAt: DateTime.now(),
      ));
    } catch (e) {
      throw mapError(e);
    } finally {
      _progress.remove(bookId);
      notifyListeners();
    }
  }

  void cancel(String bookId) {
    _cancelled.add(bookId);
    notifyListeners();
  }

  Future<void> remove(String bookId) async {
    cancel(bookId);
    _books.remove(bookId);
    await _meta?.delete(bookId);
    final box = _boxes.remove(bookId) ?? (Hive.isBoxOpen('book_$bookId') ? Hive.lazyBox<String>('book_$bookId') : null);
    try {
      if (box != null) {
        await box.deleteFromDisk();
      } else {
        await Hive.deleteBoxFromDisk('book_$bookId');
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> removeAll() async {
    for (final id in [..._books.keys]) {
      await remove(id);
    }
  }

  Future<PagePassage?> page(String bookId, int page) async {
    if (!_books.containsKey(bookId)) return null;
    final raw = await (await _box(bookId)).get('$page');
    return raw == null ? null : PagePassage.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
  }

  Future<BookDetails?> details(String bookId) async {
    if (!_books.containsKey(bookId)) return null;
    final raw = await (await _box(bookId)).get('details');
    return raw == null ? null : BookDetails.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
  }
}

/// Reads saved books from the device first, so they open offline; everything
/// else goes to [inner].
class OfflineFirstBackend implements ManabiBackend {
  OfflineFirstBackend(this.inner);
  final ManabiBackend inner;
  DownloadController? get _d => DownloadController.instance;

  @override
  Future<PagePassage> page(String bookId, int page) async {
    try {
      final kept = await _d?.page(bookId, page);
      if (kept != null) return kept;
    } catch (_) {}
    final p = await inner.page(bookId, page);
    DiscoveredBooks.notePassages([p]);
    return p;
  }

  @override
  Future<BookDetails> book(String id) async {
    try {
      final d = await inner.book(id);
      DiscoveredBooks.noteBook(d);
      return d;
    } catch (e) {
      // Offline: the saved copy of the book's index.
      final kept = await _d?.details(id).catchError((Object _) => null);
      if (kept != null) return kept;
      rethrow;
    }
  }

  // Books seen in results join the library (see DiscoveredBooks).
  @override
  Stream<AskEvent> ask(AskRequest request) => inner.ask(request).map((e) {
        if (e is AskResultEvent) DiscoveredBooks.noteSources(e.result.sources);
        return e;
      });
  @override
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all}) async {
    final r = await inner.search(query, page: page, scope: scope);
    DiscoveredBooks.notePassages(r.items);
    return r;
  }
  @override
  Future<AuthorDetails> author(String id) => inner.author(id);
  @override
  Future<String> check() => inner.check();
  @override
  Future<LayersGuess> detectLayers(String title, List<String> pages) => inner.detectLayers(title, pages);
  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) => inner.pages(bookId, from, to);
  @override
  Future<NarratorPage> narrators(String query, {int page = 1}) => inner.narrators(query, page: page);
  @override
  Future<Narrator> narrator(String id) => inner.narrator(id);
  @override
  Future<List<dynamic>> discoveredBooks() => inner.discoveredBooks();
}
