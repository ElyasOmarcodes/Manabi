import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/models/book_info.dart';

void main() {
  test('the book card splits into fields and notes', () {
    final r = splitBookInfo('الكتاب: الأربعون النووية\nالمؤلف: محيي الدين النووي (٦٣١ - ٦٧٦ هـ)\nالناشر: دار المنهاج\nبيروت - لبنان\n'
        'الطبعة: الأولى، ١٤٣٠ هـ<br>عدد الأجزاء: ٢\n[الكتاب مرقم آليا، وهو غير مطبوع]');
    expect(r.fields.map((f) => f.$1), ['الكتاب', 'المؤلف', 'الناشر', 'الطبعة', 'عدد الأجزاء']);
    expect(r.fields[2].$2, 'دار المنهاج بيروت - لبنان');
    expect(r.notes, ['[الكتاب مرقم آليا، وهو غير مطبوع]']);
  });

  test('light HTML becomes text', () {
    expect(plainText('<p>أ &amp; ب</p><p>ج</p>'), 'أ & ب\nج');
  });
}
