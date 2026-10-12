import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import 'common.dart';

const researchDepths = ['quick', 'standard', 'deep'];

String depthLabel(AppLocalizations l, String depth) => switch (depth) {
      'quick' => l.depthQuick,
      'deep' => l.depthDeep,
      _ => l.depthStandard,
    };

String depthInfo(AppLocalizations l, String depth) => switch (depth) {
      'quick' => l.depthQuickInfo,
      'deep' => l.depthDeepInfo,
      _ => l.depthStandardInfo,
    };

IconData depthIcon(String depth) => switch (depth) {
      'quick' => Icons.bolt_rounded,
      'deep' => Icons.travel_explore_rounded,
      _ => Icons.speed_rounded,
    };

/// Where the gauge needle points for a depth, out of 120: about 40, 80, 120.
double depthGauge(String depth) => switch (depth) {
      'quick' => 40 / 120,
      'deep' => 1.0,
      _ => 80 / 120,
    };

/// A speedometer whose needle glides to the research depth.
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({super.key, required this.depth, this.size = 22, this.color, this.numbers = false});
  final String depth;
  final double size;
  final Color? color;

  /// The 0–120 scale around the dial (for large gauges).
  final bool numbers;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final c = color ?? a.accent;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: depthGauge(depth)),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutBack,
      builder: (context, f, _) => SizedBox(
        width: size,
        height: size,
        // The dial turns clockwise whatever the text direction.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: CustomPaint(painter: _GaugePainter(f, c, a.faint, numbers ? TextStyle(fontFamily: uiFont, fontSize: size * 0.1, color: a.muted) : null)),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter(this.f, this.color, this.track, this.numberStyle);
  final double f;
  final Color color;
  final Color track;
  final TextStyle? numberStyle;

  static const start = math.pi * 0.75; // 135°, lower left
  static const sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final big = numberStyle != null;
    final center = size.center(Offset(0, size.height * 0.04));
    final stroke = size.width * (big ? 0.07 : 0.12);
    final radius = size.width / 2 - stroke / 2 - (big ? size.width * 0.02 : 0);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final t = f.clamp(0.0, 1.05);
    canvas.drawArc(rect, start, sweep, false, Paint()
      ..color = track.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
    canvas.drawArc(rect, start, sweep * t.clamp(0.0, 1.0), false, Paint()
      ..shader = SweepGradient(startAngle: start, endAngle: start + sweep, colors: [color.withValues(alpha: 0.45), color], transform: const GradientRotation(0)).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke);
    if (big) {
      // Ticks every 20 and the numbers every 40.
      for (var i = 0; i <= 6; i++) {
        final ang = start + sweep * i / 6;
        final dir = Offset(math.cos(ang), math.sin(ang));
        final inner = radius - stroke * 1.3 - (i.isEven ? stroke * 0.6 : 0);
        canvas.drawLine(center + dir * inner, center + dir * (radius - stroke * 1.1), Paint()
          ..color = track
          ..strokeWidth = size.width * 0.012
          ..strokeCap = StrokeCap.round);
        if (i.isEven) {
          final tp = TextPainter(text: TextSpan(text: '${i * 20}', style: numberStyle), textDirection: TextDirection.ltr)..layout();
          final at = center + dir * (inner - size.width * 0.08);
          tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
        }
      }
    }
    final ang = start + sweep * t;
    final dir = Offset(math.cos(ang), math.sin(ang));
    final needle = Paint()
      ..color = color
      ..strokeWidth = size.width * (big ? 0.035 : 0.1)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(center - dir * radius * 0.12, center + dir * radius * (big ? 0.72 : 0.62), needle);
    canvas.drawCircle(center, size.width * (big ? 0.06 : 0.11), Paint()..color = color);
    if (big) canvas.drawCircle(center, size.width * 0.025, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_GaugePainter old) => old.f != f || old.color != color || old.track != track;
}

/// The research-depth control in a small card anchored to [anchor] (the
/// button or row that opened it), not a bottom sheet.
Future<void> showDepthPopup(BuildContext anchor) {
  final navigator = Navigator.of(anchor);
  final box = anchor.findRenderObject() as RenderBox?;
  final overlay = navigator.overlay?.context.findRenderObject() as RenderBox?;
  final rect = box != null && overlay != null && box.hasSize ? box.localToGlobal(Offset.zero, ancestor: overlay) & box.size : null;
  return navigator.push(_AnchoredRoute(
    anchor: rect,
    label: MaterialLocalizations.of(anchor).modalBarrierDismissLabel,
    child: const _DepthCard(),
  ));
}

class _AnchoredRoute extends PopupRoute<void> {
  _AnchoredRoute({required this.anchor, required this.label, required this.child});
  final Rect? anchor;
  final String label;
  final Widget child;

  @override
  Color? get barrierColor => Colors.black.withValues(alpha: 0.06);
  @override
  bool get barrierDismissible => true;
  @override
  String? get barrierLabel => label;
  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    final media = MediaQuery.of(context);
    final rect = anchor ?? Rect.fromCenter(center: media.size.center(Offset.zero), width: 0, height: 0);
    return CustomSingleChildLayout(
      delegate: _AnchorLayout(rect, media.padding + const EdgeInsets.all(12), media.viewInsets.bottom),
      child: child,
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final media = MediaQuery.of(context);
    final above = (anchor?.top ?? 0) > media.size.height / 2;
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(curved), alignment: above ? Alignment.bottomCenter : Alignment.topCenter, child: child),
    );
  }
}

