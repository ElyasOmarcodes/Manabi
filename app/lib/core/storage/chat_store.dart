import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../models/chat.dart';
import 'app_dirs.dart';

/// Persists chats as JSON strings in a Hive box (works on every platform,
/// IndexedDB on the web).
class ChatStore {
  ChatStore._(this._box);

  final Box<String> _box;

  static Future<ChatStore> open({bool init = true}) async {
    if (init) await initAppStorage();
    return ChatStore._(await Hive.openBox<String>('chats'));
  }

  /// For tests.
  static Future<ChatStore> openAt(String path) async {
    Hive.init(path);
    return ChatStore._(await Hive.openBox<String>('chats'));
  }

  List<Chat> loadAll() {
    final chats = <Chat>[];
    for (final raw in _box.values) {
      try {
        chats.add(Chat.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>()));
      } catch (_) {
        // Skip a corrupted record rather than failing to start.
      }
    }
    chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return chats;
  }

  Future<void> save(Chat chat) => _box.put(chat.id, jsonEncode(chat.toJson()));
  Future<void> delete(String id) => _box.delete(id);
  Future<void> clear() => _box.clear();
}
