import 'package:flutter/material.dart';

import '../theme.dart';
import 'aura.dart';

/// Minimal Markdown model used by the answer view and by the exporters.
enum BlockKind { paragraph, heading, bullet, numbered, quote }

class MdBlock {
  const MdBlock(this.kind, this.text, {this.level = 0, this.number});
  final BlockKind kind;
  final String text;
  final int level;
  final int? number;
}

List<MdBlock> parseBlocks(String markdown) {
  final blocks = <MdBlock>[];
  final para = <String>[];
  void flush() {
    if (para.isNotEmpty) {
      blocks.add(MdBlock(BlockKind.paragraph, para.join(' ').trim()));
      para.clear();
    }
  }

  for (final raw in markdown.replaceAll('\r\n', '\n').split('\n')) {
    final line = raw.trimRight();
    final trimmed = line.trimLeft();
    if (trimmed.isEmpty) {
      flush();
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    final bullet = RegExp(r'^[-*•]\s+(.*)$').firstMatch(trimmed);
    final numbered = RegExp(r'^(\d+)[.)]\s+(.*)$').firstMatch(trimmed);
    final quote = RegExp(r'^>\s?(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flush();
      blocks.add(MdBlock(BlockKind.heading, heading.group(2)!.trim(), level: heading.group(1)!.length));
    } else if (bullet != null) {
      flush();
      blocks.add(MdBlock(BlockKind.bullet, bullet.group(1)!.trim(), level: (line.length - trimmed.length) ~/ 2));
    } else if (numbered != null) {
      flush();
      blocks.add(MdBlock(BlockKind.numbered, numbered.group(2)!.trim(), number: int.tryParse(numbered.group(1)!)));
    } else if (quote != null) {
      flush();
      blocks.add(MdBlock(BlockKind.quote, quote.group(1)!.trim()));
    } else {
      para.add(trimmed);
    }
  }
  flush();
  return blocks;
}

/// Inline segments: plain, bold, italic, code, citation marker.
enum InlineKind { text, bold, italic, code, cite }

class MdInline {
  const MdInline(this.kind, this.text, {this.cite});
  final InlineKind kind;
  final String text;
  final int? cite;
}

final _inline = RegExp(r'\*\*(.+?)\*\*|__(.+?)__|\*(?!\s)(.+?)\*|`([^`]+)`|\[(\d{1,2})\]');

List<MdInline> parseInline(String text) {
  final out = <MdInline>[];
  var last = 0;
  for (final m in _inline.allMatches(text)) {
    if (m.start > last) out.add(MdInline(InlineKind.text, text.substring(last, m.start)));
    if (m.group(1) != null || m.group(2) != null) {
      out.add(MdInline(InlineKind.bold, m.group(1) ?? m.group(2)!));
    } else if (m.group(3) != null) {
      out.add(MdInline(InlineKind.italic, m.group(3)!));
    } else if (m.group(4) != null) {
      out.add(MdInline(InlineKind.code, m.group(4)!));
    } else {
      out.add(MdInline(InlineKind.cite, m.group(0)!, cite: int.parse(m.group(5)!)));
    }
    last = m.end;
  }
  if (last < text.length) out.add(MdInline(InlineKind.text, text.substring(last)));
  return out;
}

/// Plain text without markdown syntax (citations kept as [n]).
String stripMarkdown(String markdown) => parseBlocks(markdown).map((b) {
      final t = parseInline(b.text).map((i) => i.text).join();
      return switch (b.kind) {
        BlockKind.bullet => '• $t',
        BlockKind.numbered => '${b.number ?? 1}. $t',
        BlockKind.quote => '“$t”',
        _ => t,
      };
    }).join('\n\n');

bool _isArabic(String text) {
  final arabic = RegExp('[\u0600-\u06FF]').allMatches(text).length;
  final latin = RegExp('[A-Za-z]').allMatches(text).length;
  return arabic > latin;
}

class AnswerMarkdown extends StatelessWidget {
  const AnswerMarkdown({super.key, required this.markdown, this.onCite, this.style, this.quoteScale = 1});
  final String markdown;
  final ValueChanged<int>? onCite;
  final TextStyle? style;
  final double quoteScale;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.tt.bodyLarge!;
    final blocks = parseBlocks(markdown);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks)
          Padding(
            padding: EdgeInsets.only(top: b.kind == BlockKind.heading ? 12 : 0, bottom: b.kind == BlockKind.heading ? 4 : 12),
            child: _block(context, b, base),
          ),
      ],
    );
  }

  Widget _block(BuildContext context, MdBlock b, TextStyle base) {
    switch (b.kind) {
      case BlockKind.heading:
        return Text.rich(_spans(context, b.text, base.copyWith(fontWeight: FontWeight.w800, fontSize: base.fontSize! + (b.level <= 2 ? 2.5 : 1), height: 1.6)));
      case BlockKind.bullet:
      case BlockKind.numbered:
        return Padding(
          padding: EdgeInsetsDirectional.only(start: 6.0 + b.level * 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 22,
              child: b.kind == BlockKind.bullet
                  ? Padding(
                      padding: EdgeInsets.only(top: (base.fontSize! * (base.height ?? 1.5)) / 2 - 3),
                      child: Container(width: 6, height: 6, decoration: BoxDecoration(gradient: context.aura.brand, shape: BoxShape.circle)),
                    )
                  : Text('${b.number}.', style: base.copyWith(fontWeight: FontWeight.w600, color: context.aura.accent)),
            ),
            Expanded(child: Text.rich(_spans(context, b.text, base))),
          ]),
        );
      case BlockKind.quote:
        // Verified Arabic source text: right-to-left, classical font, accent rail.
        final arabic = _isArabic(b.text);
        final a = context.aura;
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Directionality(
            textDirection: arabic ? TextDirection.rtl : Directionality.of(context),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 4, color: a.accent.withValues(alpha: 0.75)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 16, 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(Icons.format_quote_rounded, size: 18, color: a.accent.withValues(alpha: 0.6)),
                      Text.rich(_spans(
                        context,
                        b.text,
                        arabic ? arabicStyle(context, size: (base.fontSize ?? 16) + 2.5, scale: quoteScale).copyWith(height: 2.0) : base.copyWith(fontStyle: FontStyle.italic),
                      )),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
      case BlockKind.paragraph:
        return Text.rich(_spans(context, b.text, base));
    }
  }

  TextSpan _spans(BuildContext context, String text, TextStyle base) => TextSpan(
        style: base,
        children: [
          for (final i in parseInline(text))
            switch (i.kind) {
              InlineKind.text => TextSpan(text: i.text),
              InlineKind.bold => TextSpan(text: i.text, style: const TextStyle(fontWeight: FontWeight.w700)),
              InlineKind.italic => TextSpan(text: i.text, style: const TextStyle(fontStyle: FontStyle.italic)),
              InlineKind.code => TextSpan(text: i.text, style: TextStyle(backgroundColor: context.aura.surfaceAlt)),
              InlineKind.cite => WidgetSpan(alignment: PlaceholderAlignment.middle, child: CiteChip(n: i.cite!, onTap: onCite)),
            },
        ],
      );
}

class CiteChip extends StatelessWidget {
  const CiteChip({super.key, required this.n, this.onTap});
  final int n;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Pressable(
        onTap: onTap == null ? null : () => onTap!(n),
        scale: 0.85,
        child: Container(
          constraints: const BoxConstraints(minWidth: 20),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(8)),
          child: Text('$n', textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, fontWeight: FontWeight.w700, color: a.accent, height: 1.6)),
        ),
      ),
    );
  }
}
