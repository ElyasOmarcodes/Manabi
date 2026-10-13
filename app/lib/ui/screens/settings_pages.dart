import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/turath/arabic_match.dart';
import '../../state/chat_controller.dart';
import '../../state/reading_controller.dart';
import '../../state/catalog_sync.dart';
import '../../state/read_cache.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/chat_list.dart' show confirmDialog;
import '../widgets/common.dart';
import '../widgets/depth_picker.dart';
import 'chat_screen.dart' show languageLabels;
import 'reader_screen.dart' show ModePicker, PaperPicker, ReaderTextControls, bookTextStyle, layeredSpan, readerColors, readerFonts, textLayerRanges;

/// Shared frame of a settings sub-page.
class _SettingsPage extends StatelessWidget {
  const _SettingsPage({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => AuraPage(
    titleText: title,
    body: ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 28),
      children: [
        ReadingWidth(
          maxWidth: 680,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
        ),
      ],
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(14, 20, 14, 8),
    child: Text(
      text,
      style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: context.aura.muted),
    ),
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
      decoration: BoxDecoration(
        color: a.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: a.border),
      ),
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
    return _SettingsPage(
      title: l.appearance,
      children: [
        _Label(l.theme),
        Row(
          children: [
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
          ],
        ),
        _Label(l.appFont),
        Row(
          children: [
            for (final (family, name) in const [('Vazirmatn', 'Vazirmatn'), ('IBMPlexSansArabic', 'IBM Plex Sans Arabic')])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Pressable(
                    onTap: () => s.setUiFont(family),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: s.uiFontFamily == family ? a.accent.withValues(alpha: a.dark ? 0.18 : 0.08) : a.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: s.uiFontFamily == family ? a.accent : a.border, width: s.uiFontFamily == family ? 1.6 : 1),
                      ),
                      child: Column(
                        children: [
                          Text(
                            l.appFontSample,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            style: TextStyle(fontFamily: family, fontSize: 14.5, height: 1.6, color: a.text),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: TextStyle(
                              fontFamily: family,
                              fontSize: 11.5,
                              color: s.uiFontFamily == family ? a.accent : a.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        _Label(l.textSize),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'A',
                    style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted),
                  ),
                  Expanded(
                    child: Slider(value: s.textScale, min: 0.85, max: 1.2, divisions: 7, onChanged: s.setTextScale),
                  ),
                  Text(
                    'A',
                    style: TextStyle(fontFamily: uiFont, fontSize: 20, color: a.muted),
                  ),
                ],
              ),
              Text(
                l.textSizeSample,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.6, color: a.text),
              ),
            ],
          ),
        ),
        _Label(l.arabicTextSize),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'ع',
                    style: TextStyle(fontFamily: arabicFont, fontSize: 14, color: a.muted),
                  ),
                  Expanded(
                    child: Slider(value: s.arabicScale, min: 0.85, max: 1.5, divisions: 13, onChanged: s.setArabicScale),
                  ),
                  Text(
                    'ع',
                    style: TextStyle(fontFamily: arabicFont, fontSize: 22, color: a.muted),
                  ),
                ],
              ),
              Text(
                'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: arabicStyle(context, size: 19, scale: s.arabicScale),
              ),
            ],
          ),
        ),
      ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            height: 10,
            width: 46,
            decoration: BoxDecoration(gradient: a.brand, borderRadius: BorderRadius.circular(6)),
          ),
          const SizedBox(height: 6),
          Container(
            height: 22,
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: t.border),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 8,
            width: 60,
            decoration: BoxDecoration(color: t.border, borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: selected ? a.brand : LinearGradient(colors: [a.border, a.border]),
        ),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(22)),
          child: Column(
            children: [
              SizedBox(
                height: 74,
                child: mode == ThemeMode.system
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          children: [
                            Expanded(child: mock(Aura.light)),
                            Expanded(child: mock(Aura.night)),
                          ],
                        ),
                      )
                    : mock(mode == ThemeMode.dark ? Aura.night : Aura.light),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: selected ? a.accent : a.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, fontSize: 13, color: selected ? a.accent : a.text),
                    ),
                  ),
                ],
              ),
            ],
          ),
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
    return _SettingsPage(
      title: l.aiStyle,
      children: [
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
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(10)),
                      child: Icon(depthIcon(d), size: 19, color: a.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            depthLabel(l, d),
                            style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: a.text),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            depthInfo(l, d),
                            style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.55),
                          ),
                        ],
                      ),
                    ),
                    if (s.researchDepth == d) Icon(Icons.check_circle_rounded, color: a.accent, size: 22),
                  ],
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 2, 14, 0),
          child: Text(
            l.depthHint,
            style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.faint, height: 1.5),
          ),
        ),
        SettingsGroup(
          title: l.answers,
          children: [
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
          ],
        ),
      ],
    );
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
  bool _testing = false;
  String? _result;
  bool _ok = false;
  bool _showKey = false;

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _key.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_s.mode == ConnectionMode.server) {
      await _s.setServerUrl(_url.text);
      await _s.setAccessToken(_token.text);
    } else {
      await _s.setGeminiKey(_key.text);
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

  Widget _field(TextEditingController c, String label, IconData icon, Color color, {bool obscure = false, String? helper, Widget? suffix, String? hint}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          obscureText: obscure,
          autocorrect: false,
          enableSuggestions: false,
          textDirection: TextDirection.ltr,
          onSubmitted: (_) => _save(),
          style: TextStyle(fontFamily: uiFont),
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            helperText: helper,
            prefixIcon: Padding(
              padding: const EdgeInsets.all(8),
              child: IconTile(icon: icon, color: color, size: 32),
            ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedPills<ConnectionMode>(
            values: const [ConnectionMode.server, ConnectionMode.direct],
            labels: [l.modeServer, l.modeDirect],
            icons: const [Icons.dns_rounded, Icons.key_rounded],
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(server ? Icons.shield_rounded : Icons.lock_rounded, size: 18, color: a.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    server ? l.modeServerInfo : l.modeDirectInfo,
                    style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (server) ...[
            _field(_url, l.serverUrl, Icons.link_rounded, AuraHues.blue, hint: 'https://manabi.example.org'),
            _field(_token, l.accessToken, Icons.vpn_key_rounded, AuraHues.amber, obscure: true),
          ] else ...[
            _field(
              _key,
              l.geminiKey,
              Icons.key_rounded,
              AuraHues.violet,
              obscure: !_showKey,
              helper: l.geminiKeyHint,
              suffix: IconButton(
                icon: Icon(_showKey ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: a.muted),
                onPressed: () => setState(() => _showKey = !_showKey),
              ),
            ),
          ],
          Row(
            children: [
              GradientButton(onTap: _testing ? null : _test, icon: Icons.bolt_rounded, label: l.testConnection, height: 46),
              const SizedBox(width: 12),
              if (_testing) const AuraProgress(),
              if (_result != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(_ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 18, color: _ok ? a.success : a.danger),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _result!,
                          style: TextStyle(fontFamily: uiFont, fontSize: 13, color: _ok ? a.success : a.danger),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
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
    return _SettingsPage(
      title: l.dataStorage,
      children: [
        SettingsGroup(
          children: [
            SettingsRow(
              icon: Icons.inventory_2_outlined,
              color: AuraHues.teal,
              title: l.dataCatalog,
              subtitle: l.catalogInfo(catalog.books.length, catalog.authors.length, catalog.scannedAt),
            ),
            Builder(
              builder: (context) {
                final sync = context.watch<CatalogSync>();
                return SettingsRow(
                  icon: Icons.sync_rounded,
                  color: AuraHues.blue,
                  title: l.librarySync,
                  subtitle: l.librarySyncSub,
                  trailing: sync.running ? AuraProgress(value: sync.progress, width: 56, height: 4) : null,
                  onTap: sync.running ? null : () => sync.run(),
                );
              },
            ),
            StatefulBuilder(
              builder: (context, setRow) => SettingsRow(
                icon: Icons.history_edu_outlined,
                color: AuraHues.green,
                title: l.clearReadCache,
                subtitle: l.readCacheInfo('${ReadCache.pageCount}'),
                onTap: ReadCache.pageCount == 0
                    ? null
                    : () async {
                        await ReadCache.clear();
                        setRow(() {});
                      },
              ),
            ),
          ],
        ),
        SettingsGroup(
          children: [
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
          ],
        ),
      ],
    );
  }
}

// ── Reading & library ───────────────────────────────────────────────────

const _sampleText =
    '(قَالَ رَسُولُ اللَّهِ ﷺ: «إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ») أَيْ: صِحَّتُهَا بِالنِّيَّةِ، '
    'قَالَ تَعَالَى: ﴿وَمَا أُمِرُوا إِلَّا لِيَعْبُدُوا اللَّهَ مُخْلِصِينَ لَهُ الدِّينَ﴾.';

/// A small page in the current reader settings: chapter title, a matn in
/// parentheses with its commentary, a verse and a highlight.
class ReaderPreview extends StatelessWidget {
  const ReaderPreview({super.key});
  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final a = context.aura;
    final l = context.l;
    final c = readerColors(context, r.paper);
    final sample = r.hideDiacritics ? stripDiacritics(_sampleText) : _sampleText;
    final base = bookTextStyle(context, r, color: c.text);
    final mark = arabicMatches(sample, 'صحتها بالنية').firstOrNull;
    final ranges = [
      ...textLayerRanges(r, const BookLayers(enabled: true, matn: ['()']), sample, dark: a.dark),
      if (mark != null) (mark.$1, mark.$2, TextStyle(backgroundColor: highlightColors[r.highlightColor].withValues(alpha: a.dark ? 0.38 : 0.45))),
    ];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: a.border),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'بَابُ النِّيَّةِ',
              style: bookTextStyle(context, r, size: 16, weight: FontWeight.w700, color: a.accent).copyWith(height: 1.7),
            ),
            Text.rich(layeredSpan(sample, base, ranges), textAlign: r.justify ? TextAlign.justify : TextAlign.start),
            const SizedBox(height: 4),
            Text(
              '${l.volumeShort} ${readerDigits(1, r.digits)} · ${l.page} ${readerDigits(6, r.digits)}',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: uiFont, fontSize: 12, color: c.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Colour swatches (light/dark pairs) with the chosen one ringed.
class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.selected, required this.onSelect});
  final List<Color> colors;
  final int selected;
  final ValueChanged<int> onSelect;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (var i = 0; i < colors.length; i++)
          Pressable(
            onTap: () => onSelect(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colors[i],
                shape: BoxShape.circle,
                border: Border.all(color: selected == i ? a.text : a.border, width: selected == i ? 2.5 : 1),
              ),
              child: selected == i ? Icon(Icons.check_rounded, color: colors[i].computeLuminance() > 0.5 ? Colors.black87 : Colors.white, size: 19) : null,
            ),
          ),
      ],
    );
  }
}

