import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/turath/arabic_match.dart';

void main() {
  test('matching ignores diacritics and letter variants', () {
    const text = 'قَالَ: إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ، وَالصَّلَاةُ عِمَادُ الدِّينِ';
    final m = arabicMatches(text, 'انما الاعمال بالنيات');
    expect(m, hasLength(1));
    expect(text.substring(m.single.$1, m.single.$2), 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ');
    expect(arabicMatches(text, 'الصلاه'), hasLength(1));
    expect(arabicMatches(text, 'الصلاة الدين'), hasLength(2), reason: 'words are marked when the phrase is not found');
    expect(arabicMatches(text, ''), isEmpty);
  });
}
