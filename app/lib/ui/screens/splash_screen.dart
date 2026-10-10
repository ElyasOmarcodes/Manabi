import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/brand_logo.dart';
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
    final orb = CurvedAnimation(parent: _c, curve: const Interval(0, 0.6, curve: Curves.easeOutCubic));
    final text = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOutCubic));
    return Scaffold(
      backgroundColor: a.bg,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: Tween(begin: 0.92, end: 1.0).animate(orb),
            child: FadeTransition(opacity: orb, child: const BrandLogo(height: 104)),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: text,
            child: Column(children: [
              if (widget.tagline != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(widget.tagline!, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.7, color: a.muted)),
                ),
              const SizedBox(height: 26),
              const TypingDots(size: 7),
            ]),
          ),
        ]),
      ),
    );
  }
}
