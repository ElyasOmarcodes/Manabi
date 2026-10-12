import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backend/backend.dart';
import '../core/catalog/catalog_service.dart';
import 'discovered_books.dart';
import 'pdf_flags.dart';

/// One step of building the local library.
enum SyncStep { storage, catalog, extraBooks, pdfFlags }

enum SyncState { waiting, running, done, failed }

/// Builds the device's library database on first launch — the book list
/// with authors and categories, the books found on Turath beyond the
/// bundled list, and which books have a scanned PDF — and refreshes the
/// network parts in the background (daily, and every few hours while open).
class CatalogSync extends ChangeNotifier {
  CatalogSync(this._catalog, this._backend, {this.storagePath});

  final CatalogService _catalog;
  final ManabiBackend Function() _backend;

  /// Where the database lives on this device (null on the web).
  final String? storagePath;

  static const _key = 'librarySyncedAt';
  static const refreshEvery = Duration(hours: 24);

  final states = {for (final s in SyncStep.values) s: SyncState.waiting};
  final details = <SyncStep, String>{};
  bool running = false;
  Timer? _timer;

  static Future<bool> needsSetup() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key) == null;
  }

  double get progress => states.values.where((s) => s == SyncState.done || s == SyncState.failed).length / states.length;

  void _set(SyncStep s, SyncState state, [String? detail]) {
    states[s] = state;
    if (detail != null) details[s] = detail;
    notifyListeners();
  }

  /// Runs every step; the network ones may fail (offline) without stopping
  /// the rest — they are tried again on the next refresh.
  Future<void> run({bool firstRun = false}) async {
    if (running) return;
    running = true;
    for (final s in SyncStep.values) {
      states[s] = SyncState.waiting;
    }
    notifyListeners();
    _set(SyncStep.storage, SyncState.running);
    await Future<void>.delayed(Duration(milliseconds: firstRun ? 350 : 0));
    _set(SyncStep.storage, SyncState.done, storagePath ?? 'IndexedDB');

    _set(SyncStep.catalog, SyncState.running);
    await Future<void>.delayed(Duration(milliseconds: firstRun ? 350 : 0));
    _set(SyncStep.catalog, SyncState.done, '${_catalog.books.length} · ${_catalog.authors.length} · ${_catalog.categories.length}');

    var ok = true;
    _set(SyncStep.extraBooks, SyncState.running);
    try {
      final before = _catalog.books.length;
      DiscoveredBooks.noteRows(await _backend().discoveredBooks().timeout(const Duration(seconds: 25)));
      _set(SyncStep.extraBooks, SyncState.done, '+${_catalog.books.length - before}');
    } catch (e) {
      ok = false;
      _set(SyncStep.extraBooks, SyncState.failed);
    }

    _set(SyncStep.pdfFlags, SyncState.running);
    try {
      final flags = await _backend().pdfFlagsAll().timeout(const Duration(seconds: 25));
      await PdfFlags.noteMany(flags);
      _set(SyncStep.pdfFlags, SyncState.done, '${PdfFlags.knownCount}');
    } catch (e) {
      ok = false;
      _set(SyncStep.pdfFlags, SyncState.failed);
    }

    final prefs = await SharedPreferences.getInstance();
    // The first run counts as done even offline; a failed refresh is retried
    // sooner (on the next start).
    if (ok || prefs.getInt(_key) == null) await prefs.setInt(_key, ok ? DateTime.now().millisecondsSinceEpoch : 1);
    running = false;
    notifyListeners();
  }

  /// Refreshes when the last full sync is older than [refreshEvery], then
  /// keeps refreshing while the app stays open.
  Future<void> startBackground() async {
    final prefs = await SharedPreferences.getInstance();
    final last = DateTime.fromMillisecondsSinceEpoch(prefs.getInt(_key) ?? 0);
    if (DateTime.now().difference(last) > refreshEvery) unawaited(run());
    _timer ??= Timer.periodic(const Duration(hours: 6), (_) => unawaited(run()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
