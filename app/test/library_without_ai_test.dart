import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manabi/core/backend/backend.dart';
import 'package:manabi/core/catalog/catalog_service.dart';
import 'package:manabi/core/models/library.dart';

class _Down implements ManabiBackend {
  @override
  Future<PagePassage> page(String bookId, int page) async => throw const BackendException('NETWORK', 'down');
  @override
  Future<String> check() async => throw const BackendException('GEMINI_AUTH');
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Library implements ManabiBackend {
  int reads = 0;
  @override
  Future<PagePassage> page(String bookId, int page) async {
    reads++;
    throw const BackendException('NOT_FOUND', 'from the library');
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  final catalog = CatalogService.parse(File('assets/catalog/catalog.json').readAsStringSync());

  test('without a key the library reads Turath, and only the AI asks to be set up', () async {
    final asked = <Uri>[];
    final b = DirectBackend(
      apiKey: '',
      catalog: catalog,
      turathBaseUrl: 'https://manabi.example/turath/',
      noAiCode: 'SERVER_NOT_CONFIGURED',
      client: MockClient((req) async {
        asked.add(req.url);
        return http.Response('{}', 404);
      }),
    );
    await expectLater(b.page('22835', 3), throwsA(isA<BackendException>().having((e) => e.code, 'code', isNot('SERVER_NOT_CONFIGURED'))));
    expect(asked.single.host, 'manabi.example');
    expect(asked.single.path, '/turath/page');
    await expectLater(b.check(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'SERVER_NOT_CONFIGURED')));
    expect(asked.length, 1, reason: 'the AI parts never reach the network without a key');
  });

  test('when the server is down, books come from the library; AI errors stay the server\'s', () async {
    final library = _Library();
    final b = LibraryFallbackBackend(_Down(), library);
    await expectLater(b.page('1', 1), throwsA(isA<BackendException>().having((e) => e.message, 'message', 'from the library')));
    expect(library.reads, 1);
    await expectLater(b.check(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'GEMINI_AUTH')));
  });
}
