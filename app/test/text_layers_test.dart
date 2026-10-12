import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/turath/text_layers.dart';

import 'fixtures/commentary_pages.dart';

const sharh = '(قَالَ رَسُولُ اللَّهِ) أَيْ: النَّبِيُّ ﷺ (إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ) جَمْعُ نِيَّةٍ، وَهِيَ الْقَصْدُ (١)، '
    'قَالَ تَعَالَى: ﴿وَمَا أُمِرُوا إِلَّا لِيَعْبُدُوا اللَّهَ (مُخْلِصِينَ) لَهُ الدِّينَ﴾ وَ(إِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى) أَيْ جَزَاؤُهُ.';
const quotes = 'قال المصنف: "ويجب الوضوء على من أحدث" أي على كل مكلف، "وفرضه غسل الوجه" وحده من منابت الشعر (٢) إلى الذقن.';

List<String> pieces(String text, List<(int, int)> ranges) => [for (final (s, e) in ranges) text.substring(s, e)];

void main() {
  test('verses are found and their inner parentheses are not matn', () {
    final verses = quranRanges(sharh);
    expect(verses, hasLength(1));
    expect(sharh.substring(verses.single.$1, verses.single.$2), startsWith('﴿وَمَا'));
    final matn = markerRanges(sharh, '()', exclude: verses);
    expect(pieces(sharh, matn), ['(قَالَ رَسُولُ اللَّهِ)', '(إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ)', '(إِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى)']);
  });

  test('footnote numbers are never matn', () {
    expect(markerRanges('نص (١) ونص (23) و(٣/ ٤٥) و(^١)', '()'), isEmpty);
  });

  test('a parenthesis that never closes does not swallow the page', () {
    // مرقاة: "(«أَنَّ رَسُولَ اللَّهِ …»" is never closed.
    final found = pieces(mirqat3722, markerRanges(mirqat3722, '()'));
    expect(found, containsAll(['(وَلَا أَدْحَرُ)', '(وَلَا أَحْقَرُ)', '(وَلَا أَغْيَظُ)', '(وَمَا ذَاكَ)', '(مِنْ تَنَزُّلِ الرَّحْمَةِ)']));
    expect(found.every((f) => f.length < 120), isTrue);
  });

  test('the matn block on top of the page', () {
    final b = matnBlock(mirqat3722)!;
    expect(mirqat3722.substring(0, b.blockEnd), endsWith('" الْمَصَابِيحِ ".'));
    expect(mirqat3722.substring(b.sharhStart), startsWith('٢٦٠٠ - (وَعَنْ'));
    expect(matnBlock(plainBook), isNull);
  });

  test('مرقاة المفاتيح: block, (…) always, "…" only when quoted from the matn', () {
    final rules = detectMatnRules([mirqat3721, mirqat3722, mirqatContinued]);
    expect(rules.block, isTrue);
    expect(rules.always, contains('()'));
    expect(rules.always, isNot(contains('""')));

    final text = mirqat3722;
    final found = pieces(text, matnRanges(text, rules, verses: quranRanges(text)));
    expect(found.first, startsWith('٢٦٠٠ - وَعَنْ طَلْحَةَ'));
    expect(found, containsAll(['(وَعَنْ طَلْحَةَ بْنِ عُبَيْدِ اللَّهِ)', '(ابْنِ كَرِيزٍ)', '(وَلَا أَدْحَرُ)']));
    // Book titles in quotes are commentary.
    expect(found.any((f) => f.contains('الْمُغْنِي') || f.contains('الْمَشَارِقِ')), isFalse);
    // A matn phrase in quotes is matn when "" is verified.
    final verified = MatnRules(block: true, always: const ['()'], verified: const ['""']);
    final withQuotes = pieces(text, matnRanges(text, verified, verses: quranRanges(text)));
    expect(withQuotes.any((f) => f.contains('هُوَ فِيهِ أَصْغَرُ')), isTrue);
    expect(withQuotes.any((f) => f.contains('الْمُغْنِي')), isFalse);
  });

  test('a page continuing the commentary uses the earlier matn block', () {
    final rules = MatnRules(block: true, always: const ['()'], verified: const ['""']);
    final text = mirqatContinued;
    final found = pieces(text, matnRanges(text, rules, context: [mirqat3722.substring(0, matnBlock(mirqat3722)!.blockEnd)], verses: quranRanges(text)));
    expect(found, containsAll(['(وَتَجَاوُزِ اللَّهِ عَنِ الذُّنُوبِ الْعِظَامِ)', '(قَدْ رَأَى جِبْرِيلَ)', '" فَإِنَّهُ "']));
    expect(found.any((f) => f.contains('يُوزَعُونَ')), isFalse);
  });

  test('مراقي الفلاح: block and "…" always', () {
    final rules = detectMatnRules([maraqi114, maraqi114]);
    expect(rules.block, isTrue);
    expect(rules.always, ['""']);
    final found = pieces(maraqi114, matnRanges(maraqi114, rules));
    expect(found, containsAll(['"القيام بعده"', '"مطمئنا"', '"و"', '"بطنه عن فخذيه"']));
  });

  test('a plain book has no matn', () {
    expect(detectMatnRules([plainBook, plainBook]).isEmpty, isTrue);
  });

  test('the old detection still finds simple commentaries', () {
    expect(detectMatnMarkers([sharh, sharh]), ['()']);
    expect(detectMatnMarkers([quotes, quotes]), ['""']);
  });

  test('vowelled braces are taken as verses', () {
    expect(bracesAreVerses(['قال تعالى: {إِنَّا أَنْزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ} وفيه']), isTrue);
    expect(bracesAreVerses(['{باب الطهارة} وفيه مسائل']), isFalse);
  });

  test('AI stretches are found by their first and last words, without diacritics', () {
    final spans = locateSpans(mirqat3722, [('وعن طلحة بن عبيد', 'بلفظ المصابيح'), ('ولا ادحر', 'ولا ادحر'), ('ولا احقر', 'احقر')]);
    final found = pieces(mirqat3722, spans);
    expect(found.first, startsWith('وَعَنْ طَلْحَةَ'));
    expect(found.first, endsWith('الْمَصَابِيحِ'));
    expect(found, contains('(وَلَا أَدْحَرُ)'));
    expect(found, contains('(وَلَا أَحْقَرُ)'));
  });

  test('rules are learned from an AI annotation', () {
    final pages = [mirqat3721, mirqat3722];
    // What an annotator marks: the block, and the lemmas in parentheses.
    final truth = [
      for (final t in pages) [(0, matnBlock(t)!.blockEnd), ...markerRanges(t, '()', exclude: [(0, matnBlock(t)!.sharhStart), ...quranRanges(t)])],
    ];
    final (rules, agreement) = learnMatnRules(pages, truth);
    expect(rules.block, isTrue);
    expect(rules.always, contains('()'));
    expect(agreement, greaterThan(0.95));
  });

  test('rules learned from the real Gemini marking of مرقاة and مراقي الفلاح', () {
    // Stretches as Gemini returned them (CI live run).
    final mirqat = [
      ('وَعَنْ طَلْحَةَ', 'فَقِيلَ مَا رُئِيَ يَوْمَ بَدْرٍ قَالَ'),
      ('أَنَّ رَسُولَ اللَّهِ', 'مَا رُئِيَ الشَّيْطَانُ يَوْمًا'),
      ('وَلَا أَدْحَرُ', 'وَلَا أَدْحَرُ'),
      ('وَلَا أَحْقَرُ', 'وَلَا أَحْقَرُ'),
      ('وَلَا أَغْيَظُ', 'وَلَا أَغْيَظُ'),
      ('مِنْهُ فِي يَوْمِ عَرَفَةَ', 'مِنْهُ فِي يَوْمِ عَرَفَةَ'),
      ('وَمَا ذَاكَ', 'وَمَا ذَاكَ'),
      ('إِلَّا لِمَا يَرَى', 'إِلَّا لِمَا يَرَى'),
      ('مِنْ تَنَزُّلِ الرَّحْمَةِ', 'مِنْ تَنَزُّلِ الرَّحْمَةِ'),
    ];
    final first = [('وَرَوَى مَالِكٌ', 'لَا شَرِيكَ لَهُ')];
    final pages = [mirqat3721, mirqat3722];
    final (rules, agreement) = learnMatnRules(pages, [aiTruth(mirqat3721, first), aiTruth(mirqat3722, mirqat)]);
    expect(rules.block, isTrue);
    expect([...rules.always, ...rules.verified], contains('()'));
    expect(rules.always, isNot(contains('""')));
    expect(agreement, greaterThan(0.8));

    // Gemini left the top block of مراقي الفلاح unmarked; it still counts.
    final maraqi = [('القيام بعده', 'القيام بعده'), ('وضع ركبتيه', 'ثم وجهه'), ('للسجود', 'للسجود'), ('تكبير السجود', 'تكبير السجود'), ('تكبير الرفع', 'تكبير الرفع'), ('كون السجود', 'كون السجود'), ('بين كفيه', 'بين كفيه'), ('تسبيحه', 'تسبيحه'), ('ثلاثا', 'ثلاثا'), ('مجافاة الرجل', 'مجافاة الرجل'), ('بطنه عن فخذيه', 'بطنه عن فخذيه')];
    final (r2, a2) = learnMatnRules([maraqi114], [aiTruth(maraqi114, maraqi)]);
    expect(r2.block, isTrue);
    expect([...r2.always, ...r2.verified], contains('""'));
    expect(a2, greaterThan(0.8));
  });

  test('quotes inside parentheses (" لَا تَزَالُ ") do not turn the commentary into matn', () {
    final rules = detectMatnRules([mirqat6285, mirqat3722, mirqat3721]);
    final t = mirqat6285;
    final found = pieces(t, matnRanges(t, rules, verses: quranRanges(t)));
    expect(found, containsAll(['(" مِنْ أُمَّتِي ")', '(" قَائِمَةٌ بِأَمْرِ اللَّهِ ")', '(" مَنْ خَذَلَهُمْ ")']));
    for (final f in found.skip(1)) {
      expect(f.contains('أَيْ:'), isFalse, reason: 'commentary marked as matn: $f');
    }
    // The AI's stretches, found on the whole page: the block stays in the
    // block, and a stretch matching the commentary's own words is dropped.
    final ai = aiMatnRanges(t, [('وَعَنْ مُعَاوِيَةَ', 'كِتَابِ الْقِصَاصِ'), ('لَا تَزَالُ', 'لَا تَزَالُ'), ('مِنْ أُمَّتِي', 'وَهُمْ عَلَى ذَلِكَ')]);
    final b = matnBlock(t)!;
    expect(ai.first.$2, lessThanOrEqualTo(b.blockEnd));
    expect(ai.first.$2 - ai.first.$1, greaterThan(b.blockEnd * 0.9));
    for (final (s, e) in ai.skip(1)) {
      expect(e - s, lessThan(200));
    }
  });
}
