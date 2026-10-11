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

/// Bottom sheet with the research-depth slider (like an "effort" control).
Future<void> showDepthSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      builder: (context) {
        final s = context.watch<SettingsController>();
        final l = context.l;
        final a = context.aura;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: '${l.researchDepth}: ', style: TextStyle(color: a.text)),
                  TextSpan(text: depthLabel(l, s.researchDepth), style: TextStyle(color: a.accent)),
                ]),
                style: TextStyle(fontFamily: uiFont, fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 18),
              DepthSlider(value: s.researchDepth, onChanged: s.setResearchDepth),
              const SizedBox(height: 10),
              Row(children: [
                for (final d in researchDepths)
                  Expanded(
                    child: Text(depthLabel(l, d),
                        textAlign: d == 'quick' ? TextAlign.start : (d == 'deep' ? TextAlign.end : TextAlign.center),
                        style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: d == s.researchDepth ? FontWeight.w700 : FontWeight.w400, color: d == s.researchDepth ? a.text : a.muted)),
                  ),
              ]),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(depthInfo(l, s.researchDepth),
                    key: ValueKey(s.researchDepth), textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, height: 1.6, color: a.muted)),
              ),
            ]),
          ),
        );
      },
    );

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
