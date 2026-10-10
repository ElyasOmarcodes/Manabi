import 'package:flutter/foundation.dart';

import '../core/models/scope.dart';

enum Section { chat, library, saved, history, settings }

/// Shell navigation plus the composer's current search scope, so that
/// "Ask within this book" from the library can prefill the chat.
class NavController extends ChangeNotifier {
  Section section = Section.chat;
  SearchScope scope = SearchScope.all;
  String? draft;

  void go(Section s) {
    if (section == s) return;
    section = s;
    notifyListeners();
  }

  void setScope(SearchScope s) {
    scope = s;
    notifyListeners();
  }

  /// Opens a new chat restricted to [s].
  void askWithin(SearchScope s) {
    scope = s;
    section = Section.chat;
    notifyListeners();
  }

  void prefill(String text) {
    draft = text;
    section = Section.chat;
    notifyListeners();
  }

  String? takeDraft() {
    final d = draft;
    draft = null;
    return d;
  }
}
