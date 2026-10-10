import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/gen/app_localizations.dart';
import '../theme.dart';
import 'aura.dart';

export 'aura.dart';

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

/// Three dots breathing through the brand gradient.
class TypingDots extends StatefulWidget {
  const TypingDots({super.key, this.size = 8});
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
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
              child: Transform.translate(
                offset: Offset(0, -3 * math.max(0, math.sin(_c.value * 2 * math.pi - i * 0.8))),
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: [AuraHues.violet, AuraHues.blue, AuraHues.cyan][i]),
                ),
              ),
            ),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.action, this.color = AuraHues.violet});
  final IconData icon;
  final String text;
  final Widget? action;
  final Color color;
  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Reveal(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Stack(alignment: Alignment.center, children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)])),
                ),
                IconTile(icon: icon, color: color, size: 64, gradient: true),
              ]),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.7, color: context.aura.muted)),
              ),
              if (action != null) ...[const SizedBox(height: 18), action!],
            ]),
          ),
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
        color: AuraHues.rose,
        text: errorText(context.l, code),
        action: onRetry == null ? null : SoftButton(onTap: onRetry, icon: Icons.refresh_rounded, label: context.l.retry),
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

/// Scaffold for pushed pages: aurora background and a floating back button.
class AuraPage extends StatelessWidget {
  const AuraPage({super.key, required this.body, this.title, this.actions = const [], this.floating, this.bottom});
  final Widget body;
  final Widget? title;
  final List<Widget> actions;
  final Widget? floating;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) => Scaffold(
        floatingActionButton: floating,
        bottomNavigationBar: bottom,
        body: AuroraBackground(
          intensity: 0.8,
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                child: Row(children: [
                  AuraIconButton(
                    icon: Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: title ?? const SizedBox()),
                  ...actions,
                ]),
              ),
              Expanded(child: body),
            ]),
          ),
        ),
      );
}
