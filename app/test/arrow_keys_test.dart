import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/ui/widgets/visual_arrow_keys.dart';

Future<TextEditingController> _field(WidgetTester tester, String text, {TextDirection? direction, TextDirection ambient = TextDirection.ltr}) async {
  final controller = TextEditingController(text: text);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => VisualArrowKeys(child: child!),
    home: Directionality(textDirection: ambient, child: Scaffold(body: Center(child: SizedBox(width: 600, child: TextField(controller: controller, autofocus: true, textDirection: direction))))),
  ));
  await tester.pumpAndSettle();
  return controller;
}

void main() {
  for (final (ambient, direction) in [(TextDirection.ltr, null), (TextDirection.rtl, TextDirection.rtl), (TextDirection.ltr, TextDirection.rtl)]) {
    testWidgets('← moves the caret left through Arabic text ($ambient, field $direction)', (tester) async {
      final c = await _field(tester, 'بسم الله', direction: direction, ambient: ambient);
      c.selection = const TextSelection.collapsed(offset: 0); // logical start: the right end
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(c.selection.baseOffset, 1, reason: 'left goes forward in Arabic');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(c.selection.baseOffset, 0);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect((c.selection.baseOffset, c.selection.extentOffset), (0, 2));
    });
  }

  testWidgets('Latin text keeps the normal arrows', (tester) async {
    final c = await _field(tester, 'hello');
    c.selection = const TextSelection.collapsed(offset: 2);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(c.selection.baseOffset, 1);
  });
}
