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
                  decoration: BoxDecoration(shape: BoxShape.circle, color: AuraHues.violet.withValues(alpha: 0.45 + 0.25 * i)),
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
  const AuraPage({super.key, required this.body, this.title, this.titleText, this.actions = const [], this.floating, this.bottom});
  final Widget body;
  final Widget? title;

  /// Standard page title; use [title] for a custom widget.
  final String? titleText;
  final List<Widget> actions;
  final Widget? floating;
  final Widget? bottom;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Scaffold(
      backgroundColor: a.bg,
      floatingActionButton: floating,
      bottomNavigationBar: bottom,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                RoundIconButton(
                  icon: Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: title ??
                      Text(titleText ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w700, color: a.text)),
                ),
                ...actions,
              ]),
            ),
          ),
          Expanded(child: body),
        ]),
      ),
    );
  }
}

/// ChatGPT-style round icon button with a soft filled background.
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, this.onTap, this.tooltip, this.size = 40, this.color, this.filled = true});
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
        decoration: BoxDecoration(color: filled ? a.surfaceAlt : Colors.transparent, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.5, color: color ?? a.text),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// A titled group of settings rows on one rounded surface.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, this.title, required this.children});
  final String? title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 20, 14, 8),
          child: Text(title!, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: a.muted)),
        )
      else
        const SizedBox(height: 12),
      Material(
        color: a.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: a.border)),
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Padding(padding: const EdgeInsetsDirectional.only(start: 58), child: Divider(height: 1, color: a.border)),
          ],
        ]),
      ),
    ]);
  }
}

/// One row: tinted icon, title, optional subtitle and value, chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({super.key, required this.icon, required this.title, this.color, this.subtitle, this.value, this.trailing, this.onTap, this.danger = false, this.beta = false});
  final IconData icon;
  final String title;

  /// Shows a "Beta" badge after the title.
  final bool beta;
  final Color? color;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final tint = danger ? a.danger : (color ?? a.text);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 54),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: tint.withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: tint),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Row(children: [
                  Flexible(child: Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w500, color: danger ? a.danger : a.text))),
                  if (beta) const BetaBadge(),
                ]),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.45)),
              ]),
            ),
            if (value != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 150),
                  child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 14, color: a.muted)),
                ),
              ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: a.faint, size: 22),
          ]),
        ),
      ),
    );
  }
}

/// Radio-list dialog for picking one value (languages and the like).
Future<String?> showChoiceDialog(BuildContext context, {required String title, required Map<String, String> options, required String selected}) => showDialog<String>(
      context: context,
      builder: (context) {
        final a = context.aura;
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
                  child: Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w700, color: a.text)),
                ),
                for (final e in options.entries)
                  InkWell(
                    onTap: () => Navigator.of(context).pop(e.key),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      child: Row(children: [
                        Expanded(child: Text(e.value, style: TextStyle(fontFamily: uiFont, fontSize: 15, color: a.text))),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: e.key == selected ? 1 : 0,
                          child: Icon(Icons.check_rounded, color: a.accent, size: 22),
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
          ),
        );
      },
    );

/// A small "Beta" badge: the feature is early and still growing.
class BetaBadge extends StatelessWidget {
  const BetaBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      margin: const EdgeInsetsDirectional.only(start: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AuraHues.amber.withValues(alpha: 0.7)),
        color: AuraHues.amber.withValues(alpha: a.dark ? 0.16 : 0.1),
      ),
      child: const Text('Beta', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 10, fontWeight: FontWeight.w800, color: AuraHues.amber, height: 1.3)),
    );
  }
}
