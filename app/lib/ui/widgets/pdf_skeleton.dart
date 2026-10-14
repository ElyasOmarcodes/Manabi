import 'package:flutter/material.dart';

import '../theme.dart';

/// A page still coming: the outline of a page of text and its number,
/// breathing, on white.
class PdfPageSkeleton extends StatefulWidget {
  const PdfPageSkeleton({super.key, required this.number, required this.color, this.breathe = true});
  final String number;
  final Color color;
  final bool breathe;
  @override
  State<PdfPageSkeleton> createState() => _PdfPageSkeletonState();
}

class _PdfPageSkeletonState extends State<PdfPageSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void initState() {
    super.initState();
    if (widget.breathe) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PdfPageSkeleton old) {
    super.didUpdateWidget(old);
    if (!widget.breathe) _breath.stop();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: Colors.white,
    child: AnimatedBuilder(
      animation: _breath,
      builder: (context, _) => CustomPaint(painter: _SkeletonPainter(widget.color, 0.08 + 0.08 * _breath.value, widget.number), size: Size.infinite),
    ),
  );
}

class _SkeletonPainter extends CustomPainter {
  _SkeletonPainter(this.color, this.alpha, this.number);
  final Color color;
  final double alpha;
  final String number;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final line = Paint()..color = color.withValues(alpha: alpha);
    final gap = h * 0.045;
    final thick = (h * 0.012).clamp(3.0, 14.0);
    for (var i = 0; i < 17; i++) {
      final y = h * 0.1 + i * gap;
      if (y > h * 0.86) break;
      // Lines of a right-to-left page: flush right, a paragraph's last one shorter.
      final len = w * (i % 5 == 4 ? 0.42 : 0.8);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.9 - len, y, len, thick), Radius.circular(thick / 2)), line);
    }
    final tp = TextPainter(
      text: TextSpan(
        text: number,
        style: TextStyle(fontFamily: uiFont, fontSize: (w * 0.06).clamp(12.0, 36.0), fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.45)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(w / 2 - tp.width / 2, h * 0.93 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_SkeletonPainter old) => old.alpha != alpha || old.color != color || old.number != number;
}
