import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../core/backend/backend.dart';
import '../core/models/answer.dart';
import '../core/models/chat.dart';
import '../core/models/scope.dart';
import '../core/pipeline/answer_pipeline.dart';
import '../core/pipeline/prompts.dart';
import '../core/storage/chat_store.dart';
import 'keep_alive.dart';

/// Live progress of a pending answer (not persisted).
class AskProgress {
  AskProgress({DateTime? startedAt, List<AskActivityEvent>? activity}) : startedAt = startedAt ?? DateTime.now(), activity = activity ?? [];
  final DateTime startedAt;
  AskStage stage = AskStage.planning;
  List<String> queries = const [];
  int? sourcesFound;

  /// The live research log, oldest first.
  final List<AskActivityEvent> activity;
  TokenUsage usage = const TokenUsage();

  /// The answer as it is being written.
  String? draft;

  /// Set while waiting to try again after a dropped connection.
  int? retryIn;
  int attempt = 0;
}

/// Errors that happen when the connection drops (e.g. the phone put the app
/// in the background); such answers are resumed automatically.
const _transientCodes = {'NETWORK', 'GEMINI_UNAVAILABLE', 'TURATH_UNAVAILABLE', 'INTERRUPTED', 'INTERNAL'};

/// Waits before each automatic retry of an interrupted answer.
const _defaultRetryDelays = [Duration(seconds: 2), Duration(seconds: 6), Duration(seconds: 15)];

class ChatController extends ChangeNotifier with WidgetsBindingObserver {
  ChatController(this._store, this._backend, {AnswerKeepAlive? keepAlive, List<Duration> retryDelays = _defaultRetryDelays})
      : chats = _store.loadAll(),
        _retryDelays = retryDelays,
        _keepAlive = keepAlive ?? AnswerKeepAlive.platform() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Keeps the app (and its connection) alive while answers are prepared.
  final AnswerKeepAlive _keepAlive;
  final List<Duration> _retryDelays;
  final Map<String, int> _attempts = {};
  final Map<String, Timer> _retryTimers = {};

  final ChatStore _store;
  ManabiBackend Function() _backend;
  final List<Chat> chats;
  final Map<String, AskProgress> progress = {};
  final Map<String, StreamSubscription<AskEvent>> _running = {};
  final Map<String, ({String fallbackLanguage, String depth, String requestId})> _requests = {};
  final Set<String> _sawBackground = {};
  final Set<String> _resumeQueue = {};
  bool _inBackground = false;
  String? currentId;
  static const _uuid = Uuid();

  set backendProvider(ManabiBackend Function() fn) => _backend = fn;

