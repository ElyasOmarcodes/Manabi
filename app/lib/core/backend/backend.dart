import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../catalog/catalog_service.dart';
import '../gemini/gemini_client.dart';
import '../models/answer.dart';
import '../models/library.dart';
import '../models/scope.dart';
import '../pipeline/answer_pipeline.dart';
import '../pipeline/prompt_texts.dart' show layersSystem;
import '../pipeline/prompts.dart' show layersPrompt, layersSchema;
import '../turath/turath_client.dart';

/// Error codes the UI knows how to explain.
class BackendException implements Exception {
  const BackendException(this.code, [this.message = '']);

  /// NETWORK, SERVER_NOT_CONFIGURED, NO_API_KEY, GEMINI_AUTH, GEMINI_QUOTA,
  /// GEMINI_UNAVAILABLE, TURATH_UNAVAILABLE, TURATH_RATE_LIMITED, RATE_LIMITED,
  /// NOT_FOUND, INVALID_ARGUMENT, UNAUTHORIZED, INTERNAL
  final String code;
  final String message;
  @override
  String toString() => 'BackendException($code): $message';
}

BackendException mapError(Object e) {
  if (e is BackendException) return e;
  if (e is PipelineException) return BackendException(e.code, e.message);
  if (e is TurathException) {
    return BackendException(switch (e.code) {
      'NOT_FOUND' => 'NOT_FOUND',
      'RATE_LIMITED' => 'TURATH_RATE_LIMITED',
      'INVALID_ARGUMENT' => 'INVALID_ARGUMENT',
      _ => 'TURATH_UNAVAILABLE',
    }, e.message);
  }
  if (e is GeminiException) {
    return BackendException(switch (e.code) {
      'AUTH' => 'GEMINI_AUTH',
      'QUOTA' => 'GEMINI_QUOTA',
      'NETWORK' => 'NETWORK',
      _ => 'GEMINI_UNAVAILABLE',
    }, '${e.code}: ${e.message}');
  }
  if (e is TimeoutException || e is http.ClientException) return BackendException('NETWORK', '$e');
  return BackendException('INTERNAL', '$e');
}

/// Everything the UI needs from a data source. Two implementations:
/// [ServerBackend] (Manabi server, key stays on the server) and
/// [DirectBackend] (native only, user's own Gemini key).
abstract class ManabiBackend {
  Stream<AskEvent> ask(AskRequest request);
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all, TextSearchOptions options = TextSearchOptions.standard});
  Future<BookDetails> book(String id);
  Future<AuthorDetails> author(String id);
  Future<PagePassage> page(String bookId, int page);

  /// Returns the Gemini model in use, or throws a [BackendException].
  Future<String> check();

  /// Asks the model which delimiters hold the matn and the verses of a book.
  Future<LayersGuess> detectLayers(String title, List<String> pages);

  /// A short run of pages (at most five), for saving a book offline.
  Future<List<PagePassage>> pages(String bookId, int from, int to);

  Future<NarratorPage> narrators(String query, {int page = 1});
  Future<Narrator> narrator(String id);

  /// Books outside the bundled catalog that the server has met on Turath,
  /// as rows [id, title, authorId, categoryId, authorName].
  Future<List<dynamic>> discoveredBooks();

  /// Which of these books have a scanned PDF (for the badge in lists).
  Future<Map<String, bool>> pdfFlags(List<String> ids);

  /// The text models the key can call, and the one chosen automatically.
  Future<({List<ModelInfo> models, String? auto})> models();

  /// Every PDF answer the server has gathered (empty without a server).
  Future<Map<String, bool>> pdfFlagsAll();
}

/// Several searches' pages taken in turn, without repeats; totals add up.
SearchResultPage mergeSearchPages(List<SearchResultPage> pages, int page) {
  final seen = <String>{};
  final items = <PagePassage>[];
  final longest = pages.fold(0, (m, r) => r.items.length > m ? r.items.length : m);
  for (var i = 0; i < longest; i++) {
    for (final r in pages) {
      if (i < r.items.length && seen.add('${r.items[i].bookId}:${r.items[i].internalPage}')) items.add(r.items[i]);
    }
  }
  return SearchResultPage(items: items, totalMatches: pages.fold(0, (n, r) => n + r.totalMatches), page: page);
}

List<String> _layerSamples(List<String> pages) => [for (final p in pages.where((p) => p.trim().isNotEmpty).take(4)) p.length > 5000 ? p.substring(0, 5000) : p];

