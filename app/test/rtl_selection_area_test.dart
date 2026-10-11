import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _text = 'حدثنا عبد الله بن يوسف قال أخبرنا مالك عن نافع عن عبد الله بن عمر أن رسول الله صلى الله عليه وسلم قال إنما الأعمال بالنيات وإنما لكل امرئ ما نوى فمن كانت هجرته إلى الله ورسوله فهجرته إلى الله ورسوله';

void main() {
  for (final ambient in TextDirection.values) {
    testWidgets('SelectionArea: dragging left from the line start selects forward ($ambient)', (tester) async {
      var selected = '';
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: ambient,
          child: Scaffold(
            body: ListView(padding: const EdgeInsets.all(20), children: [
              SelectionArea(
                onSelectionChanged: (c) => selected = c?.plainText ?? '',
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('باب', textDirection: TextDirection.rtl),
                  Text.rich(
                    const TextSpan(style: TextStyle(fontSize: 20, height: 2), children: [
                      TextSpan(text: _text),
                    ]),
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.justify,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ));
      final box = tester.getRect(find.byType(Text).last);
      final gesture = await tester.startGesture(Offset(box.right - 20, box.top + 20));
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveBy(const Offset(-260, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(selected.startsWith('حدثنا'), isTrue, reason: selected);
      expect(selected.length, greaterThan(12), reason: selected);
    });
  }
}
