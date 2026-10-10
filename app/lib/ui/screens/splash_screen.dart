import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';

/// Brand splash shown while the catalog and stored chats load: the
/// calligraphy rises in over a slowly breathing violet glow, with a slim
/// progress line and the source credit at the bottom.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.tagline});
  final String? tagline;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..forward();
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final logo = CurvedAnimation(parent: _intro, curve: const Interval(0, 0.65, curve: Curves.easeOutCubic));
    final text = CurvedAnimation(parent: _intro, curve: const Interval(0.35, 1, curve: Curves.easeOutCubic));
    return Scaffold(
      backgroundColor: a.bg,
      body: Stack(children: [
        // Breathing glow behind the logo.
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _loop,
            builder: (context, _) {
              final t = 0.5 + 0.5 * math.sin(_loop.value * 2 * math.pi);
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.12),
                    radius: 0.75 + 0.08 * t,
                    colors: [AuraHues.violet.withValues(alpha: (a.dark ? 0.20 : 0.11) + 0.04 * t), a.bg.withValues(alpha: 0)],
                  ),
                ),
              );
            },
          ),
        ),
        Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FadeTransition(
              opacity: logo,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.12), end: Offset.zero).animate(logo),
                child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(logo), child: const BrandLogo(height: 112)),
              ),
            ),
            const SizedBox(height: 26),
            FadeTransition(
              opacity: text,
              child: Column(children: [
                if (widget.tagline != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 44),
                    child: Text(widget.tagline!, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.7, color: a.muted)),
                  ),
                const SizedBox(height: 28),
                _ProgressLine(animation: _loop, color: a.accent, track: a.border),
              ]),
            ),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: MediaQuery.paddingOf(context).bottom + 26,
          child: FadeTransition(
            opacity: text,
            child: Text('turath.io  ·  Nusus', textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, letterSpacing: 1.2, color: a.faint)),
          ),
        ),
      ]),
    );
  }
}

/// A short rounded track with a segment sliding back and forth.
class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.animation, required this.color, required this.track});
  final Animation<double> animation;
  final Color color;
  final Color track;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 120,
        height: 4,
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Curves.easeInOut.transform((math.sin(animation.value * 2 * math.pi) + 1) / 2);
            return Stack(children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(4)))),
              Positioned(
                left: t * 80,
                width: 40,
                top: 0,
                bottom: 0,
                child: DecoratedBox(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
              ),
            ]);
          },
        ),
      );
}
