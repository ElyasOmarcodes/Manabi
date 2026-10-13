import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/pdf/range_file.dart';

/// A file server that answers byte ranges, and misbehaves on request.
class _Server {
  _Server(this.body);
  Uint8List body;
  String etag = '"v1"';
  final ranges = <String>[];

  /// Ranges answered with half the bytes and then silence.
  int stalls = 0;

  /// Requests answered with a 500.
  int errors = 0;
  late HttpServer _http;
  Uri get uri => Uri.parse('http://127.0.0.1:${_http.port}/book.pdf');

  Future<void> start() async {
    _http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _http.listen((req) async {
      final res = req.response;
      final range = req.headers.value('range')!;
      ranges.add(range);
      if (errors > 0) {
        errors--;
        res.statusCode = 500;
        await res.close();
        return;
      }
      if (req.headers.value('if-none-match') == etag) {
        res.statusCode = 304;
        await res.close();
        return;
      }
      final m = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
      final from = int.parse(m.group(1)!);
      final to = int.parse(m.group(2)!).clamp(0, body.length - 1);
      res.statusCode = 206;
      res.headers.set('content-range', 'bytes $from-$to/${body.length}');
      res.headers.set('etag', etag);
      res.contentLength = to - from + 1;
      if (stalls > 0) {
        stalls--;
        res.add(body.sublist(from, from + (to - from + 1) ~/ 2));
        await res.flush();
        return; // never finished
      }
      res.add(body.sublist(from, to + 1));
      await res.close();
    });
  }

  Future<void> stop() => _http.close(force: true);
}

Uint8List _bytes(int n, [int seed = 0]) => Uint8List.fromList(List.generate(n, (i) => (i * 7 + seed) & 0xff));

void main() {
  late Directory dir;
  late _Server server;
  const block = 1024;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('pdf-range');
    server = _Server(_bytes(10 * block + 300));
    await server.start();
  });
  tearDown(() async {
    await server.stop();
    await dir.delete(recursive: true);
  });

  Future<PdfRangeFile> open({Duration timeout = const Duration(seconds: 2), Uri? uri}) =>
      PdfRangeFile.open(uri ?? server.uri, dir: dir, blockSize: block, attemptTimeout: timeout);

  test('reads the asked bytes, fetching only the blocks around them', () async {
    final f = await open();
    expect(f.size, server.body.length);
    final buf = Uint8List(1500);
    expect(await f.read(buf, 5 * block + 100, 1500), 1500);
    expect(buf, server.body.sublist(5 * block + 100, 5 * block + 1600));
    // First block for the size, then blocks 5-6 in one request.
    expect(server.ranges, ['bytes=0-1023', 'bytes=5120-7167']);
    // Held blocks are not asked again; the short last block is read too.
    final tail = Uint8List(300);
    expect(await f.read(tail, 10 * block, 300), 300);
    expect(tail, server.body.sublist(10 * block));
    expect(await f.read(buf, 5 * block + 100, 1500), 1500);
    expect(server.ranges.length, 3);
    await f.release();
  });

  test('a stalled answer is given up and asked again, never waited on for ever', () async {
    final f = await open(timeout: const Duration(milliseconds: 400));
    server.stalls = 1;
    final buf = Uint8List(100);
    final t = Stopwatch()..start();
    expect(await f.read(buf, 3 * block, 100), 100);
    expect(buf, server.body.sublist(3 * block, 3 * block + 100));
    expect(t.elapsed, lessThan(const Duration(seconds: 3)));
    expect(f.failures.value, 0);
    await f.release();
  });

  test('when the network keeps failing, the read says 0 in bounded time', () async {
    final f = await open(timeout: const Duration(milliseconds: 300));
    server.stalls = 100;
    final buf = Uint8List(100);
    final t = Stopwatch()..start();
    expect(await f.read(buf, 4 * block, 100), 0);
    expect(t.elapsed, lessThan(f.maxReadTime));
    expect(f.failures.value, 1);
    // Nothing half-arrived was kept: once the network is back the block is read.
    server.stalls = 0;
    expect(await f.read(buf, 4 * block, 100), 100);
    expect(buf, server.body.sublist(4 * block, 4 * block + 100));
    await f.release();
  });

  test('server errors are retried', () async {
    final f = await open();
    server.errors = 2;
    final buf = Uint8List(10);
    expect(await f.read(buf, 2 * block, 10), 10);
    expect(buf, server.body.sublist(2 * block, 2 * block + 10));
    await f.release();
  });

  test('a viewer opened again shares the file, and kept blocks open offline', () async {
    final a = await open();
    final b = await open();
    expect(identical(a, b), isTrue);
    final buf = Uint8List(200);
    expect(await a.read(buf, 7 * block, 200), 200);
    await a.release();
    await b.release();

    // Next visit: the ETag still matches, so no block is fetched again.
    server.ranges.clear();
    final c = await open();
    expect(await c.read(buf, 7 * block, 200), 200);
    expect(buf, server.body.sublist(7 * block, 7 * block + 200));
    expect(server.ranges, ['bytes=0-1023']);
    await c.release();

    // Without the network what was kept still reads; the rest says 0.
    final uri = server.uri;
    await server.stop();
    final d = await open(timeout: const Duration(milliseconds: 300), uri: uri);
    expect(await d.read(buf, 7 * block, 200), 200);
    expect(buf, server.body.sublist(7 * block, 7 * block + 200));
    expect(await d.read(buf, 3 * block, 200), 0);
    await d.release();
    await server.start();
  });

  test('a new edition of the file drops the old blocks', () async {
    final a = await open();
    final buf = Uint8List(50);
    expect(await a.read(buf, 6 * block, 50), 50);
    await a.release();

    server.body = _bytes(10 * block + 300, 99);
    server.etag = '"v2"';
    final b = await open();
    expect(await b.read(buf, 6 * block, 50), 50);
    expect(buf, server.body.sublist(6 * block, 6 * block + 50));
    await b.release();
  });

  test('reads past the end, or of nothing, say 0', () async {
    final f = await open();
    final buf = Uint8List(10);
    expect(await f.read(buf, f.size - 5, 10), 0);
    expect(await f.read(buf, 0, 0), 0);
    await f.release();
  });
}