class ServerBackend implements ManabiBackend {
  ServerBackend(String baseUrl, {this.accessToken, http.Client? client}) : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''), _http = client ?? http.Client();

  final String baseUrl;
  final String? accessToken;
  final http.Client _http;

  Map<String, String> get _headers => {
    'accept': 'application/json',
    if (accessToken != null && accessToken!.isNotEmpty) 'authorization': 'Bearer $accessToken',
  };

  Future<Map<String, dynamic>> _get(String path, [Map<String, String>? query]) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    http.Response res;
    try {
      res = await _http.get(uri, headers: _headers).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw BackendException('NETWORK', '$e');
    }
    return _decode(res.statusCode, utf8.decode(res.bodyBytes));
  }

  static Map<String, dynamic> _decode(int status, String body) {
    Object? json;
    try {
      json = jsonDecode(body);
    } catch (_) {
      throw BackendException(status >= 500 ? 'INTERNAL' : 'NETWORK', 'Unexpected response ($status)');
    }
    if (status >= 200 && status < 300) {
      if (json is Map) return json.cast<String, dynamic>();
      if (json is List) return {'items': json};
    }
    final error = json is Map ? json['error'] : null;
    if (error is Map) throw BackendException('${error['code'] ?? 'INTERNAL'}', '${error['message'] ?? ''}');
    throw BackendException('INTERNAL', 'HTTP $status');
  }

  @override
  Stream<AskEvent> ask(AskRequest request) async* {
    final req = http.Request('POST', Uri.parse('$baseUrl/api/ask'))
      ..headers.addAll({..._headers, 'accept': 'text/event-stream', 'content-type': 'application/json'})
      ..body = jsonEncode(request.toJson());
    http.StreamedResponse res;
    try {
      res = await _http.send(req).timeout(const Duration(seconds: 30));
    } catch (e) {
      throw BackendException('NETWORK', '$e');
    }
    if (res.statusCode != 200 || !(res.headers['content-type'] ?? '').contains('text/event-stream')) {
      _decode(res.statusCode, await res.stream.bytesToString());
      throw const BackendException('INTERNAL', 'Unexpected response');
    }
    var buffer = '';
    var gotResult = false;
    // The server sends a keep-alive every 15 s: 45 s of silence is a dead
    // connection, reported as a network error (the answer then resumes).
    final events = res.stream
        .transform(utf8.decoder)
        .timeout(
          const Duration(seconds: 45),
          onTimeout: (sink) {
            sink.addError(const BackendException('NETWORK', 'The connection to the server stalled'));
            sink.close();
          },
        );
    await for (final chunk in events) {
      buffer += chunk.replaceAll('\r\n', '\n');
      int idx;
      while ((idx = buffer.indexOf('\n\n')) >= 0) {
        final block = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);
        String? event;
        final data = StringBuffer();
        for (final line in block.split('\n')) {
          if (line.startsWith('event:')) event = line.substring(6).trim();
          if (line.startsWith('data:')) data.write(line.substring(5).trim());
        }
        if (event == null || data.isEmpty) continue;
        final payload = (jsonDecode(data.toString()) as Map).cast<String, dynamic>();
        switch (event) {
          case 'stage':
            final stage = AskStage.values.asNameMap()[payload['stage']];
            if (stage != null) yield AskStageEvent(stage);
          case 'plan':
            yield AskPlanEvent((payload['queries'] as List?)?.whereType<String>().toList() ?? const []);
          case 'sources':
            yield AskSourcesEvent((payload['count'] as num?)?.toInt() ?? 0, (payload['totalMatches'] as num?)?.toInt() ?? 0);
          case 'activity':
            yield AskActivityEvent(
              '${payload['kind'] ?? ''}',
              {...payload}
                ..remove('kind')
                ..remove('t'),
              (payload['t'] as num?)?.toInt() ?? 0,
            );
          case 'usage':
            yield AskUsageEvent(TokenUsage.fromJson(payload));
          case 'draft':
            yield AskDraftEvent('${payload['text'] ?? ''}');
          case 'result':
            gotResult = true;
            yield AskResultEvent(AnswerResult.fromJson(payload));
          case 'error':
            throw BackendException('${payload['code'] ?? 'INTERNAL'}', '${payload['message'] ?? ''}');
        }
      }
    }
    if (!gotResult) throw const BackendException('NETWORK', 'Connection closed before the answer arrived');
  }

  @override
  Future<SearchResultPage> search(
    String query, {
    int page = 1,
    SearchScope scope = SearchScope.all,
    TextSearchOptions options = TextSearchOptions.standard,
  }) async => SearchResultPage.fromJson(await _get('/api/search', {'q': query, 'page': '$page', ...scope.toRequest(), ...options.toRequest()}));

  @override
  Future<BookDetails> book(String id) async => BookDetails.fromJson(await _get('/api/books/$id'));

  @override
  Future<AuthorDetails> author(String id) async => AuthorDetails.fromJson(await _get('/api/authors/$id'));

  @override
  Future<PagePassage> page(String bookId, int page) async => PagePassage.fromJson(await _get('/api/pages/$bookId/$page'));

  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) async {
    final j = await _get('/api/pages/$bookId/$from-$to');
    return [
      for (final p in j['items'] as List? ?? const [])
        if (p is Map) PagePassage.fromJson(p.cast<String, dynamic>()),
    ];
  }

  @override
  Future<NarratorPage> narrators(String query, {int page = 1}) async =>
      NarratorPage.fromJson(await _get('/api/narrators', {if (query.trim().isNotEmpty) 'q': query.trim(), 'page': '$page'}));

  @override
  Future<Narrator> narrator(String id) async => Narrator.fromJson(await _get('/api/narrators/$id'));
  @override
  Future<List<dynamic>> discoveredBooks() async => (await _get('/api/catalog/discovered'))['books'] as List? ?? const [];
  @override
  Future<Map<String, bool>> pdfFlags(List<String> ids) async {
    final j = await _get('/api/books/pdf', {'ids': ids.join(',')});
    return {for (final e in (j['pdf'] as Map? ?? const {}).entries) '${e.key}': e.value == true};
  }

  @override
  Future<Map<String, bool>> pdfFlagsAll() async {
    final j = await _get('/api/books/pdf/all');
    return {for (final e in (j['pdf'] as Map? ?? const {}).entries) '${e.key}': e.value == true};
  }

  @override
  Future<({List<ModelInfo> models, String? auto})> models() async {
    final j = await _get('/api/models');
    return (
      models: [for (final m in (j['models'] as List? ?? const []).whereType<Map>()) ModelInfo.fromJson(m.cast<String, dynamic>())],
      auto: j['auto'] as String?,
    );
  }

  @override
  Future<LayersGuess> detectLayers(String title, List<String> pages) async {
    http.Response res;
    try {
      res = await _http
          .post(
            Uri.parse('$baseUrl/api/layers'),
            headers: {..._headers, 'content-type': 'application/json'},
            body: jsonEncode({'title': title, 'pages': _layerSamples(pages)}),
          )
          .timeout(const Duration(seconds: 90));
    } catch (e) {
      throw BackendException('NETWORK', '$e');
    }
    return LayersGuess.fromJson(_decode(res.statusCode, utf8.decode(res.bodyBytes)));
  }

  @override
  Future<String> check() async {
    final health = await _get('/api/health');
    if (health['gemini'] != true) throw const BackendException('GEMINI_AUTH', 'Server has no Gemini key');
    return '${health['model'] ?? ''}';
  }
}

