import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../state/chat_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/chat_list.dart' show confirmDialog;
import '../widgets/common.dart';
import '../widgets/depth_picker.dart';
import 'chat_screen.dart' show languageLabels;

/// Shared frame of a settings sub-page.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AuraPage(
        titleText: title,
        body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 28), children: [
          ReadingWidth(maxWidth: 680, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ]),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 20, 14, 8),
        child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: context.aura.muted)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: a.border)),
      child: child,
    );
  }
}

// ── Appearance ──────────────────────────────────────────────────────────

class AppearanceSettingsPage extends StatelessWidget {
  const AppearanceSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    return _SettingsPage(title: l.appearance, children: [
      _Label(l.theme),
      Row(children: [
        for (final (mode, label, icon) in [
          (ThemeMode.system, l.themeSystem, Icons.brightness_auto_rounded),
          (ThemeMode.light, l.themeLight, Icons.light_mode_rounded),
          (ThemeMode.dark, l.themeDark, Icons.dark_mode_rounded),
        ])
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _ThemeCard(mode: mode, label: label, icon: icon, selected: s.themeMode == mode, onTap: () => s.setThemeMode(mode)),
            ),
          ),
      ]),
      _Label(l.textSize),
      _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('A', style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted)),
            Expanded(child: Slider(value: s.textScale, min: 0.85, max: 1.2, divisions: 7, onChanged: s.setTextScale)),
            Text('A', style: TextStyle(fontFamily: uiFont, fontSize: 20, color: a.muted)),
          ]),
          Text(l.textSizeSample, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.6, color: a.text)),
        ]),
      ),
      _Label(l.arabicTextSize),
      _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Text('ع', style: TextStyle(fontFamily: arabicFont, fontSize: 14, color: a.muted)),
            Expanded(child: Slider(value: s.arabicScale, min: 0.85, max: 1.5, divisions: 13, onChanged: s.setArabicScale)),
            Text('ع', style: TextStyle(fontFamily: arabicFont, fontSize: 22, color: a.muted)),
          ]),
          Text('إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 19, scale: s.arabicScale)),
        ]),
      ),
    ]);
  }
}

/// Mini mock-up preview of a theme.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.mode, required this.label, required this.icon, required this.selected, required this.onTap});
  final ThemeMode mode;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    Widget mock(Aura t) => Container(
          decoration: BoxDecoration(color: t.bg, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.all(8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Container(height: 10, width: 46, decoration: BoxDecoration(gradient: a.brand, borderRadius: BorderRadius.circular(6))),
            const SizedBox(height: 6),
            Container(height: 22, decoration: BoxDecoration(color: t.surface, borderRadius: BorderRadius.circular(7), border: Border.all(color: t.border))),
            const SizedBox(height: 6),
            Container(height: 8, width: 60, decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(4))),
          ]),
        );
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: selected ? a.brand : LinearGradient(colors: [a.border, a.border])),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(children: [
            SizedBox(
              height: 74,
              child: mode == ThemeMode.system
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Row(children: [Expanded(child: mock(Aura.light)), Expanded(child: mock(Aura.night))]),
                    )
                  : mock(mode == ThemeMode.dark ? Aura.night : Aura.light),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 16, color: selected ? a.accent : a.muted),
              const SizedBox(width: 6),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, fontSize: 13, color: selected ? a.accent : a.text))),
            ]),
          ]),
        ),
      ),
    );
  }
}


// ── AI style ────────────────────────────────────────────────────────────

class AiStyleSettingsPage extends StatelessWidget {
  const AiStyleSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    final labels = languageLabels(l);
    return _SettingsPage(title: l.aiStyle, children: [
      _Label(l.researchDepth),
      for (final d in researchDepths)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(
            onTap: () => s.setResearchDepth(d),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: a.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: s.researchDepth == d ? a.accent : a.border, width: s.researchDepth == d ? 1.6 : 1),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(10)),
                  child: Icon(depthIcon(d), size: 19, color: a.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(depthLabel(l, d), style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: a.text)),
                    const SizedBox(height: 2),
                    Text(depthInfo(l, d), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.55)),
                  ]),
                ),
                if (s.researchDepth == d) Icon(Icons.check_circle_rounded, color: a.accent, size: 22),
              ]),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 14, 0),
        child: Text(l.depthHint, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.faint, height: 1.5)),
      ),
      SettingsGroup(title: l.answers, children: [
        SettingsRow(
          icon: Icons.translate_rounded,
          color: AuraHues.amber,
          title: l.defaultAnswerLanguage,
          value: labels[s.answerLanguage],
          onTap: () async {
            final v = await showChoiceDialog(context, title: l.defaultAnswerLanguage, options: labels, selected: s.answerLanguage);
            if (v != null) await s.setAnswerLanguage(v);
          },
        ),
      ]),
    ]);
  }
}

