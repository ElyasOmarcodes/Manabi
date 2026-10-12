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
    return BackendException(
        switch (e.code) {
          'NOT_FOUND' => 'NOT_FOUND',
          'RATE_LIMITED' => 'TURATH_RATE_LIMITED',
          'INVALID_ARGUMENT' => 'INVALID_ARGUMENT',
          _ => 'TURATH_UNAVAILABLE',
        },
        e.message);
  }
  if (e is GeminiException) {
    return BackendException(
        switch (e.code) {
          'AUTH' => 'GEMINI_AUTH',
          'QUOTA' => 'GEMINI_QUOTA',
          'NETWORK' => 'NETWORK',
          _ => 'GEMINI_UNAVAILABLE',
        },
        '${e.code}: ${e.message}');
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
}

List<String> _layerSamples(List<String> pages) => [for (final p in pages.where((p) => p.trim().isNotEmpty).take(4)) p.length > 5000 ? p.substring(0, 5000) : p];

class ServerBackend implements ManabiBackend {
  ServerBackend(String baseUrl, {this.accessToken, http.Client? client})
      : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _http = client ?? http.Client();

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
    final events = res.stream.transform(utf8.decoder).timeout(const Duration(seconds: 45), onTimeout: (sink) {
      sink.addError(const BackendException('NETWORK', 'The connection to the server stalled'));
      sink.close();
    });
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
            yield AskActivityEvent('${payload['kind'] ?? ''}', {...payload}..remove('kind')..remove('t'), (payload['t'] as num?)?.toInt() ?? 0);
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
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all, TextSearchOptions options = TextSearchOptions.standard}) async =>
      SearchResultPage.fromJson(await _get('/api/search', {'q': query, 'page': '$page', ...scope.toRequest(), ...options.toRequest()}));

  @override
  Future<BookDetails> book(String id) async => BookDetails.fromJson(await _get('/api/books/$id'));

  @override
  Future<AuthorDetails> author(String id) async => AuthorDetails.fromJson(await _get('/api/authors/$id'));

  @override
  Future<PagePassage> page(String bookId, int page) async => PagePassage.fromJson(await _get('/api/pages/$bookId/$page'));

  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) async {
    final j = await _get('/api/pages/$bookId/$from-$to');
    return [for (final p in j['items'] as List? ?? const []) if (p is Map) PagePassage.fromJson(p.cast<String, dynamic>())];
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
  Future<LayersGuess> detectLayers(String title, List<String> pages) async {
    http.Response res;
    try {
      res = await _http
          .post(Uri.parse('$baseUrl/api/layers'),
              headers: {..._headers, 'content-type': 'application/json'}, body: jsonEncode({'title': title, 'pages': _layerSamples(pages)}))
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
  DirectBackend({required String apiKey, required CatalogService catalog, String? model, http.Client? client})
      : _turath = TurathClient(client: client),
        _gemini = GeminiClient(apiKey: apiKey, model: model, client: client),
        _catalog = catalog;

  final TurathClient _turath;
  final GeminiClient _gemini;
  final CatalogService _catalog;

  Future<T> _wrap<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Stream<AskEvent> ask(AskRequest request) async* {
    final pipeline = AnswerPipeline(model: _gemini, turath: _turath, catalog: _catalog);
    try {
      yield* pipeline.ask(request);
    } catch (e) {
      throw mapError(e);
    }
  }

  @override
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all, TextSearchOptions options = TextSearchOptions.standard}) => _wrap(() =>
      _turath.search(query, page: page, bookId: scope.bookId, authorId: scope.authorId, categoryId: scope.categoryId, options: options));

  @override
  Future<BookDetails> book(String id) => _wrap(() => _turath.getBook(id));

  @override
  Future<AuthorDetails> author(String id) => _wrap(() => _turath.getAuthor(id));

  @override
  Future<PagePassage> page(String bookId, int page) => _wrap(() => _turath.getPage(bookId, page));

  @override
  Future<String> check() => _wrap(_gemini.check);

  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) => _wrap(() => _turath.getPages(bookId, from, to));

  @override
  Future<NarratorPage> narrators(String query, {int page = 1}) => _wrap(() => _turath.searchNarrators(query, page: page));

  @override
  Future<Narrator> narrator(String id) => _wrap(() => _turath.getNarrator(id));
  @override
  Future<List<dynamic>> discoveredBooks() async => const [];
  @override
  Future<Map<String, bool>> pdfFlags(List<String> ids) => _wrap(() async {
        final out = <String, bool>{};
        await Future.wait([
          for (final id in ids)
            _turath.bookHasPdf(id).then((v) {
              if (v != null) out[id] = v;
            }).catchError((Object _) {}),
        ]);
        return out;
      });

  @override
  Future<LayersGuess> detectLayers(String title, List<String> pages) => _wrap(() async => LayersGuess.fromJson((await _gemini.generateJson(
        system: layersSystem,
        prompt: layersPrompt(title: title, pages: _layerSamples(pages)),
        schema: layersSchema,
        temperature: 0,
        tier: ModelTier.fast,
      ))
          .data));
}

/// Used until the user configures a server or a key.
class UnconfiguredBackend implements ManabiBackend {
  const UnconfiguredBackend(this.code);
  final String code;
  Never _fail() => throw BackendException(code);
  @override
  Stream<AskEvent> ask(AskRequest request) => Stream.error(BackendException(code));
  @override
  Future<SearchResultPage> search(String query, {int page = 1, SearchScope scope = SearchScope.all, TextSearchOptions options = TextSearchOptions.standard}) async => _fail();
  @override
  Future<BookDetails> book(String id) async => _fail();
  @override
  Future<AuthorDetails> author(String id) async => _fail();
  @override
  Future<PagePassage> page(String bookId, int page) async => _fail();
  @override
  Future<String> check() async => _fail();
  @override
  Future<LayersGuess> detectLayers(String title, List<String> pages) async => _fail();
  @override
  Future<List<PagePassage>> pages(String bookId, int from, int to) async => _fail();
  @override
  Future<NarratorPage> narrators(String query, {int page = 1}) async => _fail();
  @override
  Future<Narrator> narrator(String id) async => _fail();
  @override
  Future<List<dynamic>> discoveredBooks() async => const [];
  @override
  Future<Map<String, bool>> pdfFlags(List<String> ids) async => const {};
}
