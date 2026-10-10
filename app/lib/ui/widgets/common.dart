import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';

extension L10nX on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this);
}

String errorText(AppLocalizations l, String? code) => switch (code) {
      'NETWORK' => l.errNetwork,
      'SERVER_NOT_CONFIGURED' => l.errServerNotConfigured,
      'NO_API_KEY' => l.errNoApiKey,
      'DIRECT_NOT_ON_WEB' => l.errDirectNotOnWeb,
      'GEMINI_AUTH' => l.errGeminiAuth,
      'GEMINI_QUOTA' => l.errGeminiQuota,
      'GEMINI_UNAVAILABLE' => l.errGeminiUnavailable,
      'TURATH_UNAVAILABLE' || 'TURATH_RATE_LIMITED' => l.errTurathUnavailable,
      'RATE_LIMITED' => l.errRateLimited,
      'UNAUTHORIZED' => l.errUnauthorized,
      'INTERRUPTED' => l.errInterrupted,
      'CANCELLED' => l.errCancelled,
      'NOT_FOUND' => l.errNotFound,
      _ => l.errGeneric,
    };

bool isSetupError(String? code) => const {'SERVER_NOT_CONFIGURED', 'NO_API_KEY', 'DIRECT_NOT_ON_WEB', 'GEMINI_AUTH', 'UNAUTHORIZED'}.contains(code);

/// Soft, low-contrast card with a hairline border and a diffuse shadow.
class SoftCard extends StatelessWidget {
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18), this.onTap, this.color, this.radius = 22, this.borderColor});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final double radius;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: br,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: dark ? 0.22 : 0.045), blurRadius: 28, offset: const Offset(0, 10)),
        ],
      ),
      child: Material(
        color: color ?? context.cs.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: br, side: BorderSide(color: borderColor ?? context.cs.outlineVariant.withValues(alpha: 0.55))),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Very soft ambient background with two blurred colour fields.
class AmbientBackground extends StatelessWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Stack(children: [
      Positioned.fill(child: ColoredBox(color: context.cs.surface)),
      Positioned(
        top: -160,
        right: -120,
        child: _Blob(size: 420, color: (dark ? const Color(0xFF1C5A4F) : const Color(0xFFCFE8DF)).withValues(alpha: dark ? 0.35 : 0.55)),
      ),
      Positioned(
        bottom: -200,
        left: -140,
        child: _Blob(size: 460, color: (dark ? const Color(0xFF4A3D1F) : const Color(0xFFF2E3C2)).withValues(alpha: dark ? 0.25 : 0.5)),
      ),
      Positioned.fill(child: child),
    ]);
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.size, required this.color});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])),
        ),
      );
}

class ManabiLogo extends StatelessWidget {
  const ManabiLogo({super.key, this.size = 44});
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.23),
        child: Image.asset('assets/images/logo.png', width: size, height: size, filterQuality: FilterQuality.medium),
      );
}

/// Three softly pulsing dots.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.color, this.size = 7});
  final Color? color;
  final double size;
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? context.cs.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: widget.size * 0.28),
            child: Opacity(
              opacity: 0.3 + 0.7 * ((math.sin((_c.value * 2 * math.pi) - i * 0.9) + 1) / 2),
              child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            ),
          ),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(color: context.mc.glow, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: context.cs.primary),
            ),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: context.tt.bodyLarge?.copyWith(color: context.cs.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ]),
        ),
      );
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel({super.key, required this.code, this.onRetry});
  final String? code;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        text: errorText(context.l, code),
        action: onRetry == null ? null : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(context.l.retry)),
      );
}

Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) toast(context, context.l.copied);
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.scheme == 'https' || uri.scheme == 'http')) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Centers content at a comfortable reading width.
class ReadingWidth extends StatelessWidget {
  const ReadingWidth({super.key, required this.child, this.maxWidth = 820});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(children: [
          Expanded(
            child: Text(text, style: context.tt.titleSmall?.copyWith(color: context.cs.primary, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          ),
          ?trailing,
        ]),
      );
}
