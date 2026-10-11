import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/backend/backend.dart';

/// The AI's marking of the matn on single pages, for books read in the
/// precise mode. Each page is asked once and kept on the device; requests
/// run one at a time.
class PageMatnAi {
  PageMatnAi._();

  static Box<String>? _box;
  static final _memory = <String, List<(String, String)>>{};
  static final _pending = <String, Future<List<(String, String)>?>>{};
  static Future<void> _queue = Future.value();

  static Future<void> open() async {
    try {
      _box = await Hive.openBox<String>('layer_ai');
    } catch (e) {
      debugPrint('layer_ai: $e');
    }
  }

  static String _key(String bookId, int page) => '$bookId:$page';

  /// The stretches already known for a page, if any.
  static List<(String, String)>? cached(String bookId, int page) {
    final key = _key(bookId, page);
    final hit = _memory[key];
    if (hit != null) return hit;
    final raw = _box?.get(key);
    if (raw == null) return null;
    try {
      final list = [for (final e in jsonDecode(raw) as List) ('${e[0]}', '${e[1]}')];
      return _memory[key] = list;
    } catch (_) {
      return null;
    }
  }

  /// Asks the AI for a page's matn stretches (once per page).
  static Future<List<(String, String)>?> fetch(ManabiBackend backend, String bookId, int page, String title, String text) {
    final known = cached(bookId, page);
    if (known != null) return SynchronousFuture(known);
    final key = _key(bookId, page);
    return _pending.putIfAbsent(key, () {
      final done = Completer<List<(String, String)>?>();
      _queue = _queue.then((_) async {
        try {
          final guess = await backend.detectLayers(title, [text]);
          final spans = guess.pages.isEmpty ? const <(String, String)>[] : guess.pages.first;
          _memory[key] = spans;
          await _box?.put(key, jsonEncode([for (final (a, b) in spans) [a, b]]));
          done.complete(spans);
        } catch (e) {
          done.complete(null);
        } finally {
          _pending.remove(key);
        }
      });
      return done.future;
    });
  }

  static Future<void> clearBook(String bookId) async {
    _memory.removeWhere((k, _) => k.startsWith('$bookId:'));
    final keys = _box?.keys.where((k) => '$k'.startsWith('$bookId:')).toList() ?? const [];
    await _box?.deleteAll(keys);
  }
}
