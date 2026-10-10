// Aura widget kit – hand-made widgets for Manabi's design language.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Clean solid page background (kept as a widget so pages share one look).
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, required this.child, this.intensity = 1});
  final Widget child;
  final double intensity;
  @override
  Widget build(BuildContext context) => ColoredBox(color: context.aura.bg, child: child);
}

/// Frosted glass surface with a hairline border and diffuse shadow.
class Glass extends StatelessWidget {
  const Glass({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.radius = 26, this.blur = 18, this.color, this.border = true, this.shadow = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color? color;
  final bool border;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final br = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: shadow ? [BoxShadow(color: a.shadow, blurRadius: 40, offset: const Offset(0, 16), spreadRadius: -12)] : null,
      ),
      child: ClipRRect(
        borderRadius: br,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: color ?? a.glass,
              borderRadius: br,
              border: border ? Border.all(color: a.dark ? Colors.white.withValues(alpha: 0.06) : Colors.white.withValues(alpha: 0.9)) : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Solid card used for content – white / ink with soft shadow.
class AuraCard extends StatelessWidget {
  const AuraCard({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 26, this.onTap, this.color, this.gradientBorder = false});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final bool gradientBorder;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final br = BorderRadius.circular(radius);
    Widget card = Material(
      color: color ?? a.surface,
      borderRadius: br,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
    card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        border: gradientBorder ? null : Border.all(color: a.border.withValues(alpha: a.dark ? 0.8 : 0.7)),
        boxShadow: [BoxShadow(color: a.shadow, blurRadius: 30, offset: const Offset(0, 12), spreadRadius: -14)],
      ),
      child: card,
    );
    if (gradientBorder) {
      card = Container(
        padding: const EdgeInsets.all(1.4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(radius + 1.4), gradient: a.brand),
        child: card,
      );
    }
    return onTap == null ? card : Pressable(onTap: null, child: card);
  }
}

/// Subtle press-down scale for anything tappable.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.onTap, this.scale = 0.97});
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.translucent,
          child: AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 140), curve: Curves.easeOut, child: widget.child),
        ),
      );
}

/// Text filled with the brand gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.gradient, this.textAlign});
  final String text;
  final TextStyle? style;
  final Gradient? gradient;
  final TextAlign? textAlign;
  @override
  Widget build(BuildContext context) => ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) => (gradient ?? context.aura.brand).createShader(Offset.zero & r.size),
        child: Text(text, style: style, textAlign: textAlign),
      );
}

/// Gradient pill button.
class GradientButton extends StatelessWidget {
  const GradientButton({super.key, required this.label, this.icon, this.onTap, this.gradient, this.expand = false, this.height = 52});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Gradient? gradient;
  final bool expand;
  final double height;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? context.aura.brand;
    final enabled = onTap != null;
    return Pressable(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.45,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            gradient: g,
            borderRadius: BorderRadius.circular(height / 2),
            boxShadow: [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -8)],
          ),
          child: Row(mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: uiFont, color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
          ]),
        ),
      ),
    );
  }
}

/// Quiet secondary button.
class SoftButton extends StatelessWidget {
  const SoftButton({super.key, required this.label, this.icon, this.onTap, this.color, this.dense = false});
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final c = color ?? a.accent;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 12 : 16, vertical: dense ? 7 : 11),
        decoration: BoxDecoration(color: c.withValues(alpha: a.dark ? 0.16 : 0.09), borderRadius: BorderRadius.circular(40)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: dense ? 16 : 18, color: c), const SizedBox(width: 6)],
          Text(label, style: TextStyle(fontFamily: uiFont, color: c, fontWeight: FontWeight.w600, fontSize: dense ? 12.5 : 14)),
        ]),
      ),
    );
  }
}

/// Round icon button on a glassy chip.
class AuraIconButton extends StatelessWidget {
  const AuraIconButton({super.key, required this.icon, this.onTap, this.tooltip, this.size = 44, this.color, this.filled = true});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color? color;
  final bool filled;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final button = Pressable(
      onTap: onTap,
      scale: 0.9,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: filled ? a.surface.withValues(alpha: a.dark ? 0.7 : 0.9) : Colors.transparent,
          shape: BoxShape.circle,
          border: filled ? Border.all(color: a.border) : null,
        ),
        child: Icon(icon, size: size * 0.46, color: color ?? a.text),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Coloured rounded square holding an icon (iOS-settings style).
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, required this.color, this.size = 40, this.gradient = false});
  final IconData icon;
  final Color color;
  final double size;
  final bool gradient;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.32),
          color: gradient ? null : color.withValues(alpha: context.aura.dark ? 0.2 : 0.12),
          gradient: gradient ? LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight) : null,
        ),
        child: Icon(icon, size: size * 0.5, color: gradient ? Colors.white : color),
      );
}

