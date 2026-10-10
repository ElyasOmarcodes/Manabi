// PDF export.
//
// The `pdf` package cannot shape several Pashto letters (ښ ګ ڼ ۍ …) and
// does not position Arabic diacritics, so every text block is laid out by
// Flutter's own text engine (HarfBuzz shaping, correct bidi) and embedded
// as a high-resolution image. Links stay clickable via pdf link annotations.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/models/answer.dart';
import '../../core/models/chat.dart';
import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';
import '../widgets/answer_markdown.dart';

const _contentWidth = 483.0; // A4 width (595) minus 2 × 56pt margins
const _scale = 3.0;
const _ink = Color(0xFF1B2724);
const _muted = Color(0xFF5C6B66);
const _emerald = Color(0xFF0F5C52);
const _gold = Color(0xFFB08A3E);

class _Painter {
  _Painter(this.rtl);
  final bool rtl;

  Future<pw.Widget> text(InlineSpan span, {bool? rtlOverride, double indent = 0, TextAlign align = TextAlign.start}) async {
    final width = _contentWidth - indent;
    final painter = TextPainter(
      text: span,
      textDirection: (rtlOverride ?? rtl) ? TextDirection.rtl : TextDirection.ltr,
      textAlign: align,
    )..layout(maxWidth: width);
    final w = width;
    final h = painter.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    painter.paint(canvas, Offset.zero);
    final image = await recorder.endRecording().toImage((w * _scale).ceil(), (h * _scale).ceil());
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
    image.dispose();
    painter.dispose();
    return pw.Padding(
      padding: rtl ? pw.EdgeInsets.only(right: indent) : pw.EdgeInsets.only(left: indent),
      child: pw.Image(pw.MemoryImage(bytes), width: w, height: h),
    );
  }

  Future<List<pw.Widget>> paragraphs(String text, TextStyle style, {bool? rtlOverride, double indent = 0}) async {
    // Long blocks are split so that page breaks can fall between them.
    final out = <pw.Widget>[];
    for (final chunk in _chunks(text)) {
      out.add(await this.text(TextSpan(text: chunk, style: style), rtlOverride: rtlOverride, indent: indent));
    }
    return out;
  }

  static Iterable<String> _chunks(String text, {int max = 700}) sync* {
    var rest = text.trim();
    while (rest.length > max) {
      var cut = rest.lastIndexOf(RegExp(r'[.!؟?،,؛;]\s'), max);
      if (cut < max ~/ 2) cut = rest.lastIndexOf(' ', max);
      if (cut <= 0) cut = max;
      yield rest.substring(0, cut + 1).trim();
      rest = rest.substring(cut + 1).trim();
    }
    if (rest.isNotEmpty) yield rest;
  }
}

TextStyle _ui(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) =>
    TextStyle(fontFamily: uiFont, fontSize: size, height: 1.7, fontWeight: weight, color: color);
TextStyle _arabic(double size, {FontWeight weight = FontWeight.w400, Color color = _ink}) =>
    TextStyle(fontFamily: arabicFont, fontSize: size, height: 1.9, fontWeight: weight, color: color);

InlineSpan _inline(String text, TextStyle base) => TextSpan(style: base, children: [
      for (final i in parseInline(text))
        switch (i.kind) {
          InlineKind.bold => TextSpan(text: i.text, style: const TextStyle(fontWeight: FontWeight.w700)),
          InlineKind.italic => TextSpan(text: i.text, style: const TextStyle(fontStyle: FontStyle.italic)),
          InlineKind.cite => TextSpan(text: ' [${i.cite}] ', style: TextStyle(color: _gold, fontWeight: FontWeight.w700, fontSize: (base.fontSize ?? 11) * 0.85)),
          _ => TextSpan(text: i.text),
        },
    ]);

