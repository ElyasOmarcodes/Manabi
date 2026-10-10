import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../state/chat_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/chat_list.dart';
import '../widgets/common.dart';
import 'chat_screen.dart' show languageLabels;
import 'saved_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final labels = languageLabels(l);
    return SafeArea(
      bottom: false,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 40), children: [
        ReadingWidth(
          maxWidth: 760,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            ScreenHeader(icon: Icons.tune_rounded, title: l.settings),
            SectionTitle(l.appearance),
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.theme, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: [
                    ButtonSegment(value: ThemeMode.system, icon: const Icon(Icons.brightness_auto_outlined), label: Text(l.themeSystem)),
                    ButtonSegment(value: ThemeMode.light, icon: const Icon(Icons.light_mode_outlined), label: Text(l.themeLight)),
                    ButtonSegment(value: ThemeMode.dark, icon: const Icon(Icons.dark_mode_outlined), label: Text(l.themeDark)),
                  ],
                  selected: {s.themeMode},
                  onSelectionChanged: (v) => s.setThemeMode(v.first),
                ),
                const SizedBox(height: 18),
                Text(l.interfaceLanguage, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final code in supportedUiLanguages)
                    ChoiceChip(label: Text(labels[code]!), selected: s.uiLanguage == code, onSelected: (_) => s.setUiLanguage(code)),
                ]),
                const SizedBox(height: 18),
                Text(l.arabicTextSize, style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(value: s.arabicScale, min: 0.85, max: 1.5, divisions: 13, label: '${(s.arabicScale * 100).round()}%', onChanged: s.setArabicScale),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Text('إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ', textAlign: TextAlign.center, style: arabicStyle(context, size: 19, scale: s.arabicScale)),
                ),
              ]),
            ),
            SectionTitle(l.answers),
            SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.defaultAnswerLanguage, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final e in labels.entries) ChoiceChip(label: Text(e.value), selected: s.answerLanguage == e.key, onSelected: (_) => s.setAnswerLanguage(e.key)),
                ]),
                const SizedBox(height: 18),
                Text('${l.maxSources}: ${s.maxSources}', style: const TextStyle(fontWeight: FontWeight.w600)),
                Slider(value: s.maxSources.toDouble(), min: 4, max: 16, divisions: 12, label: '${s.maxSources}', onChanged: (v) => s.setMaxSources(v.round())),
              ]),
            ),
            SectionTitle(l.connection),
            const _ConnectionCard(),
            SectionTitle(l.data),
            SoftCard(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: ListTile(
                leading: Icon(Icons.delete_sweep_outlined, color: context.cs.error),
                title: Text(l.clearHistory),
                onTap: () async {
                  if (await confirmDialog(context, l.clearHistoryConfirm) && context.mounted) {
                    await context.read<ChatController>().clearAll();
                  }
                },
              ),
            ),
            SectionTitle(l.about),
            const _AboutCard(),
          ]),
        ),
      ]),
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final server = s.mode == ConnectionMode.server;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedButton<ConnectionMode>(
          segments: [
            ButtonSegment(value: ConnectionMode.server, icon: const Icon(Icons.dns_outlined), label: Text(l.modeServer)),
            ButtonSegment(value: ConnectionMode.direct, icon: const Icon(Icons.key_outlined), label: Text(l.modeDirect), enabled: s.directAvailable),
          ],
          selected: {s.mode},
          onSelectionChanged: (v) {
            s.setMode(v.first);
            setState(() => _result = null);
          },
        ),
        const SizedBox(height: 10),
        Text(server ? l.modeServerInfo : l.modeDirectInfo, style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (server) ...[
          TextField(
            controller: _url,
            keyboardType: TextInputType.url,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l.serverUrl, hintText: 'https://manabi.example.org', prefixIcon: const Icon(Icons.link_rounded)),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _token,
            obscureText: true,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l.accessToken, prefixIcon: const Icon(Icons.vpn_key_outlined)),
            onSubmitted: (_) => _save(),
          ),
        ] else ...[
          TextField(
            controller: _key,
            obscureText: !_showKey,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.geminiKey,
              helperText: l.geminiKeyHint,
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(icon: Icon(_showKey ? Icons.visibility_off_outlined : Icons.visibility_outlined), onPressed: () => setState(() => _showKey = !_showKey)),
            ),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _model,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l.modelOverride, helperText: l.modelOverrideHint, prefixIcon: const Icon(Icons.memory_rounded)),
            onSubmitted: (_) => _save(),
          ),
        ],
        const SizedBox(height: 14),
        Row(children: [
          FilledButton.icon(
            onPressed: _testing ? null : _test,
            icon: _testing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering_rounded),
            label: Text(l.testConnection),
          ),
          const SizedBox(width: 12),
          if (_result != null)
            Expanded(
              child: Row(children: [
                Icon(_ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, size: 18, color: _ok ? context.mc.success : context.cs.error),
                const SizedBox(width: 6),
                Expanded(child: Text(_result!, style: TextStyle(color: _ok ? context.mc.success : context.cs.error))),
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
    final catalog = context.read<CatalogService>();
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const ManabiLogo(size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.appName, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => Text(l.version(snap.data?.version ?? '…'), style: context.tt.labelSmall),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Text(l.aboutBody, style: context.tt.bodyMedium),
        const SizedBox(height: 8),
        Text(l.catalogInfo(catalog.books.length, catalog.authors.length, catalog.scannedAt), style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(spacing: 4, children: [
          TextButton.icon(onPressed: () => openUrl('https://app.turath.io'), icon: const Icon(Icons.public_rounded, size: 18), label: const Text('turath.io')),
          TextButton.icon(onPressed: () => openUrl('https://github.com/mwijanarko1/nusus'), icon: const Icon(Icons.code_rounded, size: 18), label: const Text('Nusus SDK')),
          TextButton.icon(onPressed: () => openUrl('https://github.com/ElyasOmarcodes/Manabi'), icon: const Icon(Icons.source_outlined, size: 18), label: const Text('GitHub')),
        ]),
        const SizedBox(height: 6),
        Text(l.disclaimer, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
      ]),
    );
  }
}
