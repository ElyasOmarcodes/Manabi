import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';

/// Brand splash: the المنابع calligraphy draws itself in (Lottie) inside a
/// slowly turning halo of the brand colours, then the tagline and the
/// sources it rests on fade in.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.tagline});
  final String? tagline;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final halo = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.45, curve: Curves.easeOutCubic));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic));
    final foot = CurvedAnimation(parent: _intro, curve: const Interval(0.7, 1, curve: Curves.easeOut));
    final size = MediaQuery.sizeOf(context);
    final logoHeight = (size.shortestSide * 0.3).clamp(88.0, 132.0);
    return Scaffold(
      backgroundColor: a.bg,
      body: Stack(children: [
        // Halo: two soft brand-coloured lights circling behind the logo.
        Positioned.fill(
          child: FadeTransition(
            opacity: halo,
            child: AnimatedBuilder(
              animation: _loop,
              builder: (context, _) {
                final t = _loop.value * 2 * math.pi;
                return CustomPaint(painter: _HaloPainter(t: t, dark: a.dark, bg: a.bg));
              },
            ),
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedBrandLogo(height: logoHeight, delay: const Duration(milliseconds: 200)),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: text,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(text),
                child: widget.tagline == null
                    ? const SizedBox()
                    : Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(widget.tagline!, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.7, color: a.muted)),
                      ),
              ),
            ),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 28,
          child: FadeTransition(
            opacity: foot,
            child: Column(children: [
              _Dots(animation: _loop, color: a.accent),
              const SizedBox(height: 14),
              Text('turath.io  ·  Nusus  ·  Gemini', textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, letterSpacing: 1.1, color: a.faint)),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _HaloPainter extends CustomPainter {
  _HaloPainter({required this.t, required this.dark, required this.bg});
  final double t;
  final bool dark;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.46);
    final r = size.shortestSide * 0.55;
    void light(Color color, double angle, double alpha) {
      final p = c + Offset(math.cos(angle), math.sin(angle)) * r * 0.22;
      canvas.drawCircle(
        p,
        r,
        Paint()..shader = RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: p, radius: r)),
      );
    }

    light(AuraHues.violet, t, dark ? 0.22 : 0.13);
    light(AuraHues.amber, t + math.pi, dark ? 0.10 : 0.07);
  }

  @override
  bool shouldRepaint(_HaloPainter old) => old.t != t || old.dark != dark;
}

/// Three dots that rise in turn while the app loads.
class _Dots extends StatelessWidget {
  const _Dots({required this.animation, required this.color});
  final Animation<double> animation;
  final Color color;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Builder(builder: (context) {
              final phase = (animation.value * 9 / 1.2 - i * 0.18) % 1.0;
              final lift = math.sin(phase * math.pi).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 7,
                height: 7,
                transform: Matrix4.translationValues(0, -5 * lift, 0),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.35 + 0.65 * lift), shape: BoxShape.circle),
              );
            }),
        ]),
      );
}
