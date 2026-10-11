import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../core/backend/backend.dart';

/// Which books have Turath's scanned PDF, for the red badge in book lists.
/// Rows ask for their book as they appear; the questions are sent together
/// (a few dozen at a time) and every answer is kept on the device.
class PdfFlags {
  PdfFlags._();

  static Box<bool>? _box;
  static final _known = <String, bool>{};
  static final _waiting = <String>{};
  static Timer? _timer;
  static ManabiBackend Function()? _backend;

  /// Bumped when answers arrive (rows listen to it).
  static final changes = ValueNotifier<int>(0);

  static Future<void> open(ManabiBackend Function() backend) async {
    _backend = backend;
    try {
      _box = await Hive.openBox<bool>('pdf_flags');
      for (final k in _box!.keys) {
        final v = _box!.get(k);
        if (v != null) _known['$k'] = v;
      }
    } catch (e) {
      debugPrint('pdf_flags: $e');
    }
  }

  /// true / false when known; null while being asked.
  static bool? of(String bookId) {
    final v = _known[bookId];
    if (v == null && _backend != null && _waiting.add(bookId)) {
      _timer ??= Timer(const Duration(milliseconds: 350), _send);
    }
    return v;
  }

  /// A book whose details were loaded anyway (reader, book page).
  static void note(String bookId, bool hasPdf) {
    if (_known[bookId] == hasPdf) return;
    _known[bookId] = hasPdf;
    _box?.put(bookId, hasPdf).catchError((Object _) {});
    changes.value++;
  }

  static Future<void> _send() async {
    _timer = null;
    final ids = _waiting.take(40).toList();
    if (ids.isEmpty) return;
    try {
      final found = await _backend!().pdfFlags(ids);
      for (final e in found.entries) {
        _known[e.key] = e.value;
        _box?.put(e.key, e.value).catchError((Object _) {});
      }
      if (found.isNotEmpty) changes.value++;
    } catch (_) {
      // Offline or not configured: try these again later.
    } finally {
      _waiting.removeAll(ids);
      if (_waiting.isNotEmpty) _timer ??= Timer(const Duration(milliseconds: 350), _send);
    }
  }
}
