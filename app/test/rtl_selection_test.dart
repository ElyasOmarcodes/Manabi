import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _text = 'حدثنا عبد الله بن يوسف قال أخبرنا مالك عن نافع عن عبد الله بن عمر أن رسول الله صلى الله عليه وسلم قال إنما الأعمال بالنيات وإنما لكل امرئ ما نوى فمن كانت هجرته إلى الله ورسوله فهجرته إلى الله ورسوله';

Future<TextSelection> _dragSelect(WidgetTester tester, {required TextDirection ambient, required TextAlign align, required double dx, bool pageView = false}) async {
  // Spans like the reader's highlights.
  final text = SelectableText.rich(
    TextSpan(style: const TextStyle(fontSize: 20, height: 2), children: [
      TextSpan(text: _text.substring(0, 30)),
      TextSpan(text: _text.substring(30, 60), style: const TextStyle(backgroundColor: Color(0x55F5C451))),
      TextSpan(text: _text.substring(60)),
    ]),
    textDirection: TextDirection.rtl,
    textAlign: align,
  );
  final list = ListView(padding: const EdgeInsets.all(20), children: [text]);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: ambient,
      child: Scaffold(body: pageView ? Directionality(textDirection: TextDirection.rtl, child: PageView(children: [list, const SizedBox()])) : list),
    ),
  ));
  final box = tester.getRect(find.byType(SelectableText));
  // Long-press near the start of the first line (its right edge in RTL), then drag.
  final start = Offset(box.right - 30, box.top + 20);
  final gesture = await tester.startGesture(start);
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesture.up();
  await tester.pumpAndSettle();
  final state = tester.state<EditableTextState>(find.byType(EditableText));
  return state.textEditingValue.selection;
}

void main() {
  for (final host in ['list', 'pageview', 'reverse']) {
    testWidgets('$host: the left handle dragged left extends the end of an RTL selection', (tester) async {
      final (before, after) = await _dragHandle(tester, endHandle: true, dx: -120, host: host);
      expect(after.end, greaterThan(before.end), reason: '$before -> $after');
      expect(after.start, before.start);
    });
    testWidgets('$host: the right handle dragged right extends the start of an RTL selection', (tester) async {
      final (before, after) = await _dragHandle(tester, endHandle: false, dx: 120, host: host);
      expect(after.start, lessThan(before.start), reason: '$before -> $after');
      expect(after.end, before.end);
    });
  }
  for (final ambient in TextDirection.values) {
    for (final (align, pageView) in [(TextAlign.start, false), (TextAlign.justify, false), (TextAlign.justify, true)]) {
      testWidgets('dragging left extends an RTL selection forward ($ambient, $align, pageView: $pageView)', (tester) async {
        final s = await _dragSelect(tester, ambient: ambient, align: align, dx: -260, pageView: pageView);
        expect(s.isCollapsed, isFalse);
        // Moving left in Arabic text goes forward in reading order.
        expect(s.end, greaterThan(12), reason: 'selection $s');
        expect(s.start, lessThan(8), reason: 'selection $s');
      });
    }
  }
}

const _page = SelectableText.rich(TextSpan(text: _text, style: TextStyle(fontSize: 20, height: 2)), textDirection: TextDirection.rtl, textAlign: TextAlign.justify);

/// The reader's containers: a plain list, a right-to-left PageView, and the
/// part of the continuous view that grows upwards (pages before the anchor).
Widget _host(String kind) => switch (kind) {
      'pageview' => PageView(children: [ListView(padding: const EdgeInsets.all(20), children: const [_page])]),
      'reverse' => CustomScrollView(center: const ValueKey('c'), anchor: 0.9, slivers: [
          SliverList(delegate: SliverChildListDelegate(const [Padding(padding: EdgeInsets.all(20), child: _page)])),
          const SliverToBoxAdapter(key: ValueKey('c'), child: SizedBox(height: 300)),
        ]),
      _ => ListView(padding: const EdgeInsets.all(20), children: const [_page]),
    };

Future<(TextSelection, TextSelection)> _dragHandle(WidgetTester tester, {required bool endHandle, required double dx, String host = 'list'}) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: _host(host)),
    ),
  ));
  final box = tester.getRect(find.byType(SelectableText));
  final gesture = await tester.startGesture(Offset(box.center.dx, box.top + 20));
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pumpAndSettle();
  final state = tester.state<EditableTextState>(find.byType(EditableText));
  final before = state.textEditingValue.selection;
  final editable = tester.renderObject<RenderEditable>(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Editable'));
  final points = [for (final p in editable.getEndpointsForSelection(before)) editable.localToGlobal(p.point)];
  expect(points, hasLength(2));
  // In RTL the selection end (later text) is on the left.
  final left = points.reduce((a, b) => a.dx < b.dx ? a : b);
  final right = points.reduce((a, b) => a.dx < b.dx ? b : a);
  final h = (endHandle ? left : right) + const Offset(0, 8);
  final drag = await tester.startGesture(h);
  await tester.pump();
  for (var i = 0; i < 6; i++) {
    await drag.moveBy(Offset(dx / 6, 0));
    await tester.pump();
  }
  await drag.up();
  await tester.pumpAndSettle();
  return (before, state.textEditingValue.selection);
}

