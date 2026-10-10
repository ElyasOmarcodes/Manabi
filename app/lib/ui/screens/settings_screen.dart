import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common.dart';
import '../widgets/depth_picker.dart';
import 'chat_screen.dart' show languageLabels;
import 'settings_pages.dart';

/// Settings home, ChatGPT style: short groups of rows; each row opens its
/// own page or a small dialog.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    final labels = languageLabels(l);
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    final themeName = switch (s.themeMode) {
      ThemeMode.light => l.themeLight,
      ThemeMode.dark => l.themeDark,
      _ => l.themeSystem,
    };
    return AuraPage(
      titleText: l.settings,
      body: ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 28), children: [
        ReadingWidth(
          maxWidth: 680,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
              decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: a.border)),
              child: Column(children: [
                const BrandLogo(height: 58),
                const SizedBox(height: 10),
                Text(l.tagline, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted, height: 1.6)),
              ]),
            ),
            SettingsGroup(title: l.settingsApp, children: [
              SettingsRow(icon: Icons.palette_outlined, color: AuraHues.violet, title: l.appearance, value: themeName, onTap: () => push(const AppearanceSettingsPage())),
              SettingsRow(
                icon: Icons.language_rounded,
                color: AuraHues.blue,
                title: l.interfaceLanguage,
                value: labels[s.uiLanguage],
                onTap: () async {
                  final v = await showChoiceDialog(context,
                      title: l.interfaceLanguage, options: {for (final c in supportedUiLanguages) c: labels[c]!}, selected: s.uiLanguage);
                  if (v != null) await s.setUiLanguage(v);
                },
              ),
            ]),
            SettingsGroup(title: l.settingsAnswersGroup, children: [
              SettingsRow(icon: Icons.auto_awesome_outlined, color: AuraHues.amber, title: l.aiStyle, value: depthLabel(l, s.researchDepth), onTap: () => push(const AiStyleSettingsPage())),
              SettingsRow(
                icon: Icons.cloud_outlined,
                color: AuraHues.teal,
                title: l.connection,
                value: s.mode == ConnectionMode.server ? l.modeServer : l.modeDirect,
                onTap: () => push(const ConnectionSettingsPage()),
              ),
              SettingsRow(icon: Icons.storage_rounded, color: AuraHues.green, title: l.dataStorage, onTap: () => push(const DataSettingsPage())),
            ]),
            SettingsGroup(title: l.settingsInfo, children: [
              SettingsRow(icon: Icons.help_outline_rounded, color: AuraHues.blue, title: l.help, onTap: () => push(const HelpPage())),
              SettingsRow(icon: Icons.privacy_tip_outlined, color: AuraHues.green, title: l.privacyPolicy, onTap: () => push(const PrivacyPage())),
              SettingsRow(icon: Icons.info_outline_rounded, color: AuraHues.violet, title: l.aboutUs, onTap: () => push(const AboutPage())),
            ]),
          ]),
        ),
      ]),
    );
  }
}