Future<Uint8List> buildPdf({required String title, required List<ChatTurn> turns, required AppLocalizations l, required String uiLanguage}) async {
  final rtl = isRtlLanguage(uiLanguage);
  final p = _Painter(rtl);
  final body = <pw.Widget>[];
  final date = DateTime.now();

  body.add(await p.text(TextSpan(text: title, style: _ui(19, weight: FontWeight.w700, color: _emerald))));
  body.add(await p.text(TextSpan(text: '${l.appName} · ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}', style: _ui(9, color: _muted))));
  body.add(pw.SizedBox(height: 10));
  body.add(pw.Divider(color: PdfColor.fromInt(0xFFE2DCCD), thickness: 0.8));

  for (final t in turns) {
    final r = t.result;
    final answerRtl = isRtlLanguage(r?.language ?? uiLanguage);
    body.add(pw.SizedBox(height: 10));
    body.add(await p.text(TextSpan(text: l.question, style: _ui(10, weight: FontWeight.w700, color: _gold))));
    body.add(await p.text(TextSpan(text: t.question, style: _ui(13, weight: FontWeight.w600)), rtlOverride: isRtlLanguage(_guessLang(t.question)) ? true : rtl && _guessLang(t.question) != 'en'));
    if (r == null) continue;
    body.add(pw.SizedBox(height: 6));
    body.add(await p.text(TextSpan(text: '${l.answer} — ${r.isDocumented ? l.statusAnswered : l.statusInsufficient}', style: _ui(10, weight: FontWeight.w700, color: _gold)), rtlOverride: answerRtl));
    for (final block in parseBlocks(r.answer)) {
      final base = _ui(11.5);
      final span = switch (block.kind) {
        BlockKind.heading => _inline(block.text, base.copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
        BlockKind.bullet => TextSpan(children: [TextSpan(text: '•  ', style: base.copyWith(color: _gold)), _inline(block.text, base)]),
        BlockKind.numbered => TextSpan(children: [TextSpan(text: '${block.number}.  ', style: base.copyWith(color: _gold)), _inline(block.text, base)]),
        BlockKind.quote => _inline(block.text, base.copyWith(fontStyle: FontStyle.italic)),
        BlockKind.paragraph => _inline(block.text, base),
      };
      body.add(pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: await p.text(span, rtlOverride: answerRtl, indent: block.kind == BlockKind.bullet || block.kind == BlockKind.numbered ? 10 : 0)));
    }
    if (r.opinions.isNotEmpty) {
      body.add(await p.text(TextSpan(text: l.opinions, style: _ui(11, weight: FontWeight.w700, color: _emerald)), rtlOverride: answerRtl));
      for (final o in r.opinions) {
        body.add(await p.text(
            TextSpan(children: [
              TextSpan(text: '${o.holder}: ', style: _ui(11, weight: FontWeight.w700)),
              TextSpan(text: o.view, style: _ui(11)),
              TextSpan(text: ' ${o.sources.map((n) => '[$n]').join()}', style: _ui(10, color: _gold)),
            ]),
            rtlOverride: answerRtl,
            indent: 8));
      }
    }
    if (r.sources.isNotEmpty) {
      body.add(pw.SizedBox(height: 6));
      body.add(await p.text(TextSpan(text: l.sources, style: _ui(11, weight: FontWeight.w700, color: _emerald)), rtlOverride: answerRtl));
      for (final s in r.sources) {
        body.add(await _source(p, s, l));
      }
    }
    body.add(pw.SizedBox(height: 8));
    body.add(pw.Divider(color: PdfColor.fromInt(0xFFE2DCCD), thickness: 0.6));
  }
  body.add(await p.text(TextSpan(text: '${l.generatedBy}. ${l.disclaimer}', style: _ui(8.5, color: _muted))));

  final doc = pw.Document(title: title, author: 'Manabi', creator: 'Manabi');
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 56, vertical: 48),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.center,
      child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFF8A9893))),
    ),
    build: (_) => body,
  ));
  return doc.save();
}

Future<pw.Widget> _source(_Painter p, AnswerSource s, AppLocalizations l) async {
  final loc = [
    if (s.volume != null) '${l.volume} ${s.volume}',
    if (s.printedPage != null) '${l.page} ${s.printedPage}',
    if (s.internalPage != null) '${l.turathPage} ${s.internalPage}',
  ].join('، ');
  final children = <pw.Widget>[
    await p.text(
      TextSpan(children: [
        TextSpan(text: '[${s.n}]  ', style: _ui(11, weight: FontWeight.w700, color: _gold)),
        TextSpan(text: s.bookTitle, style: _arabic(12.5, weight: FontWeight.w700)),
        if (s.authorName != null) TextSpan(text: '  —  ${s.authorName}', style: _arabic(11.5, color: _muted)),
        if (loc.isNotEmpty) TextSpan(text: '  ($loc)', style: _arabic(10.5, color: _muted)),
      ]),
      rtlOverride: true,
    ),
  ];
  for (final q in s.quotes) {
    children.add(pw.Container(
      margin: const pw.EdgeInsets.only(top: 3, bottom: 3),
      padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFFFAF5E8),
        border: pw.Border(right: pw.BorderSide(color: PdfColor.fromInt(0xFFB08A3E), width: 2)),
      ),
      child: await p.text(TextSpan(text: q.text, style: _arabic(12.5)), rtlOverride: true, indent: 16),
    ));
  }
  children.add(pw.UrlLink(
    destination: s.url,
    child: pw.Text(s.url, style: pw.TextStyle(fontSize: 8.5, color: PdfColor.fromInt(0xFF0F5C52), decoration: pw.TextDecoration.underline)),
  ));
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 8),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: children),
  );
}

/// Rough script check for a question's direction.
String _guessLang(String text) {
  final arabicScript = RegExp('[؀-ۿ]').allMatches(text).length;
  final latin = RegExp('[A-Za-z]').allMatches(text).length;
  return arabicScript >= latin ? 'ar' : 'en';
}
