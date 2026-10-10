import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:manabi/core/backend/backend.dart';
import 'package:manabi/core/catalog/catalog_service.dart';
import 'package:manabi/core/models/answer.dart';
import 'package:manabi/core/pipeline/answer_pipeline.dart';
import 'package:manabi/core/storage/chat_store.dart';
import 'package:manabi/main.dart';
import 'package:manabi/state/chat_controller.dart';
import 'package:manabi/state/settings_controller.dart';
import 'package:manabi/ui/export/exporter.dart';
import 'package:manabi/l10n/gen/app_localizations_en.dart';
import 'package:manabi/core/models/chat.dart';
import 'package:manabi/ui/widgets/depth_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

const sampleResult = {
  'status': 'answered',
  'answer': 'The hadith is narrated by **al-Bukhari and Muslim** [1].\n\n- First point [1]',
  'sources': [
    {
      'n': 1,
      'bookId': '147927',
      'bookTitle': 'الأربعون النووية مع زيادات ابن رجب',
      'authorName': 'النووي',
      'volume': '1',
      'printedPage': 5,
      'internalPage': 5,
      'url': 'https://app.turath.io/book/147927?page=5',
      'quotes': [
        {'text': 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', 'exact': true}
      ],
    }
  ],
  'language': 'en',
};

/// Lets a page transition finish (several frames).
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  test('server backend parses the SSE stream', () async {
    final client = MockClient.streaming((req, body) async {
      expect(req.url.path, '/api/ask');
      expect(req.headers['accept'], 'text/event-stream');
      final events = [
        'event: stage\ndata: {"stage":"planning"}\n\n',
        'event: plan\ndata: {"queries":["النية"]}\n\n',
        'event: stage\ndata: {"stage":"searching"}\n\n',
        ': keep-alive\n\n',
        'event: sources\ndata: {"count":3,"totalMatches":40}\n\n',
        'event: result\ndata: ${jsonEncode(sampleResult)}\n\n',
      ];
      return http.StreamedResponse(Stream.fromIterable(events.map(utf8.encode)), 200, headers: {'content-type': 'text/event-stream; charset=utf-8'});
    });
    final backend = ServerBackend('https://example.org/', client: client);
    final events = await backend.ask(const AskRequest(question: 'q')).toList();
    expect(events.whereType<AskStageEvent>().map((e) => e.stage), [AskStage.planning, AskStage.searching]);
    expect(events.whereType<AskPlanEvent>().single.queries, ['النية']);
    expect(events.whereType<AskSourcesEvent>().single.count, 3);
    final result = events.whereType<AskResultEvent>().single.result;
    expect(result.sources.single.printedPage, 5);
  });

  test('server errors are mapped to codes', () async {
    final client = MockClient((req) async => http.Response(jsonEncode({'error': {'code': 'GEMINI_QUOTA', 'message': 'x'}}), 503, headers: {'content-type': 'application/json'}));
    final backend = ServerBackend('https://example.org', client: client);
    expect(backend.ask(const AskRequest(question: 'q')).toList(), throwsA(isA<BackendException>().having((e) => e.code, 'code', 'GEMINI_QUOTA')));
  });

  test('markdown and text export include citation data', () {
    final turn = ChatTurn(id: '1', question: 'Who narrated it?', askedAt: DateTime(2026), language: 'en', state: MessageState.done)
      ..result = AnswerResult.fromJson(sampleResult);
    final l = AppLocalizationsEn();
    final md = turnsAsMarkdown('Test', [turn], l);
    expect(md, contains('الأربعون النووية مع زيادات ابن رجب'));
    expect(md, contains('https://app.turath.io/book/147927?page=5'));
    expect(md, contains('> إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ'));
    final txt = answerAsText(turn, l);
    expect(txt, isNot(contains('**')));
    expect(txt, contains('Vol. 1'));
  });

  group('app', () {
    late Directory tmp;
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('manabi_test');
      SharedPreferences.setMockInitialValues({'uiLanguage': 'en', 'mode': 'server', 'serverUrl': ''});
    });
    tearDown(() => tmp.delete(recursive: true));

    Future<AppServices> services() async {
      final catalog = CatalogService.parse(File('assets/catalog/catalog.json').readAsStringSync());
      final settings = await SettingsController.load(catalog);
      final store = await ChatStore.openAt(tmp.path);
      return AppServices(catalog, settings, ChatController(store, () => settings.backend));
    }

    testWidgets('welcome screen, unconfigured warning and navigation', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await tester.runAsync(services);
      await tester.pumpWidget(ManabiApp(services: Future.value(s)));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('What would you like to research today?'), findsOneWidget);
      expect(find.text('Set up a connection'), findsOneWidget);
      // Asking without a server configured fails gracefully with a setup hint.
      await tester.enterText(find.byType(TextField).last, 'What is ihsan?');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('No Manabi server is set. Add the server address in Settings.'), findsOneWidget);
      // The sidebar opens the library (offline catalog) and settings as pages.
      await tester.tap(find.text('Library').first);
      await settle(tester);
      expect(find.text('The Turath library'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);
      await tester.tap(find.text('Settings').first);
      await settle(tester);
      // Settings home lists sections; each opens its own page.
      for (final (row, marker) in [
        ('Appearance', 'Text size'),
        ('AI style', 'Research depth'),
        ('Connection', 'Test connection'),
        ('Data & storage', 'Reset settings'),
        ('Help', 'How Manabi works'),
        ('Privacy policy', 'What is stored'),
        ('About us', 'Open-source licenses'),
      ]) {
        await tester.scrollUntilVisible(find.text(row), 200, scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text(row));
        await settle(tester);
        await tester.scrollUntilVisible(find.text(marker), 200, scrollable: find.byType(Scrollable).last);
        expect(find.text(marker), findsOneWidget, reason: '$row page');
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await settle(tester);
      }
      // AI style: choosing a research depth is remembered.
      await tester.scrollUntilVisible(find.text('AI style'), 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('AI style'));
      await settle(tester);
      await tester.tap(find.text('Deep'));
      await settle(tester);
      expect(s!.settings.researchDepth, 'deep');
      // The app language opens as a dialog.
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await settle(tester);
      await tester.tap(find.text('App language'));
      await settle(tester);
      expect(find.text('پښتو'), findsWidgets);
    });

    testWidgets('composer: + sheet and research depth slider', (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final s = await tester.runAsync(services);
      await tester.pumpWidget(ManabiApp(services: Future.value(s)));
      await tester.pump(const Duration(seconds: 2));
      await tester.tap(find.byTooltip('Search options'));
      await settle(tester);
      expect(find.text('Search scope'), findsOneWidget);
      expect(find.text('Research depth'), findsOneWidget);
      await tester.tap(find.text('Research depth'));
      await settle(tester);
      // Drag the slider to the far end (deep).
      final slider = find.byType(DepthSlider);
      await tester.tapAt(tester.getTopRight(slider) + const Offset(-20, 28));
      await settle(tester);
      expect(s!.settings.researchDepth, 'deep');
      expect(tester.takeException(), isNull);
    });

    for (final lang in ['ps', 'fa', 'ar']) {
      testWidgets('phone layout in $lang (dark) renders every section', (tester) async {
        tester.view.physicalSize = const Size(390 * 3, 844 * 3);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({'uiLanguage': lang, 'themeMode': 'dark', 'mode': 'server', 'serverUrl': ''});
        final s = await tester.runAsync(services);
        await tester.pumpWidget(ManabiApp(services: Future.value(s)));
        await tester.pump(const Duration(seconds: 2));
        // GPT-style structure: menu → each destination opens as a page.
        for (final icon in [Icons.auto_stories_rounded, Icons.bookmark_rounded, Icons.history_rounded, Icons.settings_rounded]) {
          await tester.tap(find.byIcon(Icons.notes_rounded));
          await settle(tester);
          await tester.tap(find.byIcon(icon).last);
          await settle(tester);
          expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget, reason: 'page has a back button (RTL)');
          await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
          await settle(tester);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}