Widget _switchRow(IconData icon, Color color, String title, bool value, ValueChanged<bool> onChanged, {String? subtitle}) => SettingsRow(
  icon: icon,
  color: color,
  title: title,
  subtitle: subtitle,
  trailing: Switch.adaptive(value: value, onChanged: onChanged),
  onTap: () => onChanged(!value),
);

/// Reading & library hub: a preview, then one row per area.
class ReadingSettingsPage extends StatelessWidget {
  const ReadingSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    final paper = switch (r.paper) {
      'sepia' => l.paperSepia,
      'plain' => l.paperPlain,
      'night' => l.paperNight,
      _ => l.paperWarm,
    };
    final font = readerFonts(l).where((f) => f.$1 == r.fontFamily).firstOrNull?.$3 ?? '';
    return _SettingsPage(
      title: l.readingSettings,
      children: [
        const SizedBox(height: 8),
        const ReaderPreview(),
        SettingsGroup(
          title: l.reader,
          children: [
            SettingsRow(
              icon: Icons.chrome_reader_mode_outlined,
              color: AuraHues.teal,
              title: l.readerDisplay,
              subtitle: '${r.readingMode == 'pages' ? l.modePages : l.modeScroll} · $paper · $font',
              onTap: () => push(const ReaderDisplaySettingsPage()),
            ),
            SettingsRow(
              icon: Icons.format_color_text_rounded,
              color: AuraHues.violet,
              title: l.textFormatting,
              beta: true,
              subtitle: l.textFormattingSub,
              onTap: () => push(const TextFormattingSettingsPage()),
            ),
          ],
        ),
        SettingsGroup(
          title: l.readingData,
          children: [
            SettingsRow(
              icon: Icons.insights_rounded,
              color: AuraHues.blue,
              title: '${l.bookmarks} · ${l.highlights} · ${l.tabFavorites}',
              value: '${r.bookmarks.length} · ${r.highlights.length} · ${r.favorites.length}',
            ),
            SettingsRow(
              icon: Icons.history_toggle_off_rounded,
              title: l.clearReadingHistory,
              danger: true,
              onTap: () async {
                if (await confirmDialog(context, l.clearReadingHistoryConfirm) && context.mounted) await r.clearHistory();
              },
            ),
            SettingsRow(
              icon: Icons.delete_forever_outlined,
              title: l.clearReadingData,
              danger: true,
              onTap: () async {
                if (await confirmDialog(context, l.clearReadingDataConfirm) && context.mounted) await r.clearAll();
              },
            ),
            SettingsRow(icon: Icons.restart_alt_rounded, title: l.resetReader, danger: true, onTap: r.resetDisplay),
          ],
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 14, 14, 0),
          child: Text(
            l.shortcutsHint,
            style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// Page and text: mode, paper, size, face and reading toggles.
class ReaderDisplaySettingsPage extends StatelessWidget {
  const ReaderDisplaySettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    return _SettingsPage(
      title: l.readerDisplay,
      children: [
        const SizedBox(height: 8),
        const ReaderPreview(),
        _Label(l.readingMode),
        ModePicker(reading: r),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 14, 0),
          child: Text(
            r.readingMode == 'pages' ? l.modePagesInfo : l.modeScrollInfo,
            style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.faint, height: 1.5),
          ),
        ),
        _Label(l.paperTheme),
        PaperPicker(reading: r),
        _Label(l.textSize),
        ReaderTextControls(reading: r),
        SettingsGroup(
          title: l.bookFont,
          children: [
            for (final (value, family, name) in readerFonts(l))
              SettingsRow(
                icon: Icons.font_download_outlined,
                color: AuraHues.violet,
                title: name,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'بسم الله الرحمن الرحيم',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontFamily: family, fontSize: 16, height: 1.6, color: a.text),
                    ),
                    const SizedBox(width: 10),
                    Icon(
                      r.fontFamily == value ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: r.fontFamily == value ? a.accent : a.faint,
                      size: 22,
                    ),
                  ],
                ),
                onTap: () => r.setFontFamily(value),
              ),
          ],
        ),
        SettingsGroup(
          title: l.reader,
          children: [
            _switchRow(Icons.format_align_justify_rounded, AuraHues.blue, l.justifyText, r.justify, r.setJustify),
            _switchRow(Icons.text_format_rounded, AuraHues.teal, l.hideDiacritics, r.hideDiacritics, r.setHideDiacritics),
            _switchRow(Icons.notes_rounded, AuraHues.green, l.showFootnotes, r.showFootnotes, r.setShowFootnotes),
            _switchRow(Icons.light_mode_outlined, AuraHues.amber, l.keepScreenOn, r.keepAwake, r.setKeepAwake),
            SettingsRow(
              icon: Icons.pin_outlined,
              color: AuraHues.rose,
              title: l.numberStyle,
              value: r.digits == 'arabic' ? '١٢٣' : '123',
              onTap: () async {
                final v = await showChoiceDialog(
                  context,
                  title: l.numberStyle,
                  options: const {'arabic': '١٢٣ – ٠١٢٣٤٥٦٧٨٩', 'latin': '123 – 0123456789'},
                  selected: r.digits,
                );
                if (v != null) await r.setDigits(v);
              },
            ),
          ],
        ),
      ],
    );
  }
}

