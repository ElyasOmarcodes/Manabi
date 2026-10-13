import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common.dart';

/// Phones show a notification while an answer is prepared in the background,
/// which needs the user's leave; elsewhere there is nothing to ask.
bool get _asksPermission => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// First launch: the language, what Manabi does, and (on phones) the
/// notification it may show; soft pages that slide in turn.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});
  final VoidCallback onDone;
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pager = PageController();
  int _page = 0;
  bool _asking = false;

  int get _count => _asksPermission ? 5 : 4;

  @override
  void dispose() {
    _pager.dispose();
    super.dispose();
  }

  void _next() {
    if (_page >= _count - 1) return widget.onDone();
    _pager.nextPage(duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
  }

  Future<void> _allow() async {
    setState(() => _asking = true);
    try {
      if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
        await FlutterForegroundTask.requestNotificationPermission();
      }
    } catch (_) {}
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final last = _page == _count - 1;
    final permissionPage = _asksPermission && last;
    return Scaffold(
      backgroundColor: a.bg,
      body: Stack(children: [
        // A soft wash of the brand colour behind everything.
        Positioned(
          top: -160,
          left: -120,
          right: -120,
          child: Container(
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [AuraHues.violet.withValues(alpha: a.dark ? 0.22 : 0.13), AuraHues.violet.withValues(alpha: 0)]),
            ),
          ),
        ),
        SafeArea(
          child: Column(children: [
            SizedBox(
              height: 52,
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _page == _count - 1 ? 0 : 1,
                  child: TextButton(onPressed: _page == _count - 1 ? null : widget.onDone, child: Text(l.onbSkip, style: TextStyle(fontFamily: uiFont, color: a.muted))),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _LanguagePage(),
                  _HeroPage(hero: const _AnswersHero(), title: l.onbFeatureAnswers, sub: l.onbFeatureAnswersSub),
                  _HeroPage(hero: const _LibraryHero(), title: l.onbFeatureLibrary, sub: l.onbFeatureLibrarySub),
                  _HeroPage(hero: const _MemoryHero(), title: l.onbFeatureMemory, sub: l.onbFeatureMemorySub),
                  if (_asksPermission) const _PermissionPage(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < _count; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 22 : 7,
                        height: 7,
                        decoration: BoxDecoration(color: i == _page ? a.accent : a.border, borderRadius: BorderRadius.circular(7)),
                      ),
                  ]),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                      onPressed: _asking ? null : (permissionPage ? _allow : _next),
                      child: Text(permissionPage ? l.onbAllow : (last ? l.onbStart : l.onbNext),
                          style: TextStyle(fontFamily: uiFont, fontSize: 15.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (permissionPage)
                    TextButton(onPressed: widget.onDone, child: Text(l.onbNotNow, style: TextStyle(fontFamily: uiFont, color: a.muted)))
                  else
                    const SizedBox(height: 48),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Fades and lifts its child in once, a little after [delay].
class _Rise extends StatelessWidget {
  const _Rise({required this.child, this.delay = 0});
  final Widget child;
  final int delay;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 520 + delay),
        curve: Interval(delay / (520 + delay), 1, curve: Curves.easeOutCubic),
        builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: child)),
        child: child,
      );
}

class _PageFrame extends StatelessWidget {
  const _PageFrame({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
          ),
        ),
      );
}

class _Title extends StatelessWidget {
  const _Title(this.title, this.sub);
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Column(children: [
      Text(title, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 23, fontWeight: FontWeight.w800, height: 1.4, color: a.text)),
      const SizedBox(height: 8),
      Text(sub, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.75, color: a.muted)),
    ]);
  }
}

class _LanguagePage extends StatelessWidget {
  const _LanguagePage();
  static const _names = {'ps': ('پښتو', 'Pashto'), 'fa': ('دری / فارسی', 'Dari / Persian'), 'ar': ('العربية', 'Arabic'), 'en': ('English', 'English')};
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final s = context.watch<SettingsController>();
    return _PageFrame(children: [
      const _Rise(child: Center(child: BrandLogo(height: 72))),
      const SizedBox(height: 26),
      _Rise(delay: 80, child: _Title(l.onbLanguageTitle, l.onbLanguageSub)),
      const SizedBox(height: 22),
      for (final (i, code) in supportedUiLanguages.indexed)
        _Rise(
          delay: 140 + i * 60,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Choice(
              selected: s.uiLanguage == code,
              title: _names[code]!.$1,
              subtitle: code == 'en' ? null : _names[code]!.$2,
              onTap: () => s.setUiLanguage(code),
              accent: a.accent,
            ),
          ),
        ),
    ]);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.selected, required this.title, required this.onTap, required this.accent, this.subtitle});
  final bool selected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color accent;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Pressable(
      onTap: onTap,
      scale: 0.98,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        decoration: BoxDecoration(
          color: selected ? a.accentTint : a.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? accent : a.border, width: selected ? 1.6 : 1),
          boxShadow: selected ? [BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 18, offset: const Offset(0, 6))] : null,
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 16.5, fontWeight: FontWeight.w700, color: a.text)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
            ]),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: selected
                ? Icon(Icons.check_circle_rounded, key: const ValueKey(1), color: accent)
                : Icon(Icons.circle_outlined, key: const ValueKey(0), color: a.faint),
          ),
        ]),
      ),
    );
  }
}

/// A page with a large illustration, its title and a line under it.
class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.hero, required this.title, required this.sub});
  final Widget hero;
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) => _PageFrame(children: [
        _Rise(child: Center(child: SizedBox(width: 260, height: 260, child: hero))),
        const SizedBox(height: 30),
        _Rise(delay: 120, child: _Title(title, sub)),
      ]);
}