/// Puts the card above the anchor when it is low on the screen (as the chat
/// box is), otherwise below, kept inside the screen.
class _AnchorLayout extends SingleChildLayoutDelegate {
  _AnchorLayout(this.anchor, this.margin, this.keyboard);
  final Rect anchor;
  final EdgeInsets margin;
  final double keyboard;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) =>
      BoxConstraints(maxWidth: math.min(360, c.maxWidth - margin.horizontal), maxHeight: c.maxHeight - margin.vertical - keyboard);

  @override
  Offset getPositionForChild(Size size, Size child) {
    final above = anchor.top > size.height / 2;
    final y = above ? anchor.top - child.height - 8 : anchor.bottom + 8;
    final x = anchor.center.dx - child.width / 2;
    return Offset(x.clamp(margin.left, size.width - margin.right - child.width), y.clamp(margin.top, size.height - margin.bottom - keyboard - child.height));
  }

  @override
  bool shouldRelayout(_AnchorLayout old) => old.anchor != anchor || old.keyboard != keyboard;
}

class _DepthCard extends StatelessWidget {
  const _DepthCard();
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    return Material(
      color: a.surface,
      elevation: 0,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: a.border),
          boxShadow: [BoxShadow(color: a.shadow, blurRadius: 30, offset: const Offset(0, 12), spreadRadius: -6)],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            SpeedGauge(depth: s.researchDepth, size: 84, numbers: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.researchDepth, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted)),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(depthLabel(l, s.researchDepth),
                      key: ValueKey(s.researchDepth), style: TextStyle(fontFamily: uiFont, fontSize: 20, fontWeight: FontWeight.w800, color: a.accent)),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 12),
          DepthSlider(value: s.researchDepth, onChanged: s.setResearchDepth),
          const SizedBox(height: 8),
          Row(children: [
            for (final d in researchDepths)
              Expanded(
                child: Text(depthLabel(l, d),
                    textAlign: d == 'quick' ? TextAlign.start : (d == 'deep' ? TextAlign.end : TextAlign.center),
                    style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: d == s.researchDepth ? FontWeight.w700 : FontWeight.w400, color: d == s.researchDepth ? a.text : a.muted)),
              ),
          ]),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(depthInfo(l, s.researchDepth),
                key: ValueKey(s.researchDepth), textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, height: 1.6, color: a.muted)),
          ),
        ]),
      ),
    );
  }
}

/// A round button showing the gauge; opens the depth card anchored to it.
class DepthButton extends StatelessWidget {
  const DepthButton({super.key, this.size = 40});
  final double size;
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    return Tooltip(
      message: '${l.researchDepth}: ${depthLabel(l, s.researchDepth)}',
      child: Pressable(
        onTap: () => showDepthPopup(context),
        scale: 0.9,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(child: SpeedGauge(depth: s.researchDepth, size: size * 0.55, color: s.researchDepth == 'standard' ? a.muted : a.accent)),
        ),
      ),
    );
  }
}

/// Three-stop pill slider: a filled track up to a round white thumb.
class DepthSlider extends StatelessWidget {
  const DepthSlider({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final index = researchDepths.indexOf(value).clamp(0, 2);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return LayoutBuilder(builder: (context, c) {
      const height = 56.0;
      const pad = 6.0;
      const thumb = height - pad * 2;
      final w = c.maxWidth;
      final travel = w - pad * 2 - thumb;
      double xFor(int i) => pad + travel * i / 2;
      void setFrom(double dx) {
        final local = rtl ? w - dx : dx;
        final i = ((local - pad - thumb / 2) / travel * 2).round().clamp(0, 2);
        if (researchDepths[i] != value) {
          HapticFeedback.selectionClick();
          onChanged(researchDepths[i]);
        }
      }

      final x = xFor(index);
      return Semantics(
        slider: true,
        value: researchDepths[index],
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => setFrom(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => setFrom(d.localPosition.dx),
          child: SizedBox(
            height: height,
            child: Stack(children: [
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(height)))),
              AnimatedPositionedDirectional(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                start: pad,
                top: pad,
                bottom: pad,
                width: x - pad + thumb,
                child: DecoratedBox(decoration: BoxDecoration(color: a.accent, borderRadius: BorderRadius.circular(height))),
              ),
              for (var i = 0; i < 3; i++)
                PositionedDirectional(
                  start: xFor(i) + thumb / 2 - 4,
                  top: height / 2 - 4,
                  child: Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: i <= index ? Colors.white.withValues(alpha: 0.7) : a.faint)),
                ),
              AnimatedPositionedDirectional(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                start: x,
                top: pad,
                child: Container(
                  width: thumb,
                  height: thumb,
                  decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: a.shadow, blurRadius: 8, offset: const Offset(0, 2))]),
                  child: Icon(depthIcon(value), color: a.accent, size: 20),
                ),
              ),
            ]),
          ),
        ),
      );
    });
  }
}