class DirectBackend implements ManabiBackend {
  /// Without [apiKey] the library still works; only the AI parts fail, with
  /// [noAiCode] (what the user has to set up).
  DirectBackend({
    required String apiKey,
    required CatalogService catalog,
    String? model,
    http.Client? client,
    String turathBaseUrl = 'https://api.turath.io/',
    this.noAiCode = 'NO_API_KEY',
  }) : _turath = TurathClient(client: client, baseUrl: turathBaseUrl),
       _gemini = GeminiClient(apiKey: apiKey, model: model, client: client),
       _hasKey = apiKey.trim().isNotEmpty,
       _catalog = catalog;

  final TurathClient _turath;
  final GeminiClient _gemini;
  final CatalogService _catalog;
  final bool _hasKey;
  final String noAiCode;

  GeminiClient get _ai => _hasKey ? _gemini : throw BackendException(noAiCode);

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<AskEvent> ask(AskRequest request) async* {
    final pipeline = AnswerPipeline(model: _ai, turath: _turath, catalog: _catalog);
    try {
      yield* pipeline.ask(request);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all, TextSearchOptions options = TextSearchOptions.standard}) =>
      _wrap(() async {
        // One search per scope target (Turath filters one id of each kind).
        final targets = scope.targets;
        if (targets.length == 1) {
          final t = targets.first;
          return _turath.search(query, page: page, bookId: t.bookId, authorId: t.authorId, categoryId: t.categoryId, options: options);
        }
        final pages = await Future.wait([
          for (final t in targets)
            _turath
                .search(query, page: page, bookId: t.bookId, authorId: t.authorId, categoryId: t.categoryId, options: options)
                .catchError((Object _) => SearchResultPage(items: const [], totalMatches: 0, page: page)),
        ]);
        return mergeSearchPages(pages, page);
      });

