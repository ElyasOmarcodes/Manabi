import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/models/library.dart';

void main() {
  // Turath's file list for صحيح البخاري (ط السلطانية).
  const links = PdfLinks('/bksultanya/', [
    '00_54495.pdf',
    '01_54495p1.pdf|',
    '01_54495p2.pdf|#3|',
    '01_54495.pdf',
    '02_54496.pdf',
  ]);

  test('a numbered volume opens its whole file', () {
    expect(links.url('1'), 'https://files.turath.io/pdf/bksultanya/01_54495.pdf');
    expect(links.url('2'), 'https://files.turath.io/pdf/bksultanya/02_54496.pdf');
  });

  test('a named volume (the introduction) opens the 00 file', () {
    expect(links.url('المقدمة'), 'https://files.turath.io/pdf/bksultanya/00_54495.pdf');
  });

  test('no volume opens the first real volume', () {
    expect(links.url(), 'https://files.turath.io/pdf/bksultanya/01_54495.pdf');
  });
}