/// Verses, matn and highlight colours.
class TextFormattingSettingsPage extends StatelessWidget {
  const TextFormattingSettingsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    final dark = a.dark;
    return _SettingsPage(
      title: l.textFormatting,
      children: [
        const SizedBox(height: 8),
        const ReaderPreview(),
        SettingsGroup(
          title: l.quranSection,
          children: [
            _switchRow(Icons.menu_book_rounded, AuraHues.blue, l.styleQuran, r.styleQuran, r.setStyleQuran),
            SettingsRow(
              icon: Icons.font_download_outlined,
              color: AuraHues.blue,
              title: l.quranFontLabel,
              value: r.quranFont == 'quran' ? l.fontAmiriQuran : l.fontBookFace,
              onTap: () async {
                final v = await showChoiceDialog(
                  context,
                  title: l.quranFontLabel,
                  options: {'quran': l.fontAmiriQuran, 'book': l.fontBookFace},
                  selected: r.quranFont,
                );
                if (v != null) await r.setQuranFont(v);
              },
            ),
          ],
        ),
        _Label(l.quranColorLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _Swatches(colors: [for (final c in quranColors) dark ? c.$2 : c.$1], selected: r.quranColor, onSelect: r.setQuranColor),
        ),
        SettingsGroup(
          title: l.matnSection,
          children: [_switchRow(Icons.format_bold_rounded, AuraHues.rose, l.matnBoldLabel, r.matnBold, r.setMatnBold, subtitle: l.matnSeparate)],
        ),
        _Label(l.matnColorLabel),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _Swatches(colors: [for (final c in matnColors) dark ? c.$2 : c.$1], selected: r.matnColor, onSelect: r.setMatnColor),
        ),
        _Label(l.highlightColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _Swatches(colors: highlightColors, selected: r.highlightColor, onSelect: r.setHighlightColor),
        ),
      ],
    );
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: a.dark ? 0.18 : 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(fontFamily: uiFont, fontSize: 15.5, fontWeight: FontWeight.w700, color: a.text),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.85, color: a.text),
            ),
          ],
        ),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return _SettingsPage(
      title: l.help,
      children: [
        _Article(icon: Icons.account_tree_outlined, color: AuraHues.violet, title: l.helpHowTitle, body: l.helpHowBody),
        _Article(icon: Icons.lightbulb_outline_rounded, color: AuraHues.amber, title: l.helpTipsTitle, body: l.helpTipsBody),
        _Article(icon: Icons.format_quote_rounded, color: AuraHues.teal, title: l.helpSourcesTitle, body: l.helpSourcesBody),
        _Article(icon: Icons.balance_rounded, color: AuraHues.rose, title: l.helpLimitsTitle, body: l.helpLimitsBody),
      ],
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return _SettingsPage(
      title: l.privacyPolicy,
      children: [
        _Article(icon: Icons.phone_android_rounded, color: AuraHues.green, title: l.privacyStoredTitle, body: l.privacyStoredBody),
        _Article(icon: Icons.send_outlined, color: AuraHues.blue, title: l.privacySentTitle, body: l.privacySentBody),
        _Article(icon: Icons.key_rounded, color: AuraHues.amber, title: l.privacyKeyTitle, body: l.privacyKeyBody),
        _Article(icon: Icons.delete_outline_rounded, color: AuraHues.rose, title: l.privacyDeleteTitle, body: l.privacyDeleteBody),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return _SettingsPage(
      title: l.aboutUs,
      children: [
        const SizedBox(height: 8),
        _Card(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 22),
          child: Column(
            children: [
              const AnimatedBrandLogo(height: 74),
              const SizedBox(height: 10),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => Text(
                  l.version(snap.data?.version ?? '…'),
                  style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.aboutMission,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: uiFont, fontSize: 14.5, height: 1.8, color: a.text, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 10),
              Text(
                l.aboutBody,
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: uiFont, fontSize: 13.5, height: 1.8, color: a.muted),
              ),
            ],
          ),
        ),
        SettingsGroup(
          children: [
            SettingsRow(icon: Icons.public_rounded, color: AuraHues.blue, title: 'turath.io', onTap: () => openUrl('https://app.turath.io')),
            SettingsRow(icon: Icons.code_rounded, color: AuraHues.violet, title: 'Nusus SDK', onTap: () => openUrl('https://github.com/mwijanarko1/nusus')),
            SettingsRow(
              icon: Icons.source_outlined,
              color: AuraHues.rose,
              title: l.sourceCode,
              value: 'GitHub',
              onTap: () => openUrl('https://github.com/ElyasOmarcodes/Manabi'),
            ),
            SettingsRow(
              icon: Icons.article_outlined,
              color: AuraHues.teal,
              title: l.licenses,
              onTap: () => showLicensePage(
                context: context,
                applicationName: l.appName,
                applicationIcon: const Padding(padding: EdgeInsets.all(12), child: BrandLogo(height: 40)),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
          child: Text(
            '${l.aboutCredits}\n${l.disclaimer}',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.7),
          ),
        ),
      ],
    );
  }
}
