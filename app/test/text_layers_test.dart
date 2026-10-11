import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/turath/text_layers.dart';

const sharh = '(قَالَ رَسُولُ اللَّهِ) أَيْ: النَّبِيُّ ﷺ (إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ) جَمْعُ نِيَّةٍ، وَهِيَ الْقَصْدُ (١)، '
    'قَالَ تَعَالَى: ﴿وَمَا أُمِرُوا إِلَّا لِيَعْبُدُوا اللَّهَ (مُخْلِصِينَ) لَهُ الدِّينَ﴾ وَ(إِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى) أَيْ جَزَاؤُهُ.';
const quotes = 'قال المصنف: "ويجب الوضوء على من أحدث" أي على كل مكلف، "وفرضه غسل الوجه" وحده من منابت الشعر (٢) إلى الذقن.';

void main() {
  test('verses are found and their inner parentheses are not matn', () {
    final verses = quranRanges(sharh);
    expect(verses, hasLength(1));
    expect(sharh.substring(verses.single.$1, verses.single.$2), startsWith('﴿وَمَا'));
    final matn = markerRanges(sharh, '()', exclude: verses);
    expect([for (final (s, e) in matn) sharh.substring(s, e)], ['(قَالَ رَسُولُ اللَّهِ)', '(إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ)', '(إِنَّمَا لِكُلِّ امْرِئٍ مَا نَوَى)']);
  });

  test('footnote numbers are never matn', () {
    expect(markerRanges('نص (١) ونص (23) و(٣/ ٤٥)', '()'), isEmpty);
  });

  test('the matn marker of a book is detected from its pages', () {
    expect(detectMatnMarkers([sharh, sharh]), ['()']);
    expect(detectMatnMarkers([quotes, quotes]), ['""']);
    expect(detectMatnMarkers(['نص عادي بلا متن مشروح ولا علامات.']), isEmpty);
  });

  test('vowelled braces are taken as verses', () {
    expect(bracesAreVerses(['قال تعالى: {إِنَّا أَنْزَلْنَاهُ فِي لَيْلَةِ الْقَدْرِ} وفيه']), isTrue);
    expect(bracesAreVerses(['{باب الطهارة} وفيه مسائل']), isFalse);
  });
}
