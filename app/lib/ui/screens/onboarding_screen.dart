import 'dart:io' show Platform;

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

  int get _count => _asksPermission ? 3 : 2;

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
                  opacity: _page == 0 ? 0 : 1,
                  child: TextButton(onPressed: _page == 0 ? null : widget.onDone, child: Text(l.onbSkip, style: TextStyle(fontFamily: uiFont, color: a.muted))),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pager,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  const _LanguagePage(),
                  const _IntroPage(),
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

class _IntroPage extends StatelessWidget {
  const _IntroPage();
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final items = [
      (Icons.auto_awesome_rounded, AuraHues.violet, l.onbFeatureAnswers, l.onbFeatureAnswersSub),
      (Icons.local_library_rounded, AuraHues.teal, l.onbFeatureLibrary, l.onbFeatureLibrarySub),
      (Icons.psychology_rounded, AuraHues.amber, l.onbFeatureMemory, l.onbFeatureMemorySub),
    ];
    return _PageFrame(children: [
      _Rise(child: _Title(l.onbIntroTitle, l.onbIntroSub)),
      const SizedBox(height: 24),
      for (final (i, (icon, color, title, sub)) in items.indexed) _Rise(delay: 120 + i * 90, child: _Feature(icon: icon, color: color, title: title, sub: sub)),
    ]);
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.color, required this.title, required this.sub});
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: a.border)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: a.text)),
            const SizedBox(height: 3),
            Text(sub, style: TextStyle(fontFamily: uiFont, fontSize: 13, height: 1.65, color: a.muted)),
          ]),
        ),
      ]),
    );
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
