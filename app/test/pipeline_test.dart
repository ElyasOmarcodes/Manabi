import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manabi/core/catalog/catalog_service.dart';
import 'package:manabi/core/models/answer.dart';
import 'package:manabi/core/models/scope.dart';
import 'package:manabi/core/pipeline/answer_pipeline.dart';
import 'package:manabi/core/pipeline/quote_verifier.dart';
import 'package:manabi/core/turath/turath_client.dart';

// Real responses recorded from api.turath.io (fixtures from the Nusus project, MIT).
Map<String, dynamic> fixture(String name) => jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, dynamic>;

final page5 = fixture('page-147927-5.json');
final search = fixture('search-book-147927.json');

MockClient turathMock({bool empty = false, bool fail = false, List<Uri>? log}) => MockClient((req) async {
      log?.add(req.url);
      if (fail) return http.Response('down', 500);
      final p = req.url.queryParameters;
      Object body;
      switch (req.url.path) {
        case '/search':
          body = empty
              ? {'count': 0, 'data': []}
              : (p['q'] ?? '').contains('ني')
                  ? {
                      'count': 1,
                      'data': [
                        {'book_id': 147927, 'cat_id': 6, 'author_id': 44, 'meta': page5['meta'], 'text': page5['text']}
                      ]
                    }
                  : search;
        case '/page':
          final pg = int.parse(p['pg']!);
          if (pg == 5) {
            body = page5;
          } else {
            final hit = (search['data'] as List).cast<Map>().where((h) => jsonDecode(h['meta'] as String)['page_id'] == pg).firstOrNull;
            body = hit == null ? <String, dynamic>{} : {'meta': hit['meta'], 'text': hit['text']};
          }
        case '/book':
          body = fixture('book-147927.json');
        case '/author':
          body = fixture('author-44.json');
        default:
          return http.Response('{}', 404);
      }
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200, headers: {'content-type': 'application/json'});
    });

class ScriptedModel implements JsonModel {
  ScriptedModel(this.outputs);
  final List<Object> outputs;
  final prompts = <String>[];
  @override
  Future<ModelReply> generateJson(
      {required String system,
      required String prompt,
      required Map<String, dynamic> schema,
      double temperature = 0.2,
      ModelTier tier = ModelTier.main,
      void Function(String text)? onText}) async {
    prompts.add(prompt);
    final next = outputs.removeAt(0);
    if (next is Exception) throw next;
    final data = next is Map<String, dynamic> Function(String) ? next(prompt) : next as Map<String, dynamic>;
    onText?.call('{"status":"answered","answer":"draft');
    return (data: data, model: 'test-model', usage: const TokenUsage(input: 100, output: 10, calls: 1));
  }
}

Map<String, dynamic> plan({String type = 'hadith', String lang = 'ps'}) => {
      'standaloneQuestion': 'q',
      'detectedLanguage': lang,
      'questionType': type,
      'isIslamicStudies': true,
      'queries': ['إنما الأعمال بالنيات', 'النية'],
      'madhhabs': <String>[],
      'requestedBooks': <String>[],
      'referenceBooks': <String>[],
    };

String keyFor(String prompt, int page, String prefix) => RegExp('\\[($prefix\\d+)\\] Book: [^\\n]*Page: $page\\b').firstMatch(prompt)!.group(1)!;