/// Something that drifts gently up and down, out of step with its neighbours.
class _Float extends StatefulWidget {
  const _Float({required this.child, this.phase = 0, this.distance = 6});
  final Widget child;
  final double phase;
  final double distance;
  @override
  State<_Float> createState() => _FloatState();
}

class _FloatState extends State<_Float> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(offset: Offset(0, widget.distance * math.sin((_c.value + widget.phase) * 2 * math.pi)), child: child),
        child: widget.child,
      );
}

/// The soft round stage every illustration stands on.
class _Stage extends StatelessWidget {
  const _Stage({required this.color, required this.children});
  final Color color;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
      Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: a.dark ? 0.32 : 0.18), color.withValues(alpha: a.dark ? 0.08 : 0.04)]),
        ),
      ),
      Positioned.fill(
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.18), width: 1.2))),
        ),
      ),
      ...children,
    ]);
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.width, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final double? width;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: a.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: a.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: a.dark ? 0.3 : 0.08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: child,
    );
  }
}

Widget _bar(Color c, double w, {double h = 6}) => Container(width: w, height: h, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(h)));

/// A quotation card with its verified seal and the page it comes from.
class _AnswersHero extends StatelessWidget {
  const _AnswersHero();
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return _Stage(color: AuraHues.violet, children: [
      _Float(
        child: _Card(
          width: 196,
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Icon(Icons.format_quote_rounded, size: 18, color: a.accent), const Spacer(), _bar(a.border, 46)]),
              const SizedBox(height: 8),
              Text('﴿وَتُوبُوا إِلَى اللَّهِ جَمِيعًا﴾', style: arabicStyle(context, size: 15).copyWith(fontFamily: 'Amiri', height: 1.7)),
              const SizedBox(height: 6),
              _bar(a.faint.withValues(alpha: 0.35), 150),
              const SizedBox(height: 6),
              _bar(a.faint.withValues(alpha: 0.35), 110),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(8)),
                  child: Text('٤/٢ · ١', style: TextStyle(fontFamily: uiFont, fontSize: 11, fontWeight: FontWeight.w700, color: a.accent)),
                ),
              ]),
            ]),
          ),
        ),
      ),
      Positioned(
        top: 34,
        right: 22,
        child: _Float(
          phase: 0.35,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AuraHues.green,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: AuraHues.green.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 28),
          ),
        ),
      ),
    ]);
  }
}

/// Book spines on a shelf, one opened to its printed page.
class _LibraryHero extends StatelessWidget {
  const _LibraryHero();
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final spines = [AuraHues.teal, AuraHues.violet, AuraHues.amber, AuraHues.green, AuraHues.blue];
    return _Stage(color: AuraHues.teal, children: [
      Positioned(
        bottom: 62,
        child: _Float(
          distance: 3,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final (i, c) in spines.indexed)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: 22,
                height: 92.0 + (i * 17 % 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [c, Color.lerp(c, Colors.black, 0.18)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [_bar(Colors.white.withValues(alpha: 0.7), 12, h: 3), const SizedBox(height: 4), _bar(Colors.white.withValues(alpha: 0.5), 8, h: 3)]),
              ),
          ]),
        ),
      ),
      Positioned(
        top: 44,
        left: 26,
        child: _Float(
          phase: 0.5,
          child: _Card(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              _bar(a.faint.withValues(alpha: 0.4), 54, h: 5),
              const SizedBox(height: 5),
              _bar(a.faint.withValues(alpha: 0.4), 70, h: 5),
              const SizedBox(height: 5),
              _bar(a.faint.withValues(alpha: 0.4), 40, h: 5),
            ]),
          ),
        ),
      ),
      Positioned(
        top: 30,
        right: 34,
        child: _Float(
          phase: 0.2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: AuraHues.rose, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: AuraHues.rose.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))]),
            child: const Text('PDF', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ),
      ),
    ]);
  }
}

/// The wishes it keeps, as small notes around a light.
class _MemoryHero extends StatelessWidget {
  const _MemoryHero();
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    Widget chip(String text, IconData icon, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: a.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.withValues(alpha: 0.35)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: a.dark ? 0.3 : 0.07), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: c),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: a.text)),
          ]),
        );
    return _Stage(color: AuraHues.amber, children: [
      Container(
        width: 78,
        height: 78,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AuraHues.amber, Color(0xFFF2C14E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AuraHues.amber.withValues(alpha: 0.4), blurRadius: 26, offset: const Offset(0, 10))],
        ),
        child: const Icon(Icons.lightbulb_rounded, color: Colors.white, size: 38),
      ),
      Positioned(top: 30, left: 10, child: _Float(phase: 0.1, child: chip(l.onbChipBrief, Icons.short_text_rounded, AuraHues.violet))),
      Positioned(top: 60, right: 0, child: _Float(phase: 0.45, child: chip(l.onbChipSchool, Icons.account_balance_rounded, AuraHues.green))),
      Positioned(bottom: 40, left: 26, child: _Float(phase: 0.7, child: chip(l.onbChipPosts, Icons.dashboard_customize_outlined, AuraHues.teal))),
    ]);
  }
}

class _PermissionPage extends StatelessWidget {
  const _PermissionPage();
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return _PageFrame(children: [
      _Rise(
        child: Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(gradient: a.brand, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 12))]),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 42),
          ),
        ),
      ),
      const SizedBox(height: 26),
      _Rise(delay: 80, child: _Title(l.onbPermissionTitle, l.onbPermissionSub)),
      const SizedBox(height: 20),
      _Rise(
        delay: 160,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: a.accent),
            const SizedBox(width: 10),
            Expanded(child: Text(l.onbPermissionNote, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, height: 1.6, color: a.muted))),
          ]),
        ),
      ),
    ]);
  }
}
