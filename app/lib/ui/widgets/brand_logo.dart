import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

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

/// The المنابع logo drawing itself in (Lottie, built from the same paths by
/// tool/brand/lottie.py): stroked in the brand violet, then filled in the
/// theme's ink colour, with the Latin name rising in underneath.
class AnimatedBrandLogo extends StatefulWidget {
  const AnimatedBrandLogo({super.key, this.height = 112, this.delay = Duration.zero, this.onDone});
  final double height;
  final Duration delay;
  final VoidCallback? onDone;
  @override
  State<AnimatedBrandLogo> createState() => _AnimatedBrandLogoState();
}

class _AnimatedBrandLogoState extends State<AnimatedBrandLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this)..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone?.call();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return SizedBox(
      height: widget.height,
      child: AspectRatio(
        aspectRatio: brandViewBox.width / brandViewBox.height,
        child: Lottie.asset(
          'assets/brand/almanabea_lottie.json',
          controller: _c,
          fit: BoxFit.contain,
          // Without the animation (tests, missing asset) the still logo shows.
          errorBuilder: (context, error, stack) => BrandLogo(height: widget.height),
          delegates: LottieDelegates(values: [
            ValueDelegate.strokeColor(const ['ink', '**'], value: a.accent),
            ValueDelegate.color(const ['ink', '**'], value: a.text),
            ValueDelegate.strokeColor(const ['latin', '**'], value: a.muted),
            ValueDelegate.color(const ['latin', '**'], value: a.muted),
          ]),
          onLoaded: (composition) {
            _c.duration = composition.duration;
            Future<void>.delayed(widget.delay, () {
              if (mounted) _c.forward();
            });
          },
        ),
      ),
    );
  }
}
