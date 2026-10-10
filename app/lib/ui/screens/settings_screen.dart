import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../state/chat_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/chat_list.dart' show confirmDialog;
import '../widgets/common.dart';
import 'chat_screen.dart' show languageLabels;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    final labels = languageLabels(l);
    return AuraPage(
      title: Text(l.settings, style: TextStyle(fontFamily: uiFont, fontSize: 20, fontWeight: FontWeight.w800, color: context.aura.text)),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 30), children: [
        ReadingWidth(
          maxWidth: 760,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SectionLabel(l.theme),
            Row(children: [
              for (final (mode, label, icon) in [
                (ThemeMode.system, l.themeSystem, Icons.brightness_auto_rounded),
                (ThemeMode.light, l.themeLight, Icons.light_mode_rounded),
                (ThemeMode.dark, l.themeDark, Icons.dark_mode_rounded),
              ])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: _ThemeCard(mode: mode, label: label, icon: icon, selected: s.themeMode == mode, onTap: () => s.setThemeMode(mode)),
                  ),
                ),
            ]),
            SectionLabel(l.interfaceLanguage),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final code in supportedUiLanguages) AuraChip(label: labels[code]!, selected: s.uiLanguage == code, onTap: () => s.setUiLanguage(code)),
            ]),
            SectionLabel(l.answers),
            AuraCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  const IconTile(icon: Icons.translate_rounded, color: AuraHues.orange),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.defaultAnswerLanguage, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: a.text))),
                ]),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in labels.entries) AuraChip(label: e.value, selected: s.answerLanguage == e.key, onTap: () => s.setAnswerLanguage(e.key)),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  const IconTile(icon: Icons.library_books_rounded, color: AuraHues.blue),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.maxSources, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: a.text))),
                  GradientText('${s.maxSources}', style: const TextStyle(fontFamily: uiFont, fontSize: 20, fontWeight: FontWeight.w800)),
                ]),
                Slider(value: s.maxSources.clamp(4, 14).toDouble(), min: 4, max: 14, divisions: 10, onChanged: (v) => s.setMaxSources(v.round())),
                Row(children: [
                  const IconTile(icon: Icons.text_fields_rounded, color: AuraHues.violet),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.arabicTextSize, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: a.text))),
                  Text('${(s.arabicScale * 100).round()}%', style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: a.accent)),
                ]),
                Slider(value: s.arabicScale, min: 0.85, max: 1.5, divisions: 13, onChanged: s.setArabicScale),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(gradient: a.soft, borderRadius: BorderRadius.circular(18)),
                  child: Text('إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', textAlign: TextAlign.center, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 19, scale: s.arabicScale)),
                ),
              ]),
            ),
            SectionLabel(l.connection),
            const _ConnectionCard(),
            SectionLabel(l.data),
            TileGroup(children: [
              AuraTile(
                icon: Icons.delete_sweep_rounded,
                color: AuraHues.rose,
                title: l.clearHistory,
                titleStyle: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w600, color: a.danger),
                onTap: () async {
                  if (await confirmDialog(context, l.clearHistoryConfirm) && context.mounted) {
                    await context.read<ChatController>().clearAll();
                  }
                },
              ),
            ]),
            SectionLabel(l.about),
            const _AboutCard(),
          ]),
        ),
      ]),
    );
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

class _AboutCard extends StatelessWidget {
  const _AboutCard();
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    return AuraCard(
      gradientBorder: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const ManabiMark(size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GradientText(l.appName, style: const TextStyle(fontFamily: uiFont, fontSize: 22, fontWeight: FontWeight.w800, height: 1.3)),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => Text(l.version(snap.data?.version ?? '…'), style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Text(l.aboutBody, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.8, color: a.text)),
        const SizedBox(height: 10),
        StatusBadge(icon: Icons.inventory_2_rounded, color: AuraHues.cyan, label: l.catalogInfo(catalog.books.length, catalog.authors.length, catalog.scannedAt)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          SoftButton(dense: true, icon: Icons.public_rounded, label: 'turath.io', color: AuraHues.blue, onTap: () => openUrl('https://app.turath.io')),
          SoftButton(dense: true, icon: Icons.code_rounded, label: 'Nusus SDK', color: AuraHues.violet, onTap: () => openUrl('https://github.com/mwijanarko1/nusus')),
          SoftButton(dense: true, icon: Icons.source_rounded, label: 'GitHub', color: AuraHues.pink, onTap: () => openUrl('https://github.com/ElyasOmarcodes/Manabi')),
        ]),
        const SizedBox(height: 12),
        Text(l.disclaimer, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.6)),
      ]),
    );
  }
}
