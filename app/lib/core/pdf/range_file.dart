import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// A PDF on the network read in byte ranges, the ranges kept in a sparse file
/// on disk so a page seen once opens again without the network.
///
/// Made for pdfium's file access, which blocks its one worker thread on every
/// read: [read] never throws, gives up within [maxReadTime], and reports
/// failure as 0 (pdfium takes any other number as data, and would draw the
/// page from a block of zeroes).
class PdfRangeFile {
  PdfRangeFile._(this.uri, this.headers, this._data, this._metaFile, this._client, this.blockSize, this.attemptTimeout, this.attempts);

  final Uri uri;
  final Map<String, String>? headers;
  final int blockSize;
  final Duration attemptTimeout;
  final int attempts;
  final File _metaFile;
  final http.Client Function() _client;
  final RandomAccessFile _data;
  http.Client? _http;

  /// -1 until the network or an earlier visit told it.
  int size = -1;
  String? _etag;
  Uint8List _have = Uint8List(0);
  int _users = 0;

  /// Reads that could not be served; the viewer offers to load again.
  final failures = ValueNotifier(0);

  /// Bytes on disk and the file's size, for the loading banner.
  void Function(int have, int size)? onProgress;

  Duration get maxReadTime => (attemptTimeout + const Duration(seconds: 2)) * attempts;

  static final _open = <String, Future<PdfRangeFile>>{};

  /// The shared file of [uri]: one per URL, so a viewer opened again while the
  /// last one is still closing reads the same blocks, never a second copy.
  static Future<PdfRangeFile> open(
    Uri uri, {
    required Directory dir,
    Map<String, String>? headers,
    int blockSize = 128 * 1024,
    Duration attemptTimeout = const Duration(seconds: 20),
    int attempts = 3,
    http.Client Function()? client,
  }) async {
    final key = uri.toString();
    final pending = _open[key] ??= _create(uri, dir, headers, blockSize, attemptTimeout, attempts, client ?? http.Client.new);
    try {
      final file = await pending;
      file._users++;
      return file;
    } catch (_) {
      if (identical(_open[key], pending)) _open.remove(key);
      rethrow;
    }
  }

  static Future<PdfRangeFile> _create(
    Uri uri,
    Directory dir,
    Map<String, String>? headers,
    int blockSize,
    Duration attemptTimeout,
    int attempts,
    http.Client Function() client,
  ) async {
    await dir.create(recursive: true);
    final name = sha1.convert(utf8.encode(uri.toString())).toString();
    final data = await File('${dir.path}/$name.pdf').open(mode: FileMode.append);
    final file = PdfRangeFile._(uri, headers, data, File('${dir.path}/$name.json'), client, blockSize, attemptTimeout, attempts);
    try {
      await file._start();
    } catch (_) {
      await data.close();
      rethrow;
    }
    return file;
  }

  /// Gives the file back; the last user closes it.
  Future<void> release() async {
    if (--_users > 0) return;
    _open.remove(uri.toString());
    await _locked(() async {
      _http?.close();
      _http = null;
      await _data.close();
    });
  }

  int get _blocks => (size + blockSize - 1) ~/ blockSize;
  bool _isHeld(int b) => b < _blocks && _have[b >> 3] & (1 << (b & 7)) != 0;
  void _hold(int b) => _have[b >> 3] |= 1 << (b & 7);

  int get bytesHeld {
    var n = 0;
    for (var b = 0; b < _blocks; b++) {
      if (_isHeld(b)) n += min(blockSize, size - b * blockSize);
    }
    return n;
  }

  // What an earlier visit kept, then the first block from the network: it
  // tells the size, and a new edition of the file (another ETag) drops the
  // old blocks. Without the network the kept blocks are read as they are.
  Future<void> _start() async {
    try {
      final meta = jsonDecode(await _metaFile.readAsString()) as Map<String, dynamic>;
      if (meta['blockSize'] == blockSize && meta['size'] is int) {
        size = meta['size'] as int;
        _etag = meta['etag'] as String?;
        _have = Uint8List((_blocks + 7) >> 3);
        final kept = base64Decode(meta['have'] as String? ?? '');
        _have.setRange(0, min(kept.length, _have.length), kept);
      }
    } catch (_) {}
    try {
      await _fetch(0, 1, start: true);
    } catch (_) {
      if (!_isHeld(0)) rethrow;
    }
  }

