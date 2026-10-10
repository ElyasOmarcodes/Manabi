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
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..forward();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = CurvedAnimation(parent: _c, curve: const Interval(0, 0.65, curve: Curves.easeOutBack));
    final text = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1, curve: Curves.easeOutCubic));
    return Scaffold(
      body: AmbientBackground(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: Tween(begin: 0.7, end: 1.0).animate(logo),
              child: FadeTransition(
                opacity: logo,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(34),
                    boxShadow: [BoxShadow(color: Palette.emerald.withValues(alpha: 0.28), blurRadius: 60, spreadRadius: 6, offset: const Offset(0, 18))],
                  ),
                  child: const ManabiLogo(size: 128),
                ),
              ),
            ),
            const SizedBox(height: 28),
            FadeTransition(
              opacity: text,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(text),
                child: Column(children: [
                  Text('منابع', style: TextStyle(fontFamily: uiFont, fontSize: 40, fontWeight: FontWeight.w800, color: context.cs.onSurface, height: 1.2)),
                  const SizedBox(height: 2),
                  Text('M A N A B I', style: TextStyle(fontFamily: uiFont, fontSize: 13, letterSpacing: 3, color: context.mc.gold, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  if (widget.tagline != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(widget.tagline!, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 15, color: context.cs.onSurfaceVariant)),
                    ),
                  const SizedBox(height: 28),
                  const TypingDots(),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
