import 'package:flutter_test/flutter_test.dart';
import 'package:manabi/core/models/library.dart';
import 'package:manabi/ui/widgets/pdf_pane.dart';

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

  // روح المعاني: the volume number is at the end and 00 is the introduction.
  const tail = PdfLinks('shamela', ['roohm_00.pdf', 'roohm_01.pdf', 'roohm_04.pdf', 'roohm_15.pdf']);

  test('a volume number at the end of the name picks that volume, not the cover', () {
    expect(tail.url('4'), 'https://files.turath.io/pdf/shamela/roohm_04.pdf');
    expect(tail.url('15'), 'https://files.turath.io/pdf/shamela/roohm_15.pdf');
    expect(tail.url(), 'https://files.turath.io/pdf/shamela/roohm_01.pdf');
  });

  test('the web reads PDF ranges through the server; apps read Turath directly', () {
    const turath = 'https://files.turath.io/pdf/shamela/roohm_04.pdf';
    expect(pdfViewUrl(turath, web: false, serverUrl: 'https://m.example'), turath);
    expect(pdfViewUrl(turath, web: true, serverUrl: 'https://m.example/'), 'https://m.example/api/pdf/shamela/roohm_04.pdf');
    expect(pdfViewUrl(turath, web: true), turath);
  });
}
