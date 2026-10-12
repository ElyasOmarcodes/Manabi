import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/turath/arabic_match.dart';

/// Rich text that, once laid out, scrolls its scrollable so the first match
/// of [reveal] sits near the top of the view: a search hit or a heading
/// opened from the contents lands on the line itself, not on the top of
/// its page.
class RevealText extends StatefulWidget {
  const RevealText(this.span, {super.key, this.reveal, this.textDirection, this.textAlign});
  final TextSpan span;
  final String? reveal;
  final TextDirection? textDirection;
  final TextAlign? textAlign;

  @override
  State<RevealText> createState() => _RevealTextState();
}

class _RevealTextState extends State<RevealText> {
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(RevealText old) {
    super.didUpdateWidget(old);
    if (widget.reveal != old.reveal) _schedule();
  }

  void _schedule() {
    final q = widget.reveal;
    if (q == null || q.trim().isEmpty) return;
    // Twice: once laid out, and again after neighbouring pages settle.
    WidgetsBinding.instance.addPostFrameCallback((_) => _go(q, animate: false));
    Future<void>.delayed(const Duration(milliseconds: 450), () => _go(q, animate: true));
  }

  void _go(String q, {required bool animate}) {
    if (!mounted) return;
    final text = widget.span.toPlainText();
    final hits = arabicMatches(text, q);
    if (hits.isEmpty) return;
    RenderParagraph? paragraph;
    void find(RenderObject o) {
      if (paragraph != null) return;
      if (o is RenderParagraph) {
        paragraph = o;
        return;
      }
      o.visitChildren(find);
    }

    final root = context.findRenderObject();
    if (root == null) return;
    find(root);
    final p = paragraph;
    if (p == null || !p.hasSize) return;
    final (s, e) = hits.first;
    final boxes = p.getBoxesForSelection(TextSelection(baseOffset: s, extentOffset: e));
    if (boxes.isEmpty) return;
    final rect = boxes.first.toRect();
    final viewport = RenderAbstractViewport.maybeOf(p);
    final position = Scrollable.maybeOf(context)?.position;
    if (viewport == null || position == null) return;
    final target = viewport.getOffsetToReveal(p, 0.18, rect: rect).offset.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - position.pixels).abs() < 4) return;
    if (animate) {
      position.animateTo(target, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic);
    } else {
      position.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) => Text.rich(widget.span, textDirection: widget.textDirection, textAlign: widget.textAlign);
}
