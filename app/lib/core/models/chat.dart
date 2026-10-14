import 'answer.dart';
import 'scope.dart';

enum MessageState { pending, done, failed }

/// One question and its answer.
class ChatTurn {
  ChatTurn({
    required this.id,
    required this.question,
    required this.askedAt,
    required this.language,
    this.scope = SearchScope.all,
    this.result,
    this.state = MessageState.pending,
    this.errorCode,
    this.errorDetail,
    this.favorite = false,
    List<AskActivityEvent>? steps,
  }) : steps = steps ?? [];

  final String id;
  final String question;
  final DateTime askedAt;

  /// Requested answer language: ps, ar, fa, en or auto.
  final String language;
  final SearchScope scope;
  AnswerResult? result;
  MessageState state;
  String? errorCode;

  /// Technical reason behind [errorCode] (status, model, timeout), shown small.
  String? errorDetail;
  bool favorite;

  /// The research steps that led to the answer, shown above it on request.
  List<AskActivityEvent> steps;

  static List<AskActivityEvent> _steps(Object? v) => [
        for (final e in v is List ? v : const [])
          if (e is Map && e['k'] is String) AskActivityEvent(e['k'] as String, (e['d'] as Map?)?.cast<String, dynamic>() ?? const {}, (e['t'] as num?)?.toInt() ?? 0),
      ];

  static List<Map<String, dynamic>> _stepsJson(List<AskActivityEvent> steps) => [
        for (final e in steps.length > 80 ? steps.sublist(steps.length - 80) : steps)
          {'k': e.kind, 'd': _plain(e.data), 't': e.elapsedMs},
      ];

  /// Only what JSON can hold (strings, numbers, lists and maps of them).
  static Map<String, dynamic> _plain(Map<String, dynamic> d) {
    Object? clean(Object? v) => switch (v) {
          String() || num() || bool() || null => v,
          List() => [for (final x in v) clean(x)],
          Map() => {for (final e in v.entries) '${e.key}': clean(e.value)},
          _ => '$v',
        };
    return {for (final e in d.entries) e.key: clean(e.value)};
  }

  factory ChatTurn.fromJson(Map<String, dynamic> j) => ChatTurn(
        id: j['id'] as String,
        question: j['question'] as String,
        askedAt: DateTime.tryParse(j['askedAt'] as String? ?? '') ?? DateTime.now(),
        language: j['language'] as String? ?? 'auto',
        scope: SearchScope.fromJson((j['scope'] as Map?)?.cast<String, dynamic>()),
        result: j['result'] is Map ? AnswerResult.fromJson((j['result'] as Map).cast<String, dynamic>()) : null,
        state: MessageState.values.asNameMap()[j['state']] == MessageState.done
            ? MessageState.done
            : MessageState.failed, // a pending turn from a previous run was interrupted
        errorCode: j['errorCode'] as String? ?? (j['state'] == 'done' ? null : 'INTERRUPTED'),
        errorDetail: j['errorDetail'] as String?,
        favorite: j['favorite'] == true,
        steps: _steps(j['steps']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'askedAt': askedAt.toIso8601String(),
        'language': language,
        'scope': scope.toJson(),
        if (result != null) 'result': result!.toJson(),
        'state': state.name,
        if (errorCode != null) 'errorCode': errorCode,
        if (errorDetail != null) 'errorDetail': errorDetail,
        'favorite': favorite,
        if (steps.isNotEmpty) 'steps': _stepsJson(steps),
      };
}

class Chat {
  Chat({required this.id, required this.title, required this.createdAt, required this.updatedAt, List<ChatTurn>? turns, this.pinned = false})
      : turns = turns ?? [];

  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  bool pinned;
  final List<ChatTurn> turns;

  factory Chat.fromJson(Map<String, dynamic> j) => Chat(
        id: j['id'] as String,
        title: j['title'] as String? ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
        pinned: j['pinned'] == true,
        turns: (j['turns'] as List?)?.whereType<Map>().map((t) => ChatTurn.fromJson(t.cast<String, dynamic>())).toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'pinned': pinned,
        'turns': turns.map((t) => t.toJson()).toList(),
      };
}
