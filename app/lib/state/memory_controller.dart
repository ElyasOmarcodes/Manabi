import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One thing the assistant keeps about the user: a wish about answers or a
/// fact that shapes them ("answer briefly", "follows the Hanafi school").
class MemoryItem {
  const MemoryItem(this.text, this.at);
  final String text;
  final DateTime at;
  Map<String, dynamic> toJson() => {'text': text, 'at': at.toIso8601String()};
  static MemoryItem? fromJson(Object? j) {
    if (j is! Map || j['text'] is! String) return null;
    return MemoryItem(j['text'] as String, DateTime.tryParse('${j['at']}') ?? DateTime.now());
  }
}

/// What the assistant remembers, kept on this device only, shown and
/// editable in the settings; sent with every question while it is on.
class MemoryController extends ChangeNotifier {
  MemoryController._(this._prefs, this.items, this.enabled);

  static const _key = 'memory.items';
  static const _onKey = 'memory.enabled';
  static const limit = 30;

  final SharedPreferences? _prefs;
  final List<MemoryItem> items;
  bool enabled;

  static Future<MemoryController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final items = <MemoryItem>[];
    try {
      for (final j in jsonDecode(prefs.getString(_key) ?? '[]') as List) {
        final item = MemoryItem.fromJson(j);
        if (item != null) items.add(item);
      }
    } catch (_) {}
    return MemoryController._(prefs, items, prefs.getBool(_onKey) ?? true);
  }

  /// For tests: nothing is saved.
  factory MemoryController.inMemory([List<String> texts = const []]) => MemoryController._(null, [for (final t in texts) MemoryItem(t, DateTime.now())], true);

  /// What goes with a question.
  List<String> get forPrompt => enabled ? [for (final i in items) i.text] : const [];

  /// Keeps [text] unless the same thing is already remembered; the oldest
  /// item leaves when the list is full.
  void add(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    final norm = t.toLowerCase().replaceAll(RegExp(r'[\s.!،,]+'), ' ').trim();
    if (items.any((i) => i.text.toLowerCase().replaceAll(RegExp(r'[\s.!،,]+'), ' ').trim() == norm)) return;
    items.insert(0, MemoryItem(t.length > 240 ? t.substring(0, 240) : t, DateTime.now()));
    if (items.length > limit) items.removeRange(limit, items.length);
    _save();
  }

  void update(int index, String text) {
    final t = text.trim();
    if (index < 0 || index >= items.length) return;
    if (t.isEmpty) return remove(index);
    items[index] = MemoryItem(t, items[index].at);
    _save();
  }

  void remove(int index) {
    if (index < 0 || index >= items.length) return;
    items.removeAt(index);
    _save();
  }

  void clear() {
    items.clear();
    _save();
  }

  void setEnabled(bool v) {
    enabled = v;
    _prefs?.setBool(_onKey, v);
    notifyListeners();
  }

  void _save() {
    _prefs?.setString(_key, jsonEncode([for (final i in items) i.toJson()]));
    notifyListeners();
  }
}
