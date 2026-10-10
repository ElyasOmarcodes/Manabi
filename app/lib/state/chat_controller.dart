import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/backend/backend.dart';
import '../core/models/answer.dart';
import '../core/models/chat.dart';
import '../core/models/scope.dart';
import '../core/pipeline/answer_pipeline.dart';
import '../core/pipeline/prompts.dart';
import '../core/storage/chat_store.dart';

/// Live progress of a pending answer (not persisted).
class AskProgress {
  AskStage stage = AskStage.planning;
  List<String> queries = const [];
  int? sourcesFound;
}

class ChatController extends ChangeNotifier {
  ChatController(this._store, this._backend) : chats = _store.loadAll();

  final ChatStore _store;
  ManabiBackend Function() _backend;
  final List<Chat> chats;
  final Map<String, AskProgress> progress = {};
  final Map<String, StreamSubscription<AskEvent>> _running = {};
  String? currentId;
  static const _uuid = Uuid();

  set backendProvider(ManabiBackend Function() fn) => _backend = fn;

  Chat? get current => currentId == null ? null : chats.where((c) => c.id == currentId).firstOrNull;

  List<Chat> get sortedChats => [...chats]..sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });

  List<(Chat, ChatTurn)> get favorites => [
        for (final c in chats)
          for (final t in c.turns)
            if (t.favorite) (c, t),
      ]..sort((a, b) => b.$2.askedAt.compareTo(a.$2.askedAt));

  List<(Chat, ChatTurn)> searchHistory(String query) {
    final q = query.trim().toLowerCase();
    return [
      for (final c in chats)
        for (final t in c.turns)
          if (q.isEmpty || t.question.toLowerCase().contains(q) || (t.result?.answer.toLowerCase().contains(q) ?? false)) (c, t),
    ]..sort((a, b) => b.$2.askedAt.compareTo(a.$2.askedAt));
  }

  bool get busy => _running.isNotEmpty;

  void newChat() {
    currentId = null;
    notifyListeners();
  }

  void open(String id) {
    currentId = id;
    notifyListeners();
  }

  Future<void> ask(String question, {required String language, required String fallbackLanguage, SearchScope scope = SearchScope.all, int maxSources = 10}) async {
    final text = question.trim();
    if (text.isEmpty) return;
    var chat = current;
    final now = DateTime.now();
    if (chat == null) {
      chat = Chat(id: _uuid.v4(), title: _titleFor(text), createdAt: now, updatedAt: now);
      chats.insert(0, chat);
      currentId = chat.id;
    }
    final turn = ChatTurn(id: _uuid.v4(), question: text, askedAt: now, language: language, scope: scope);
    chat.turns.add(turn);
    chat.updatedAt = now;
    await _store.save(chat);
    _run(chat, turn, fallbackLanguage: fallbackLanguage, maxSources: maxSources);
  }

  void retry(ChatTurn turn, {required String fallbackLanguage, int maxSources = 10}) {
    final chat = chats.firstWhere((c) => c.turns.contains(turn));
    turn
      ..state = MessageState.pending
      ..errorCode = null
      ..result = null;
    _run(chat, turn, fallbackLanguage: fallbackLanguage, maxSources: maxSources);
  }

  void cancel(ChatTurn turn) {
    _running.remove(turn.id)?.cancel();
    progress.remove(turn.id);
    turn
      ..state = MessageState.failed
      ..errorCode = 'CANCELLED';
    _persist(turn);
    notifyListeners();
  }

  void _run(Chat chat, ChatTurn turn, {required String fallbackLanguage, required int maxSources}) {
    final previous = chat.turns.takeWhile((t) => t != turn).where((t) => t.state == MessageState.done).toList();
    final history = [
      for (final t in previous.length > 3 ? previous.sublist(previous.length - 3) : previous)
        HistoryTurn(t.question, t.result?.summary.isNotEmpty == true ? t.result!.summary : _clip(t.result?.answer ?? '')),
    ];
    final p = progress[turn.id] = AskProgress();
    notifyListeners();
    final request = AskRequest(
        question: turn.question, language: turn.language, fallbackLanguage: fallbackLanguage, scope: turn.scope, history: history, maxSources: maxSources);
    _running[turn.id] = _backend().ask(request).listen(
      (event) {
        switch (event) {
          case AskStageEvent(:final stage):
            p.stage = stage;
          case AskPlanEvent(:final queries):
            p.queries = queries;
          case AskSourcesEvent(:final count):
            p.sourcesFound = count;
          case AskResultEvent(:final result):
            turn
              ..result = result
              ..state = MessageState.done;
        }
        notifyListeners();
      },
      onError: (Object e) {
        turn
          ..state = MessageState.failed
          ..errorCode = mapError(e).code;
        _finish(chat, turn);
      },
      onDone: () {
        if (turn.state == MessageState.pending) {
          turn
            ..state = MessageState.failed
            ..errorCode = 'NETWORK';
        }
        _finish(chat, turn);
      },
      cancelOnError: true,
    );
  }

  void _finish(Chat chat, ChatTurn turn) {
    _running.remove(turn.id);
    progress.remove(turn.id);
    chat.updatedAt = DateTime.now();
    _store.save(chat);
    notifyListeners();
  }

  void _persist(ChatTurn turn) {
    final chat = chats.where((c) => c.turns.contains(turn)).firstOrNull;
    if (chat != null) _store.save(chat);
  }

  void toggleFavorite(ChatTurn turn) {
    turn.favorite = !turn.favorite;
    _persist(turn);
    notifyListeners();
  }

  Future<void> rename(Chat chat, String title) async {
    chat.title = title.trim().isEmpty ? chat.title : title.trim();
    await _store.save(chat);
    notifyListeners();
  }

  Future<void> togglePin(Chat chat) async {
    chat.pinned = !chat.pinned;
    await _store.save(chat);
    notifyListeners();
  }

  Future<void> delete(Chat chat) async {
    for (final t in chat.turns) {
      _running.remove(t.id)?.cancel();
      progress.remove(t.id);
    }
    chats.remove(chat);
    if (currentId == chat.id) currentId = null;
    await _store.delete(chat.id);
    notifyListeners();
  }

  Future<void> clearAll() async {
    for (final s in _running.values) {
      s.cancel();
    }
    _running.clear();
    progress.clear();
    chats.clear();
    currentId = null;
    await _store.clear();
    notifyListeners();
  }

  static String _titleFor(String q) {
    final single = q.replaceAll(RegExp(r'\s+'), ' ');
    return single.length <= 48 ? single : '${single.substring(0, 47)}…';
  }

  static String _clip(String s) => s.length <= 300 ? s : s.substring(0, 300);

  @override
  void dispose() {
    for (final s in _running.values) {
      s.cancel();
    }
    super.dispose();
  }
}