/// Selectable pill (filters, scope, language).
class AuraChip extends StatelessWidget {
  const AuraChip({super.key, required this.label, this.icon, this.selected = false, this.onTap, this.onClear, this.color});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onClear;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final c = color ?? a.accent;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsetsDirectional.fromSTEB(icon == null ? 14 : 10, 8, onClear != null && selected ? 6 : 14, 8),
        decoration: BoxDecoration(
          color: selected ? a.accent : a.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: selected ? Colors.transparent : a.border),
          boxShadow: selected ? [BoxShadow(color: a.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -6)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: selected ? Colors.white : c),
            const SizedBox(width: 6),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : a.text)),
          ),
          if (onClear != null && selected) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onClear,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Custom segmented control with a sliding gradient thumb.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({super.key, required this.values, required this.labels, required this.value, required this.onChanged, this.icons, this.enabled});
  final List<T> values;
  final List<String> labels;
  final List<IconData>? icons;
  final T value;
  final ValueChanged<T> onChanged;
  final List<bool>? enabled;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final index = values.indexOf(value);
    return LayoutBuilder(builder: (context, c) {
      final w = (c.maxWidth - 8) / values.length; // inner width after 4px padding
      final rtl = Directionality.of(context) == TextDirection.rtl;
      return Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(30)),
        child: Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            left: rtl ? null : index * w,
            right: rtl ? index * w : null,
            top: 0,
            bottom: 0,
            width: w,
            child: Container(
              decoration: BoxDecoration(
                gradient: a.brand,
                borderRadius: BorderRadius.circular(26),
                boxShadow: [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 5), spreadRadius: -4)],
              ),
            ),
          ),
          Positioned.fill(child: Row(children: [
            for (var i = 0; i < values.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: (enabled?[i] ?? true) ? () => onChanged(values[i]) : null,
                  child: Opacity(
                    opacity: (enabled?[i] ?? true) ? 1 : 0.4,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (icons != null) ...[
                        Icon(icons![i], size: 17, color: i == index ? Colors.white : a.muted),
                        const SizedBox(width: 6),
                      ],
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w600, color: i == index ? Colors.white : a.muted),
                          child: Text(labels[i], overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ])),
        ]),
      );
    });
  }
}

/// Animated gradient orb – Manabi's "thinking" indicator and hero art.
class AuraOrb extends StatefulWidget {
  const AuraOrb({super.key, this.size = 120, this.animate = true, this.child});
  final double size;
  final bool animate;
  final Widget? child;
  @override
  State<AuraOrb> createState() => _AuraOrbState();
}

class _AuraOrbState extends State<AuraOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value * 2 * math.pi;
          final pulse = 1 + 0.04 * math.sin(t * 2);
          return Stack(alignment: Alignment.center, children: [
            Transform.scale(
              scale: 1.25 * pulse,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [AuraHues.violet.withValues(alpha: 0.18), AuraHues.violet.withValues(alpha: 0.0)]),
                ),
              ),
            ),
            Transform.rotate(
              angle: t,
              child: Transform.scale(
                scale: pulse,
                child: Container(
                  width: s * 0.82,
                  height: s * 0.82,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: [AuraHues.violet, AuraHues.orchid, AuraHues.violet]),
                  ),
                ),
              ),
            ),
            Container(
              width: s * 0.82,
              height: s * 0.82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.4),
                  colors: [Colors.white.withValues(alpha: 0.75), Colors.white.withValues(alpha: 0.0)],
                  stops: const [0, 0.65],
                ),
              ),
            ),
            ?child,
          ]);
        },
        child: widget.child,
      ),
    );
  }
}

/// Manabi mark drawn in code: gradient squircle with a star and an open book.
class ManabiMark extends StatelessWidget {
  const ManabiMark({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: context.aura.brand,
          borderRadius: BorderRadius.circular(size * 0.3),
          boxShadow: [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.35), blurRadius: size * 0.4, offset: Offset(0, size * 0.12), spreadRadius: -size * 0.12)],
        ),
        child: CustomPaint(painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.34;
    final star = Path();
    for (var k = 0; k < 16; k++) {
      final ang = -math.pi / 2 + k * math.pi / 8;
      final rr = k.isEven ? r : r * 0.78;
      final p = Offset(c.dx + rr * math.cos(ang), c.dy + rr * math.sin(ang));
      k == 0 ? star.moveTo(p.dx, p.dy) : star.lineTo(p.dx, p.dy);
    }
    star.close();
    canvas.drawPath(star, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.045
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white.withValues(alpha: 0.95));
    // open book
    final w = r * 1.0;
    final h = r * 0.48;
    final paint = Paint()..color = Colors.white;
    for (final side in [-1.0, 1.0]) {
      final p = Path()
        ..moveTo(c.dx, c.dy - h * 0.42)
        ..quadraticBezierTo(c.dx + side * w * 0.25, c.dy - h * 0.62, c.dx + side * w * 0.5, c.dy - h * 0.44)
        ..lineTo(c.dx + side * w * 0.5, c.dy + h * 0.5)
        ..quadraticBezierTo(c.dx + side * w * 0.25, c.dy + h * 0.32, c.dx, c.dy + h * 0.52)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Section label with a small gradient bar.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing, this.padding = const EdgeInsets.fromLTRB(6, 22, 6, 10)});
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
        padding: padding,
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w700, color: context.aura.muted, letterSpacing: 0.2))),
          ?trailing,
        ]),
      );
}

