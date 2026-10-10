import 'package:flutter/material.dart';

import '../theme.dart';
import 'brand_paths.dart';

/// The «المنابع» calligraphy logo, drawn from vector paths so it stays sharp
/// at any size and takes the theme's colours (no background).
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.height = 40, this.latin = true, this.color, this.latinColor});

  /// Height of the drawing; the width follows the logo's proportions.
  final double height;

  /// Shows the "ALMANABEA" line under the calligraphy.
  final bool latin;
  final Color? color;
  final Color? latinColor;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final box = latin ? brandViewBox : brandMarkViewBox;
    return Semantics(
      label: 'المنابع',
      image: true,
      child: SizedBox(
        height: height,
        width: height * box.width / box.height,
        child: CustomPaint(painter: _LogoPainter(box: box, ink: color ?? a.text, latin: latin ? (latinColor ?? a.muted) : null)),
      ),
    );
  }
}

final _ink = parseSvgPath(brandInkPath);
final _latin = parseSvgPath(brandLatinPath);

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.box, required this.ink, required this.latin});
  final Rect box;
  final Color ink;
  final Color? latin;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / box.height;
    canvas
      ..save()
      ..scale(scale)
      ..translate(-box.left, -box.top);
    canvas.drawPath(_ink, Paint()..color = ink..isAntiAlias = true);
    if (latin != null) canvas.drawPath(_latin, Paint()..color = latin!..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.ink != ink || old.latin != latin || old.box != box;
}

/// Parses the absolute M/L/C/Z path data written by tool/brand/trace.py.
Path parseSvgPath(String d) {
  final path = Path()..fillType = PathFillType.evenOdd;
  final tokens = RegExp(r'[MLCZ]|-?\d+(?:\.\d+)?').allMatches(d).map((m) => m[0]!).toList();
  var i = 0;
  double next() => double.parse(tokens[i++]);
  String command = 'M';
  while (i < tokens.length) {
    final t = tokens[i];
    if (RegExp('[MLCZ]').hasMatch(t)) {
      command = t;
      i++;
      if (command == 'Z') {
        path.close();
        continue;
      }
    }
    switch (command) {
      case 'M':
        path.moveTo(next(), next());
        command = 'L';
      case 'L':
        path.lineTo(next(), next());
      case 'C':
        path.cubicTo(next(), next(), next(), next(), next(), next());
      default:
        i++;
    }
  }
  return path;
}