void main() {
  late CatalogService catalog;
  setUpAll(() {
    catalog = CatalogService.parse(File('assets/catalog/catalog.json').readAsStringSync());
  });

  group('quote verifier', () {
    final text = page5['text'] as String;
    test('exact quote without diacritics is located, original text returned', () {
      final q = locateQuote(text, 'انما الأعمال بالنيات وإنما لكل امرئ ما نوى');
      expect(q, isNotNull);
      expect(q!.exact, isTrue);
      expect(text.contains(q.text), isTrue);
      expect(normalizeArabic(q.text), 'انما الاعمال بالنيات وانما لكل امري ما نوي');
    });
    test('close quote is accepted fuzzily but shown from the source', () {
      final q = locateQuote(text, 'فمن كانت هجرته إلى الله ورسوله فهجرته إلى ورسوله');
      expect(q, isNotNull);
      expect(q!.exact, isFalse);
      expect(text.contains(q.text), isTrue);
    });
    test('fabricated and too-short quotes are rejected', () {
      expect(locateQuote(text, 'من صلى الفجر في جماعة فهو في ذمة الله حتى يمسي'), isNull);
      expect(locateQuote(text, 'النيات'), isNull);
    });
  });

  group('turath client', () {
    test('page, book, author and search are normalized like Nusus', () async {
      final t = TurathClient(client: turathMock());
      final p = await t.getPage('147927', 5);
      expect(p.bookTitle, 'الأربعون النووية مع زيادات ابن رجب');
      expect(p.authorName, 'النووي');
      expect(p.volume, '1');
      expect(p.url, 'https://app.turath.io/book/147927?page=5');
      expect(p.shamelaUrl, 'https://shamela.ws/book/147927/5');
      expect(p.citation, 'النووي، الأربعون النووية مع زيادات ابن رجب، ج 1، ص 5، صفحة تراث 5، تراث 147927');
      expect(p.text.contains('<span'), isFalse);
      final b = await t.getBook('147927');
      expect(b.toc.length, greaterThan(10));
      expect(b.authorId, '44');
      final a = await t.getAuthor('44');
      expect(a.name, 'النووي');
      final s = await t.search('الإسلام', bookId: '147927');
      expect(s.totalMatches, 14);
      expect(s.items.first.internalPage, 25);
    });
  });

  group('pipeline', () {
    Map<String, dynamic> Function(String) rankPage(int page) =>
        (prompt) => {'selected': [keyFor(prompt, page, 'C')], 'coverage': 'full', 'followUpQueries': [], 'followUpBooks': []};

    test('live log, token usage, streamed draft, and a retry resumes the finished steps', () async {
      Map<String, dynamic> compose(String prompt) {
        final key = keyFor(prompt, 5, 'S');
        return {
          'status': 'answered',
          'answer': 'ځواب [$key].\n[[Q1]]',
          'citations': [
            {'id': 'Q1', 'sourceId': key, 'quote': 'إنما الأعمال بالنيات وإنما لكل امرئ ما نوى'}
          ],
          'opinions': [],
        };
      }

      final model = ScriptedModel([plan(), rankPage(5), Exception('connection dropped'), compose]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock()), catalog: catalog);
      const request = AskRequest(question: 'د نیت حدیث', language: 'ps', requestId: 'resume-test-1');
      final first = <AskEvent>[];
      await expectLater(pipeline.ask(request).forEach(first.add), throwsException);
      final kinds = first.whereType<AskActivityEvent>().map((e) => e.kind).toSet();
      expect(kinds.containsAll(['plan', 'search', 'found', 'rank', 'ranked', 'read', 'compose']), isTrue, reason: '$kinds');
      expect(first.whereType<AskUsageEvent>().last.usage.calls, 2);
      expect(model.prompts, hasLength(3));

      final again = await pipeline.ask(request).toList();
      expect(model.prompts, hasLength(4), reason: 'only the answer is written again');
      expect(again.whereType<AskDraftEvent>().single.text, 'draft');
      final r = (again.last as AskResultEvent).result;
      expect(r.status, AnswerStatus.answered);
      expect(r.usage.calls, 1);
    });

    test('partial JSON strings are read while streaming', () {
      expect(partialJsonString(r'{"status":"answered","answer":"a\nb \"q\" ا', 'answer'), 'a\nb "q" ا');
      expect(partialJsonString('{"answer":"x","summary":"y"}', 'answer'), 'x');
      expect(partialJsonString('{"status":"ans', 'answer'), isNull);
    });

    test('grounded answer: metadata from Turath, inline verified quotes, markers renumbered', () async {
      final model = ScriptedModel([
        plan(),
        rankPage(5),
        (String prompt) {
          final key = keyFor(prompt, 5, 'S');
          return {
            'status': 'answered',
            'answer': 'دا حدیث [$key] کې راغلی.\n[[Q1]]\n[[Q2]]\n[S77]',
            'citations': [
              {'id': 'Q1', 'sourceId': key, 'quote': 'إنما الأعمال بالنيات وإنما لكل امرئ ما نوى'},
              {'id': 'Q2', 'sourceId': key, 'quote': 'هذا كلام مختلق لا يوجد في هذا الكتاب أبدا'},
            ],
            'opinions': [
              {'holder': 'x', 'view': 'y', 'sourceIds': [key]}
            ],
          };
        },
      ]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock()), catalog: catalog);
      final events = await pipeline.ask(const AskRequest(question: 'د نیت حدیث', language: 'ps')).toList();
      final stages = events.whereType<AskStageEvent>().map((e) => e.stage).toSet().toList();
      expect(stages, AskStage.values);
      final r = (events.last as AskResultEvent).result;
      expect(r.status, AnswerStatus.answered);
      final lines = r.answer.split('\n');
      expect(lines.first, 'دا حدیث [1] کې راغلی.');
      final quotes = lines.where((l) => l.startsWith('> ')).toList();
      expect(quotes, hasLength(1));
      expect(quotes.single.endsWith(' [1]'), isTrue);
      expect((page5['text'] as String).contains(quotes.single.substring(2, quotes.single.length - 4)), isTrue);
      expect(r.answer.contains('[['), isFalse);
      final s = r.sources.single;
      expect(s.bookId, '147927');
      expect(s.authorName, 'النووي');
      expect(s.volume, '1');
      expect(s.printedPage, 5);
      expect(s.url, 'https://app.turath.io/book/147927?page=5');
      expect(s.quotes, hasLength(1));
      expect(r.opinions.single.sources, [1]);
    });

    test('unverifiable answer becomes insufficient', () async {
      final model = ScriptedModel([
        plan(lang: 'en'),
        rankPage(5),
        {
          'status': 'answered',
          'answer': 'Made up [S1]\n[[Q1]]',
          'citations': [
            {'id': 'Q1', 'sourceId': 'S1', 'quote': 'قال رسول الله من غش فليس منا والمكر والخداع في النار'}
          ],
        },
      ]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock()), catalog: catalog);
      final r = ((await pipeline.ask(const AskRequest(question: 'q')).toList()).last as AskResultEvent).result;
      expect(r.status, AnswerStatus.insufficient);
      expect(r.answer, insufficientMessages['en']);
      expect(r.sources, isEmpty);
      expect(r.related, isNotEmpty);
    });

    test('no matches: reading and compose never run', () async {
      final model = ScriptedModel([plan(lang: 'fa')]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock(empty: true)), catalog: catalog);
      final r = ((await pipeline.ask(const AskRequest(question: 'q', language: 'fa')).toList()).last as AskResultEvent).result;
      expect(r.status, AnswerStatus.insufficient);
      expect(r.answer, insufficientMessages['fa']);
      expect(model.prompts, hasLength(1));
    });

    test('follow-up round searches new queries', () async {
      final log = <Uri>[];
      final model = ScriptedModel([
        {...plan(), 'queries': ['الإسلام']},
        {'selected': [], 'coverage': 'partial', 'missing': 'x', 'followUpQueries': ['النيات'], 'followUpBooks': []},
        rankPage(5),
        (String prompt) {
          final key = keyFor(prompt, 5, 'S');
          return {
            'status': 'answered',
            'answer': 'x [$key]\n[[Q1]]',
            'citations': [
              {'id': 'Q1', 'sourceId': key, 'quote': 'إنما الأعمال بالنيات وإنما لكل امرئ ما نوى'}
            ]
          };
        },
      ]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock(log: log)), catalog: catalog);
      final r = ((await pipeline.ask(const AskRequest(question: 'q', language: 'ar')).toList()).last as AskResultEvent).result;
      expect(log.any((u) => u.path == '/search' && u.queryParameters['q'] == 'النيات'), isTrue);
      expect(r.status, AnswerStatus.answered);
      expect(model.prompts, hasLength(4));
    });

    test('quick research skips the follow-up round; deep plans more searches', () async {
      final log = <Uri>[];
      final model = ScriptedModel([
        {...plan(), 'queries': ['الإسلام']},
        {'selected': [], 'coverage': 'partial', 'missing': 'x', 'followUpQueries': ['النيات'], 'followUpBooks': []},
        {'status': 'insufficient', 'answer': '', 'citations': []},
      ]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock(log: log)), catalog: catalog);
      await pipeline.ask(const AskRequest(question: 'q', language: 'ar', depth: 'quick')).toList();
      expect(log.any((u) => u.path == '/search' && u.queryParameters['q'] == 'النيات'), isFalse);
      expect(model.prompts, hasLength(3));
      final queries = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
      int count(Limits l) => searchPlan(queries: queries, madhhabs: ['hanafi'], referenceBookIds: ['1', '2', '3', '4', '5', '6'], limits: l).length;
      expect(count(Limits.quick) < count(Limits.standard) && count(Limits.standard) < count(Limits.deep), isTrue);
    });

    test('Turath outage is reported', () async {
      final model = ScriptedModel([plan()]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock(fail: true)), catalog: catalog);
      expect(pipeline.ask(const AskRequest(question: 'q')).toList(), throwsA(isA<PipelineException>().having((e) => e.code, 'code', 'TURATH_UNAVAILABLE')));
    });

    test('a user scope is strict: every search stays inside the book', () async {
      final log = <Uri>[];
      final model = ScriptedModel([
        {...plan(type: 'fiqh'), 'madhhabs': ['hanafi'], 'referenceBooks': ['رد المحتار']},
        {'selected': [], 'coverage': 'none', 'followUpQueries': [], 'followUpBooks': []},
      ]);
      final pipeline = AnswerPipeline(model: model, turath: TurathClient(client: turathMock(log: log)), catalog: catalog);
      await pipeline.ask(const AskRequest(question: 'q', scope: SearchScope(bookId: '12836'))).toList();
      final searches = log.where((u) => u.path == '/search');
      expect(searches, isNotEmpty);
      expect(searches.every((u) => u.queryParameters['book'] == '12836'), isTrue);
      expect(model.prompts.first, contains('الأربعون النووية'));
    });

    test('search plan and book resolution match the server', () {
      final p = searchPlan(queries: ['a', 'b', 'c', 'd'], madhhabs: ['hanafi', 'shafii'], requestedBookIds: ['1'], referenceBookIds: ['2', '3']);
      expect(p.any((s) => s.kind == 'requested' && s.bookId == '1'), isTrue);
      expect(p.where((s) => s.kind == 'madhhab').map((s) => s.categoryId).toSet(), {'14', '16'});
      expect(resolveBooks(['رد المحتار'], catalog), ['21613']);
      expect(resolveBooks(['الفقه الاسلامي وأدلته'], catalog), ['384']);
      expect(resolveBooks(['الموسوعة الفقهية'], catalog), ['38056']);
    });
  });

  group('catalog', () {
    test('book and author search', () {
      expect(catalog.books.length, greaterThan(8000));
      expect(catalog.findBooks('الاربعون النوويه').map((b) => b.id), contains('12836'));
      expect(catalog.findAuthors('النووي').first.name, 'النووي');
      expect(catalog.categories, hasLength(40));
      expect(catalog.booksByAuthor('44'), isNotEmpty);
    });
  });

  test('answer JSON round trip', () {
    final json = {
      'status': 'partial',
      'answer': 'x [1]',
      'sources': [
        {'n': 1, 'bookId': '1', 'bookTitle': 't', 'url': 'u', 'quotes': [{'text': 'q', 'exact': true}], 'printedPage': 3}
      ],
      'opinions': [{'holder': 'h', 'view': 'v', 'sources': [1]}],
      'queries': ['a'],
      'language': 'ar',
    };
    final r = AnswerResult.fromJson(json);
    final again = AnswerResult.fromJson(jsonDecode(jsonEncode(r.toJson())) as Map<String, dynamic>);
    expect(again.status, AnswerStatus.partial);
    expect(again.sources.single.quotes.single.text, 'q');
    expect(again.sources.single.printedPage, 3);
    expect(again.opinions.single.sources, [1]);
  });

  test('pipeline adds the continuation page as its own source', () async {
    var composePromptText = '';
    final model = ScriptedModel([
      plan(),
      (String prompt) => {'selected': [keyFor(prompt, 5, 'C')], 'coverage': 'full', 'followUpQueries': [], 'followUpBooks': []},
      (String prompt) {
        composePromptText = prompt;
        return {'status': 'insufficient', 'answer': '', 'citations': []};
      },
    ]);
    await AnswerPipeline(model: model, turath: TurathClient(client: turathMock()), catalog: catalog).ask(const AskRequest(question: 'q')).toList();
    expect(RegExp(r'\[S1\] Book: [^\n]*Page: 5\b').hasMatch(composePromptText), isTrue);
    expect(RegExp(r'\[S2\] Book: [^\n]*Page: 6\b').hasMatch(composePromptText), isTrue);
  });

  test('schools named in the question are detected', () {
    expect(namedMadhhabs('د حنفي مذهب علماء څه فرمايي'), ['hanafi']);
    expect(namedMadhhabs('What do the Shafi\'is and Hanbalis say?'), ['shafii', 'hanbali']);
    expect(namedMadhhabs('حدیث نیت'), isEmpty);
  });
}