  @override
  Future<BookDetails> book(String id) => _wrap(() => _turath.getBook(id));

  @override
  Future<AuthorDetails> author(String id) => _wrap(() => _turath.getAuthor(id));

  @override
  Future<PagePassage> page(String bookId, int page) => _wrap(() => _turath.getPage(bookId, page));

  @override
  Future<String> check() => _wrap(() => _ai.check());

  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) => _wrap(() => _turath.getPages(bookId, from, to));

  @override
  Future<NarratorPage> narrators(String query, {int page = 1}) => _wrap(() => _turath.searchNarrators(query, page: page));

  @override
  Future<Narrator> narrator(String id) => _wrap(() => _turath.getNarrator(id));
  @override
  Future<List<dynamic>> discoveredBooks() async => const [];
  @override
  Future<Map<String, bool>> pdfFlagsAll() async => const {};

  @override
  Future<({List<ModelInfo> models, String? auto})> models() => _wrap(() async {
    final list = await _ai.chatModelList();
    return (models: list, auto: await _ai.resolveModel());
  });

  @override
  Future<Map<String, bool>> pdfFlags(List<String> ids) => _wrap(() async {
    final out = <String, bool>{};
    await Future.wait([
      for (final id in ids)
        _turath
            .bookHasPdf(id)
            .then((v) {
              if (v != null) out[id] = v;
            })
            .catchError((Object _) {}),
    ]);
    return out;
  });

  @override
  Future<LayersGuess> detectLayers(String title, List<String> pages) => _wrap(
    () async => LayersGuess.fromJson(
      (await _ai.generateJson(
        system: layersSystem,
        prompt: layersPrompt(title: title, pages: _layerSamples(pages)),
        schema: layersSchema,
        temperature: 0,
        tier: ModelTier.fast,
      )).data,
    ),
  );
}

/// The Manabi server, with the library read straight from Turath when the
/// server cannot be reached: books open even when the AI side is down.
class LibraryFallbackBackend implements ManabiBackend {
  LibraryFallbackBackend(this.server, this.library);
  final ManabiBackend server;
  final ManabiBackend library;

  Future<T> _either<T>(Future<T> Function(ManabiBackend b) f) async {
    try {
      return await f(server);
    } on BackendException catch (e) {
      if (e.code != 'NETWORK' && e.code != 'INTERNAL' && e.code != 'UNAUTHORIZED') rethrow;
      return f(library);
    }
  }

  @override
  Stream<AskEvent> ask(AskRequest request) => server.ask(request);
  @override
  Future<String> check() => server.check();
  @override
  Future<LayersGuess> detectLayers(String title, List<String> pages) => server.detectLayers(title, pages);
  @override
  Future<({List<ModelInfo> models, String? auto})> models() => server.models();
  @override
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all, TextSearchOptions options = TextSearchOptions.standard}) =>
      _either((b) => b.search(query, page: page, scope: scope, options: options));
  @override
  Future<BookDetails> book(String id) => _either((b) => b.book(id));
  @override
  Future<AuthorDetails> author(String id) => _either((b) => b.author(id));
  @override
  Future<PagePassage> page(String bookId, int page) => _either((b) => b.page(bookId, page));
  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) => _either((b) => b.pages(bookId, from, to));
  @override
  Future<NarratorPage> narrators(String query, {int page = 1}) => _either((b) => b.narrators(query, page: page));
  @override
  Future<Narrator> narrator(String id) => _either((b) => b.narrator(id));
  @override
  Future<List<dynamic>> discoveredBooks() => _either((b) => b.discoveredBooks());
  @override
  Future<Map<String, bool>> pdfFlags(List<String> ids) => _either((b) => b.pdfFlags(ids));
  @override
  Future<Map<String, bool>> pdfFlagsAll() => _either((b) => b.pdfFlagsAll());
}
