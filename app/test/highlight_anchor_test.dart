import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/state/highlight_anchor.dart';
import 'package:manabi/state/reading_controller.dart';

Highlight h(String text, {String? part, int? start, String? note, int color = 0}) =>
    Highlight(bookId: '1', bookTitle: 'b', page: 5, text: text, color: color, note: note, savedAt: DateTime(2026), part: part, start: start);

void main() {
  // The matn on top and the commentary repeating its words.
  const body = '(إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ) ــ قوله: (إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ) أي: صحتها بالنية، والأعمال بالنيات عند الجمهور.';
  final spaces = {'title': 'الحديث الأول', 'body': body};

  test('a mark made in the commentary stays there, not on the same words in the matn', () {
    final second = body.indexOf('(إِنَّمَا', 5);
    final a = anchorFor(body, second + 1, second + 1 + 'إِنَّمَا الْأَعْمَالُ'.length)!;
    final placed = placeHighlights(spaces, [h(a.text, part: 'body', start: a.start)]);
    expect(placed, hasLength(1));
    expect(placed.single.start, second + 1);
  });

  test('the first occurrence is marked when the first one was chosen', () {
    final a = anchorFor(body, 1, 1 + 'إِنَّمَا'.length)!;
    expect(placeHighlights(spaces, [h(a.text, part: 'body', start: a.start)]).single.start, 1);
  });

  test('marks keep their place when diacritics are hidden', () {
    final second = body.indexOf('(إِنَّمَا', 5);
    final a = anchorFor(body, second + 1, second + 1 + 'إِنَّمَا'.length)!;
    final plain = stripDiacritics(body);
    final placed = placeHighlights({'body': plain}, [h(a.text, part: 'body', start: a.start)]);
    expect(placed.single.start, plain.indexOf('(إنما', 5) + 1);
  });

  test('a phrase that is not on the page marks nothing (no word-by-word fallback)', () {
    expect(placeHighlights(spaces, [h('الأعمال عند غيرهم', part: 'body', start: 0)]), isEmpty);
    expect(placeHighlights(spaces, [h('الأعمال عند غيرهم')]), isEmpty);
  });

  test('an older mark (no place) is put at its first occurrence only', () {
    final placed = placeHighlights(spaces, [h('بالنيات')]);
    expect(placed, hasLength(1));
    expect(placed.single.space, 'body');
  });

  test('only the marks the selection touches are found for removal', () {
    final first = anchorFor(body, 1, 9)!;
    final second = body.indexOf('(إِنَّمَا', 5);
    final secondA = anchorFor(body, second + 1, second + 9)!;
    final m1 = h(first.text, part: 'body', start: first.start, color: 1);
    final m2 = h(secondA.text, part: 'body', start: secondA.start, color: 2);
    final placed = placeHighlights(spaces, [m1, m2]);
    final under = highlightsUnder(placed, [(space: 'body', start: second + 2, end: second + 4, text: '')]);
    expect(under, [m2]);
    expect(highlightsUnder(placed, [(space: 'title', start: 0, end: 4, text: '')]), isEmpty);
  });

  test('two marks with the same words at different places are different marks', () {
    expect(h('بالنيات', part: 'body', start: 3).sameAs(h('بالنيات', part: 'body', start: 40)), isFalse);
    expect(h('بالنيات', part: 'body', start: 3).sameAs(h('بالنيات', part: 'body', start: 3)), isTrue);
  });

  test('a selection is trimmed of spaces; spaces alone make no mark', () {
    final a = anchorFor('  قال الطيبي  ', 0, 14)!;
    expect(a.text, 'قال الطيبي');
    expect(a.start, 2);
    expect(anchorFor('   ', 0, 3), isNull);
  });

  test('offsets without diacritics go both ways', () {
    const s = 'إِنَّمَا';
    expect(toCanonical(s, s.length), 'إنما'.length);
    expect(fromCanonical(s, 2), s.indexOf('م'));
  });
}