/// Large page title with optional gradient word and subtitle.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.subtitle, this.icon, this.color = AuraHues.violet, this.trailing});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color color;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      child: Row(children: [
        if (icon != null) ...[IconTile(icon: icon!, color: color, size: 46, gradient: true), const SizedBox(width: 14)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 26, fontWeight: FontWeight.w800, color: a.text, height: 1.25)),
            if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

/// Search field with a soft glassy look.
class AuraSearchField extends StatelessWidget {
  const AuraSearchField({super.key, required this.hint, this.onChanged, this.onSubmitted, this.rtl = false, this.autofocus = false, this.controller});
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool rtl;
  final bool autofocus;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      decoration: BoxDecoration(
        color: a.surface.withValues(alpha: a.dark ? 0.75 : 0.95),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: a.border),
        boxShadow: [BoxShadow(color: a.shadow, blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -14)],
      ),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        textDirection: rtl ? TextDirection.rtl : null,
        style: TextStyle(fontFamily: uiFont, color: a.text, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => a.brand.createShader(Offset.zero & r.size),
            child: const Icon(Icons.search_rounded),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

/// Book cover generated from the title, tinted by the book's category.
class BookCover extends StatelessWidget {
  const BookCover({super.key, required this.title, this.color = AuraHues.violet, this.width = 46, this.height = 60});
  final String title;
  final Color color;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) {
    final letter = title.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '').characters.take(1).toString();
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.2),
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.28)!], begin: Alignment.topRight, end: Alignment.bottomLeft),
      ),
      child: Stack(children: [
        PositionedDirectional(start: width * 0.13, top: 0, bottom: 0, child: Container(width: 1.5, color: Colors.white.withValues(alpha: 0.4))),
        Center(child: Text(letter, style: TextStyle(fontFamily: arabicFont, fontSize: width * 0.46, color: Colors.white, fontWeight: FontWeight.w700, height: 1.3))),
      ]),
    );
  }
}

/// Tinted feature card (soft colour wash + coloured hairline), as used for
/// entry points such as "browse categories".
class FeatureCard extends StatelessWidget {
  const FeatureCard({super.key, required this.icon, required this.title, required this.color, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color color;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: a.dark ? 0.12 : 0.06), a.surface),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: color.withValues(alpha: a.dark ? 0.35 : 0.28), width: 1.2),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withValues(alpha: a.dark ? 0.22 : 0.13), borderRadius: BorderRadius.circular(15)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: a.text)),
          if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.6)),
        ]),
      ),
    );
  }
}

/// Solid coloured statistic tile.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, required this.icon, required this.color});
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: a.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: color.withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontFamily: uiFont, fontSize: 21, fontWeight: FontWeight.w800, color: a.text, height: 1.2))),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted)),
      ]),
    );
  }
}

/// Soft pill showing a short status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color, required this.icon});
  final String label;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: color.withValues(alpha: context.aura.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(30)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, style: TextStyle(fontFamily: uiFont, color: color, fontWeight: FontWeight.w700, fontSize: 12.5))),
        ]),
      );
}

/// Smooth on-appear animation (fade + rise), optionally staggered.
class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child, this.delay = 0, this.offset = 18});
  final Widget child;
  final int delay;
  final double offset;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 520 + delay),
        curve: Interval(delay / (520 + delay), 1, curve: Curves.easeOutCubic),
        builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * offset), child: child)),
        child: child,
      );
}

/// Grouped settings-style list.
class TileGroup extends StatelessWidget {
  const TileGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return AuraCard(
      padding: EdgeInsets.zero,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) Padding(padding: const EdgeInsetsDirectional.only(start: 68), child: Divider(color: a.border.withValues(alpha: 0.7))),
        ],
      ]),
    );
  }
}

class AuraTile extends StatelessWidget {
  const AuraTile({super.key, required this.icon, required this.color, required this.title, this.subtitle, this.trailing, this.onTap, this.titleStyle});
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final TextStyle? titleStyle;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          IconTile(icon: icon, color: color, size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: titleStyle ?? TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w600, color: a.text)),
              if (subtitle != null) Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.5)),
            ]),
          ),
          if (trailing != null) trailing! else if (onTap != null) Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: a.faint),
        ]),
      ),
    );
  }
}