// ── Connection ──────────────────────────────────────────────────────────

class ConnectionSettingsPage extends StatelessWidget {
  const ConnectionSettingsPage({super.key});
  @override
  Widget build(BuildContext context) => _SettingsPage(title: context.l.connection, children: const [SizedBox(height: 8), _ConnectionCard()]);
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard();
  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  late final SettingsController _s = context.read<SettingsController>();
  late final _url = TextEditingController(text: _s.serverUrl);
  late final _token = TextEditingController(text: _s.accessToken);
  late final _key = TextEditingController(text: _s.geminiKey);
  late final _model = TextEditingController(text: _s.modelOverride);
  bool _testing = false;
  String? _result;
  bool _ok = false;
  bool _showKey = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _key.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_s.mode == ConnectionMode.server) {
      await _s.setServerUrl(_url.text);
      await _s.setAccessToken(_token.text);
    } else {
      await _s.setGeminiKey(_key.text);
      await _s.setModelOverride(_model.text);
    }
  }

  Future<void> _test() async {
    await _save();
    setState(() {
      _testing = true;
      _result = null;
    });
    try {
      final model = await _s.backend.check();
      if (!mounted) return;
      setState(() {
        _ok = true;
        _result = context.l.connectionOk(model.isEmpty ? '—' : model);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ok = false;
        _result = errorText(context.l, mapError(e).code);
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _field(TextEditingController c, String label, IconData icon, Color color, {bool obscure = false, String? helper, Widget? suffix, String? hint}) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _save(),
          style: const TextStyle(fontFamily: uiFont),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            prefixIcon: Padding(padding: const EdgeInsets.all(8), child: IconTile(icon: icon, color: color, size: 32)),
            suffixIcon: suffix,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    final server = s.mode == ConnectionMode.server;
    return AuraCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedPills<ConnectionMode>(
          values: const [ConnectionMode.server, ConnectionMode.direct],
          labels: [l.modeServer, l.modeDirect],
          icons: const [Icons.dns_rounded, Icons.key_rounded],
          enabled: [true, s.directAvailable],
          value: s.mode,
          onChanged: (v) {
            s.setMode(v);
            setState(() => _result = null);
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(gradient: a.soft, borderRadius: BorderRadius.circular(16)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(server ? Icons.shield_rounded : Icons.lock_rounded, size: 18, color: a.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(server ? l.modeServerInfo : l.modeDirectInfo, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.6))),
          ]),
        ),
        const SizedBox(height: 16),
        if (server) ...[
          _field(_url, l.serverUrl, Icons.link_rounded, AuraHues.blue, hint: 'https://manabi.example.org'),
          _field(_token, l.accessToken, Icons.vpn_key_rounded, AuraHues.amber, obscure: true),
        ] else ...[
          _field(_key, l.geminiKey, Icons.key_rounded, AuraHues.violet,
              obscure: !_showKey,
              helper: l.geminiKeyHint,
              suffix: IconButton(icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: a.muted), onPressed: () => setState(() => _showKey = !_showKey))),
          _field(_model, l.modelOverride, Icons.memory_rounded, AuraHues.cyan, helper: l.modelOverrideHint),
        ],
        Row(children: [
          GradientButton(
            onTap: _testing ? null : _test,
            icon: Icons.bolt_rounded,
            label: l.testConnection,
            height: 46,
          ),
          const SizedBox(width: 12),
          if (_testing) const TypingDots(),
          if (_result != null)
            Expanded(
              child: Row(children: [
                Icon(_ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 18, color: _ok ? a.success : a.danger),
                const SizedBox(width: 6),
                Expanded(child: Text(_result!, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: _ok ? a.success : a.danger))),
              ]),
            ),
        ]),
      ]),
    );
  }
}


// ── Data ────────────────────────────────────────────────────────────────

