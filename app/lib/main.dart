import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/catalog/catalog_service.dart';
import 'core/storage/chat_store.dart';
import 'l10n/fallback_localizations.dart';
import 'l10n/gen/app_localizations.dart';
import 'state/chat_controller.dart';
import 'state/nav_controller.dart';
import 'state/reading_controller.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/visual_arrow_keys.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ManabiApp());
}

class AppServices {
  AppServices(this.catalog, this.settings, this.chats);
  final CatalogService catalog;
  final SettingsController settings;
  final ChatController chats;

  static Future<AppServices> load() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 3800));
    final catalog = await CatalogService.load();
    final settings = await SettingsController.load(catalog);
    final store = await ChatStore.open();
    final chats = ChatController(store, () => settings.backend);
    await minSplash;
    return AppServices(catalog, settings, chats);
  }
}

class ManabiApp extends StatefulWidget {
  const ManabiApp({super.key, this.services});

  /// Injected in tests.
  final Future<AppServices>? services;

  @override
  State<ManabiApp> createState() => _ManabiAppState();
}

class _ManabiAppState extends State<ManabiApp> {
  late final Future<AppServices> _services = widget.services ?? AppServices.load();

  @override
  Widget build(BuildContext context) => FutureBuilder<AppServices>(
        future: _services,
        builder: (context, snap) {
          final services = snap.data;
          if (services == null) {
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              locale: const Locale('ps'),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                PashtoCupertinoFallback(),
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Builder(builder: (context) => SplashScreen(tagline: snap.hasError ? '${snap.error}' : AppLocalizations.of(context).tagline)),
            );
          }
          return MultiProvider(
            providers: [
              Provider.value(value: services.catalog),
              ChangeNotifierProvider.value(value: services.settings),
              ChangeNotifierProvider.value(value: services.chats),
              ChangeNotifierProvider(create: (_) => NavController()),
              ChangeNotifierProvider(create: (_) => ReadingController()..load()),
            ],
            child: const _App(),
          );
        },
      );
}

class _App extends StatelessWidget {
  const _App();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'Manabi · منابع',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: settings.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 350),
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        PashtoCupertinoFallback(),
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) {
        final l = AppLocalizations.of(context);
        context.read<ChatController>().keepAliveLabels = (title: l.appName, text: l.keepAliveText);
        // Phones get a slightly more compact type scale; the user can adjust it in Appearance.
        final mq = MediaQuery.of(context);
        final base = mq.textScaler.scale(100) / 100;
        final phone = mq.size.shortestSide < 600;
        return MediaQuery(data: mq.copyWith(textScaler: TextScaler.linear(base * (phone ? 0.9 : 1.0) * settings.textScale)), child: VisualArrowKeys(child: child!));
      },
      home: const HomeShell(),
    );
  }
}
