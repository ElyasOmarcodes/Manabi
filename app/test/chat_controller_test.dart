import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/backend/backend.dart';
import 'package:manabi/core/models/answer.dart';
import 'package:manabi/core/models/chat.dart';
import 'package:manabi/core/pipeline/answer_pipeline.dart';
import 'package:manabi/core/storage/chat_store.dart';
import 'package:manabi/state/chat_controller.dart';

/// First answer drops like a backgrounded phone's connection; later ones succeed.
class FlakyBackend implements ManabiBackend {
  final requests = <AskRequest>[];
  int failures = 1;

  @override
  Stream<AskEvent> ask(AskRequest request) async* {
    requests.add(request);
    yield const AskStageEvent(AskStage.planning);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (failures-- > 0) throw const BackendException('NETWORK', 'connection closed');
    yield AskResultEvent(AnswerResult.fromJson(const {'status': 'answered', 'answer': 'ok', 'sources': [], 'language': 'en'}));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  setUp(() async => tmp = await Directory.systemTemp.createTemp('manabi_chat'));
  tearDown(() => tmp.delete(recursive: true));

  Future<void> idle() => Future<void>.delayed(const Duration(milliseconds: 60));

  test('an answer interrupted in the background resumes on return, with the same request id', () async {
    final backend = FlakyBackend();
    final chats = ChatController(await ChatStore.openAt(tmp.path), () => backend);
    await chats.ask('q', language: 'en', fallbackLanguage: 'en', depth: 'deep');
    chats.didChangeAppLifecycleState(AppLifecycleState.paused);
    await idle();
    final turn = chats.current!.turns.single;
    expect(turn.state, MessageState.pending, reason: 'not failed while in the background');
    expect(backend.requests, hasLength(1));
    chats.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await idle();
    expect(backend.requests, hasLength(2));
    expect(backend.requests.last.requestId, backend.requests.first.requestId);
    expect(backend.requests.last.depth, 'deep');
    expect(turn.state, MessageState.done);
    chats.dispose();
  });

  test('a dropped connection in the foreground is retried, then reported', () async {
    final backend = FlakyBackend();
    final chats = ChatController(await ChatStore.openAt(tmp.path), () => backend, retryDelays: const [Duration(milliseconds: 5)]);
    await chats.ask('q', language: 'en', fallbackLanguage: 'en');
    await idle();
    final turn = chats.current!.turns.single;
    expect(turn.state, MessageState.done, reason: 'one automatic retry with the same request id');
    expect(backend.requests, hasLength(2));
    expect(backend.requests.last.requestId, backend.requests.first.requestId);

    backend.failures = 5;
    chats.retry(turn, fallbackLanguage: 'en');
    await idle();
    expect(turn.state, MessageState.failed, reason: 'gives up after the retries');
    expect(turn.errorCode, 'NETWORK');
    expect(backend.requests, hasLength(4));
    chats.dispose();
  });
}