class DataSettingsPage extends StatelessWidget {
  const DataSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final catalog = context.read<CatalogService>();
    return _SettingsPage(title: l.dataStorage, children: [
      SettingsGroup(children: [
        SettingsRow(
          icon: Icons.inventory_2_outlined,
          color: AuraHues.teal,
          title: l.dataCatalog,
          subtitle: l.catalogInfo(catalog.books.length, catalog.authors.length, catalog.scannedAt),
        ),
      ]),
      SettingsGroup(children: [
        SettingsRow(
          icon: Icons.delete_sweep_outlined,
          title: l.clearHistory,
          danger: true,
          onTap: () async {
            if (await confirmDialog(context, l.clearHistoryConfirm) && context.mounted) {
              await context.read<ChatController>().clearAll();
            }
          },
        ),
        SettingsRow(
          icon: Icons.restart_alt_rounded,
          title: l.resetSettings,
          danger: true,
          onTap: () async {
            if (await confirmDialog(context, l.resetSettingsConfirm) && context.mounted) {
              await context.read<SettingsController>().resetAll();
            }
          },
        ),
      ]),
    ]);
  }
}

// ── Help, privacy, about ────────────────────────────────────────────────

class _Article extends StatelessWidget {
  const _Article({required this.icon, required this.color, required this.title, required this.body});
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: color.withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 15.5, fontWeight: FontWeight.w700, color: a.text))),
          ]),
          const SizedBox(height: 10),
          Text(body, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.85, color: a.text)),
        ]),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return _SettingsPage(title: l.help, children: [
      _Article(icon: Icons.account_tree_outlined, color: AuraHues.violet, title: l.helpHowTitle, body: l.helpHowBody),
      _Article(icon: Icons.lightbulb_outline_rounded, color: AuraHues.amber, title: l.helpTipsTitle, body: l.helpTipsBody),
      _Article(icon: Icons.format_quote_rounded, color: AuraHues.teal, title: l.helpSourcesTitle, body: l.helpSourcesBody),
      _Article(icon: Icons.balance_rounded, color: AuraHues.rose, title: l.helpLimitsTitle, body: l.helpLimitsBody),
    ]);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return _SettingsPage(title: l.privacyPolicy, children: [
      _Article(icon: Icons.phone_android_rounded, color: AuraHues.green, title: l.privacyStoredTitle, body: l.privacyStoredBody),
      _Article(icon: Icons.send_outlined, color: AuraHues.blue, title: l.privacySentTitle, body: l.privacySentBody),
      _Article(icon: Icons.key_rounded, color: AuraHues.amber, title: l.privacyKeyTitle, body: l.privacyKeyBody),
      _Article(icon: Icons.delete_outline_rounded, color: AuraHues.rose, title: l.privacyDeleteTitle, body: l.privacyDeleteBody),
    ]);
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return _SettingsPage(title: l.aboutUs, children: [
      const SizedBox(height: 8),
      _Card(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
        child: Column(children: [
          const BrandLogo(height: 74),
          const SizedBox(height: 10),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => Text(l.version(snap.data?.version ?? '…'), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted)),
          ),
          const SizedBox(height: 16),
          Text(l.aboutMission, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, height: 1.8, color: a.text, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Text(l.aboutBody, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, height: 1.8, color: a.muted)),
        ]),
      ),
      SettingsGroup(children: [
        SettingsRow(icon: Icons.public_rounded, color: AuraHues.blue, title: 'turath.io', onTap: () => openUrl('https://app.turath.io')),
        SettingsRow(icon: Icons.code_rounded, color: AuraHues.violet, title: 'Nusus SDK', onTap: () => openUrl('https://github.com/mwijanarko1/nusus')),
        SettingsRow(icon: Icons.source_outlined, color: AuraHues.rose, title: l.sourceCode, value: 'GitHub', onTap: () => openUrl('https://github.com/ElyasOmarcodes/Manabi')),
        SettingsRow(
          icon: Icons.article_outlined,
          color: AuraHues.teal,
          title: l.licenses,
          onTap: () => showLicensePage(context: context, applicationName: l.appName, applicationIcon: const Padding(padding: EdgeInsets.all(12), child: BrandLogo(height: 40))),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
        child: Text('${l.aboutCredits}\n${l.disclaimer}', textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.7)),
      ),
    ]);
  }
}
