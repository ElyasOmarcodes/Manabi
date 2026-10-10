import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';

/// Animated brand splash shown while the catalog and stored chats load.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.tagline});
  final String? tagline;
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final orb = CurvedAnimation(parent: _c, curve: const Interval(0, 0.7, curve: Curves.easeOutBack));
    final text = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOutCubic));
    return Scaffold(
      body: AuroraBackground(
        intensity: 1.3,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(orb),
              child: FadeTransition(opacity: orb, child: const AuraOrb(size: 190, child: ManabiMark(size: 76))),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: text,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(text),
                child: Column(children: [
                  const GradientText('منابع', style: TextStyle(fontFamily: uiFont, fontSize: 50, fontWeight: FontWeight.w800, height: 1.25)),
                  Text('M A N A B I', style: TextStyle(fontFamily: uiFont, fontSize: 13, letterSpacing: 4, color: a.muted, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 18),
                  if (widget.tagline != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 36),
                      child: Text(widget.tagline!, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.7, color: a.muted)),
                    ),
                  const SizedBox(height: 30),
                  const TypingDots(size: 9),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
