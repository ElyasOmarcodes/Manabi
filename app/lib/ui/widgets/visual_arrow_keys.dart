import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final _rtlChar = RegExp('[֐-ࣿיִ-﷿ﹰ-﻿]');

/// Left and right arrows move the caret the way it looks on screen.
///
/// Flutter maps ← to "one character back" whatever the script, so in Arabic,
/// Persian or Pashto text the caret goes the opposite way to the arrow. For
/// text fields that contain right-to-left text this moves it visually
/// instead (Shift extends the selection); other fields keep the default.
class VisualArrowKeys extends StatelessWidget {
  const VisualArrowKeys({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _VisualMoveIntent(left: true, extend: false),
          SingleActivator(LogicalKeyboardKey.arrowRight): _VisualMoveIntent(left: false, extend: false),
          SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): _VisualMoveIntent(left: true, extend: true),
          SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): _VisualMoveIntent(left: false, extend: true),
        },
        child: Actions(actions: {_VisualMoveIntent: _VisualMoveAction()}, child: child),
      );
}

class _VisualMoveIntent extends Intent {
  const _VisualMoveIntent({required this.left, required this.extend});
  final bool left;
  final bool extend;
}

class _VisualMoveAction extends Action<_VisualMoveIntent> {
  EditableTextState? get _editable {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return null;
    if (context is StatefulElement && context.state is EditableTextState) return context.state as EditableTextState;
    return context.findAncestorStateOfType<EditableTextState>();
  }

  @override
  bool isEnabled(_VisualMoveIntent intent) {
    final e = _editable;
    // Only fields with right-to-left text need it; when disabled the key
    // goes on to Flutter's default handling.
    return e != null && e.mounted && _rtlChar.hasMatch(e.textEditingValue.text);
  }

  @override
  Object? invoke(_VisualMoveIntent intent) {
    final e = _editable;
    if (e == null) return null;
    final value = e.textEditingValue;
    final text = value.text;
    final sel = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: text.length);
    // Without Shift a selection collapses to its visually left/right end.
    final from = !intent.extend && !sel.isCollapsed ? null : sel.extentOffset;
    final render = e.renderEditable;
    double x(int offset) => render.getLocalRectForCaret(TextPosition(offset: offset)).center.dx;
    double y(int offset) => render.getLocalRectForCaret(TextPosition(offset: offset)).center.dy;
    int target;
    if (from == null) {
      final a = sel.start, b = sel.end;
      target = (x(a) < x(b)) == intent.left ? a : b;
    } else {
      final prev = _step(text, from, -1);
      final next = _step(text, from, 1);
      final here = x(from), row = y(from);
      int? pick;
      for (final c in [prev, next]) {
        if (c == from) continue;
        final dx = x(c) - here;
        if ((y(c) - row).abs() < 2 && (intent.left ? dx < -0.5 : dx > 0.5)) pick = c;
      }
      // At a line edge: in right-to-left text ← goes forward, → back.
      target = pick ?? (intent.left == _rtlChar.hasMatch(_around(text, from)) ? next : prev);
    }
    final selection = intent.extend ? TextSelection(baseOffset: sel.baseOffset, extentOffset: target) : TextSelection.collapsed(offset: target);
    e.userUpdateTextEditingValue(value.copyWith(selection: selection), SelectionChangedCause.keyboard);
    e.bringIntoView(TextPosition(offset: target));
    return null;
  }

  /// The offset one user-perceived character (with its marks) away.
  static int _step(String text, int offset, int dir) {
    if (dir < 0) {
      if (offset <= 0) return 0;
      final before = text.substring(0, offset).characters;
      return offset - before.last.length;
    }
    if (offset >= text.length) return text.length;
    return offset + text.substring(offset).characters.first.length;
  }

  static String _around(String text, int offset) => text.substring((offset - 2).clamp(0, text.length), (offset + 2).clamp(0, text.length));
}