  Future<void> _save() => _metaFile.writeAsString(jsonEncode({'size': size, 'etag': _etag, 'blockSize': blockSize, 'have': base64Encode(_have)}));

  // Reads, fetches and closing one at a time (a RandomAccessFile takes one
  // operation at a time, and two readers never fetch the same block twice).
  Future<void> _tail = Future.value();
  Future<T> _locked<T>(Future<T> Function() f) {
    final r = _tail.then((_) => f());
    _tail = r.then((_) {}, onError: (_) {});
    return r;
  }

  /// Copies [length] bytes at [position] into [buffer]; returns [length], or 0
  /// when they could not be had.
  Future<int> read(Uint8List buffer, int position, int length) => _locked(() async {
    try {
      if (length <= 0 || position < 0 || position + length > size) return 0;
      final last = (position + length - 1) ~/ blockSize;
      for (var b = position ~/ blockSize; b <= last; b++) {
        if (_isHeld(b)) continue;
        // A run of missing blocks in one request. No reading ahead: pdfium
        // asks for a page's whole image at once, and most of its other reads
        // are small and far apart.
        var n = 1;
        while (b + n <= last && !_isHeld(b + n)) {
          n++;
        }
        await _fetch(b, n);
        b += n - 1;
      }
      for (var b = position ~/ blockSize; b <= last; b++) {
        if (!_isHeld(b)) throw StateError('block $b missing');
      }
      await _data.setPosition(position);
      if (await _data.readInto(buffer, 0, length) != length) throw StateError('short read');
      return length;
    } catch (_) {
      failures.value++;
      return 0;
    }
  });

  // Blocks [block, block + count) from the network, tried [attempts] times,
  // each try (the answer and every byte of it) within [attemptTimeout].
  Future<void> _fetch(int block, int count, {bool start = false}) async {
    Object? error;
    for (var i = 0; i < attempts; i++) {
      if (i > 0) await Future<void>.delayed(Duration(milliseconds: 700 * i));
      try {
        await _fetchOnce(block, count, start: start).timeout(attemptTimeout);
        return;
      } catch (e) {
        error = e;
        // A stalled answer keeps its connection; drop it with the client.
        _http?.close();
        _http = null;
        if (e is _Refused) break;
      }
    }
    throw error!;
  }

  Future<void> _fetchOnce(int block, int count, {required bool start}) async {
    final from = block * blockSize;
    final to = start ? blockSize : min((block + count) * blockSize, size);
    final req = http.Request('GET', uri)
      ..headers.addAll({'range': 'bytes=$from-${to - 1}', if (start && _etag != null && _isHeld(0)) 'if-none-match': _etag!, ...?headers});
    final res = await (_http ??= _client()).send(req);
    if (res.statusCode == 304) {
      await res.stream.drain<void>();
      return;
    }
    if (res.statusCode != 206 && res.statusCode != 200) {
      await res.stream.drain<void>();
      throw res.statusCode >= 400 && res.statusCode < 500 && res.statusCode != 408 && res.statusCode != 429
          ? _Refused(res.statusCode)
          : HttpException('PDF ${res.statusCode}');
    }
    final bytes = await res.stream.toBytes();
    var at = 0;
    var total = bytes.length;
    if (res.statusCode == 206) {
      final m = RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(res.headers['content-range'] ?? '');
      if (m == null) throw const HttpException('PDF range without content-range');
      at = int.parse(m.group(1)!);
      total = int.parse(m.group(3)!);
      if (at != from || int.parse(m.group(2)!) - at + 1 != bytes.length) throw const HttpException('PDF range cut short');
    }
    final etag = res.headers['etag'];
    if (start) {
      if (total != size || (etag != null && _etag != null && etag != _etag)) {
        size = total;
        _have = Uint8List((_blocks + 7) >> 3);
        await _data.truncate(0);
      }
      _etag = etag ?? _etag;
    } else if (total != size) {
      throw const HttpException('PDF changed while reading');
    }
    await _data.setPosition(at);
    await _data.writeFrom(bytes);
    // Only whole blocks that arrived (or the file's short last block) count.
    final end = at + bytes.length;
    for (var b = at ~/ blockSize; b < _blocks && min((b + 1) * blockSize, size) <= end; b++) {
      _hold(b);
    }
    await _save();
    onProgress?.call(bytesHeld, size);
  }
}

class _Refused implements Exception {
  const _Refused(this.status);
  final int status;
  @override
  String toString() => 'PDF $status';
}