  /// Text of the "preparing your answer" notification.
  set keepAliveLabels(({String title, String text}) value) => _keepAlive.labels = value;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _inBackground = true;
      _sawBackground.addAll(_running.keys);
    } else if (state == AppLifecycleState.resumed) {
      _inBackground = false;
      final queued = [..._resumeQueue];
      _resumeQueue.clear();
      for (final id in queued) {
        final found = _find(id);
        if (found != null && found.$2.state == MessageState.pending) _start(found.$1, found.$2, keepProgress: true);
      }
    }
  }

  (Chat, ChatTurn)? _find(String turnId) {
    for (final c in chats) {
      for (final t in c.turns) {
        if (t.id == turnId) return (c, t);
      }
    }
    return null;
  }

  Future<void> ask(String question, {required String language, required String fallbackLanguage, SearchScope scope = SearchScope.all, String depth = 'standard'}) async {
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
    _requests[turn.id] = (fallbackLanguage: fallbackLanguage, depth: depth, requestId: _uuid.v4());
    _start(chat, turn);
  }

  void retry(ChatTurn turn, {required String fallbackLanguage, String depth = 'standard'}) {
    final chat = chats.firstWhere((c) => c.turns.contains(turn));
    // Same request id: if the server finished the answer meanwhile, it is
    // returned at once without asking Gemini again.
    final previous = _requests[turn.id];
    _requests[turn.id] = (fallbackLanguage: fallbackLanguage, depth: depth, requestId: previous?.requestId ?? _uuid.v4());
    _attempts.remove(turn.id);
    _retryTimers.remove(turn.id)?.cancel();
    _start(chat, turn);
  }

  void _start(Chat chat, ChatTurn turn, {bool keepProgress = false}) {
    turn
      ..state = MessageState.pending
      ..errorCode = null
      ..errorDetail = null
      ..result = null;
    if (!keepProgress) progress.remove(turn.id);
    final r = _requests[turn.id] ?? (fallbackLanguage: 'en', depth: 'standard', requestId: _uuid.v4());
    _run(chat, turn, fallbackLanguage: r.fallbackLanguage, depth: r.depth, requestId: r.requestId);
  }

  void _syncKeepAlive() {
    final busy = _running.isNotEmpty || _retryTimers.isNotEmpty || _resumeQueue.isNotEmpty;
    busy ? _keepAlive.start() : _keepAlive.stop();
  }

  void cancel(ChatTurn turn) {
    _running.remove(turn.id)?.cancel();
    _resumeQueue.remove(turn.id);
    _retryTimers.remove(turn.id)?.cancel();
    _attempts.remove(turn.id);
    progress.remove(turn.id);
    _syncKeepAlive();
    turn
      ..state = MessageState.failed
      ..errorCode = 'CANCELLED';
    _persist(turn);
    notifyListeners();
  }

  void _run(Chat chat, ChatTurn turn, {required String fallbackLanguage, required String depth, required String requestId}) {
    final previous = chat.turns.takeWhile((t) => t != turn).where((t) => t.state == MessageState.done).toList();
    final history = [
      for (final t in previous.length > 3 ? previous.sublist(previous.length - 3) : previous)
        HistoryTurn(
          t.question,
          t.result?.summary.isNotEmpty == true ? t.result!.summary : _clip(t.result?.answer ?? ''),
          [for (final src in t.result?.sources ?? const []) src.bookTitle],
        ),
    ];
    final before = progress[turn.id];
    final p = progress[turn.id] = AskProgress(startedAt: before?.startedAt, activity: before?.activity)..attempt = _attempts[turn.id] ?? 0;
    if (before != null) p.usage = before.usage;
    if (_inBackground) _sawBackground.add(turn.id);
    notifyListeners();
    final request = AskRequest(
        question: turn.question,
        language: turn.language,
        fallbackLanguage: fallbackLanguage,
        scope: turn.scope,
        history: history,
        depth: depth,
        requestId: requestId);
    _running[turn.id] = _backend().ask(request).listen(
      (event) {
        switch (event) {
          case AskStageEvent(:final stage):
            p.stage = stage;
          case AskPlanEvent(:final queries):
            p.queries = queries;
          case AskSourcesEvent(:final count):
            p.sourcesFound = count;
          case AskActivityEvent():
            p.activity.add(event);
          case AskUsageEvent(:final usage):
            p.usage = usage;
          case AskDraftEvent(:final text):
            p.draft = text;
          case AskResultEvent(:final result):
            turn
              ..result = result
              ..state = MessageState.done;
        }
        notifyListeners();
      },
      onError: (Object e) {
        final error = mapError(e);
        _fail(chat, turn, error.code, detail: error.message);
      },
      onDone: () {
        if (turn.state == MessageState.pending) return _fail(chat, turn, 'NETWORK');
        _finish(chat, turn);
      },
      cancelOnError: true,
    );
    _syncKeepAlive();
  }

  void _fail(Chat chat, ChatTurn turn, String code, {String? detail}) {
    _running.remove(turn.id);
    // A dropped connection (often the phone suspending the app): try again
    // with the same request id, which resumes from the finished steps.
    final attempt = _attempts[turn.id] ?? 0;
    if (_transientCodes.contains(code) && attempt < _retryDelays.length) {
      _attempts[turn.id] = attempt + 1;
      final p = progress[turn.id];
      if (p != null) p.activity.add(AskActivityEvent('retry', {'code': code, 'attempt': attempt + 1}, DateTime.now().difference(p.startedAt).inMilliseconds));
      if (_inBackground || _sawBackground.contains(turn.id)) {
        _sawBackground.remove(turn.id);
        if (_inBackground) {
          _resumeQueue.add(turn.id);
          notifyListeners();
          return;
        }
      }
      final delay = _retryDelays[attempt];
      p?.retryIn = delay.inSeconds;
      notifyListeners();
      _retryTimers[turn.id]?.cancel();
      _retryTimers[turn.id] = Timer(delay, () {
        _retryTimers.remove(turn.id);
        if (turn.state != MessageState.pending) return;
        if (_inBackground) {
          _resumeQueue.add(turn.id);
        } else {
          _start(chat, turn, keepProgress: true);
        }
      });
      return;
    }
    turn
      ..state = MessageState.failed
      ..errorCode = code
      ..errorDetail = (detail == null || detail.isEmpty) ? null : (detail.length > 240 ? '${detail.substring(0, 240)}…' : detail);
    _finish(chat, turn);
  }

  void _finish(Chat chat, ChatTurn turn) {
    _sawBackground.remove(turn.id);
    _running.remove(turn.id);
    _attempts.remove(turn.id);
    _retryTimers.remove(turn.id)?.cancel();
    progress.remove(turn.id);
    _syncKeepAlive();
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
    WidgetsBinding.instance.removeObserver(this);
    for (final s in _running.values) {
      s.cancel();
    }
    super.dispose();
  }
}
