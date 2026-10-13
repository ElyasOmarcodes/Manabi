import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show BrowserContextMenu;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/catalog/catalog_service.dart';
import 'core/storage/app_dirs.dart';
import 'core/storage/chat_store.dart';
import 'l10n/fallback_localizations.dart';
import 'l10n/gen/app_localizations.dart';
import 'state/catalog_sync.dart';
import 'state/chat_controller.dart';
import 'state/downloads.dart';
import 'state/discovered_books.dart';
import 'state/layer_ai.dart';
import 'state/pdf_flags.dart';
import 'state/nav_controller.dart';
import 'state/reading_controller.dart';
import 'state/read_cache.dart';
import 'state/search_history.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';
import 'ui/screens/setup_screen.dart';
import 'state/memory_controller.dart';
import 'ui/screens/splash_screen.dart';
import 'ui/theme.dart';
import 'ui/widgets/visual_arrow_keys.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // On the web a right click opens the app's own menus (the reader's
  // selection menu) instead of the browser's.
  if (kIsWeb) BrowserContextMenu.disableContextMenu();
  runApp(const ManabiApp());
}

class AppServices {
  AppServices(this.catalog, this.settings, this.chats, {required this.sync, this.needsSetup = false, MemoryController? memory})
      : memory = memory ?? MemoryController.inMemory();
  final CatalogService catalog;

  /// What the assistant remembers of the user.
  final MemoryController memory;
  final SettingsController settings;
  final ChatController chats;

  /// Builds and refreshes the library on the device.
  final CatalogSync sync;

  /// First launch: the library is built before the app opens.
  final bool needsSetup;

  static Future<AppServices> load() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 3800));
    final storagePath = await initAppStorage();
    final catalog = await CatalogService.load();
    final settings = await SettingsController.load(catalog);
    final store = await ChatStore.open(init: false);
    await DownloadController.open();
    await PageMatnAi.open();
    await SearchHistory.open();
    await ReadCache.open();
    await DiscoveredBooks.open(catalog);
    await PdfFlags.open(() => settings.backend);
    final sync = CatalogSync(catalog, () => settings.backend, storagePath: storagePath);
    final needsSetup = await CatalogSync.needsSetup();
    // Later launches refresh the shared lists (new books, PDFs) quietly.
    if (!needsSetup) unawaited(sync.startBackground());
    final memory = await MemoryController.load();
    final chats = ChatController(store, () => settings.backend)
      ..modelProvider = (() => settings.chatModel.isEmpty ? null : settings.chatModel)
      ..memoryProvider = (() => memory.forPrompt)
      ..onRemember = (text) {
        if (memory.enabled) memory.add(text);
      };
    await minSplash;
    return AppServices(catalog, settings, chats, sync: sync, needsSetup: needsSetup, memory: memory);
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
              ChangeNotifierProvider.value(value: DownloadController.instance ?? DownloadController.empty()),
              ChangeNotifierProvider.value(value: services.sync),
              ChangeNotifierProvider.value(value: services.memory),
            ],
            child: _App(needsSetup: services.needsSetup),
          );
        },
      );
}

class _App extends StatefulWidget {
  const _App({this.needsSetup = false});
  final bool needsSetup;
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  late bool _setup = widget.needsSetup;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return MaterialApp(
      title: 'Manabi · منابع',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [_DropFocusOnNavigate()],
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
      home: _setup
          ? SetupScreen(
              sync: context.read<CatalogSync>(),
              onDone: () {
                setState(() => _setup = false);
                context.read<CatalogSync>().startBackground();
              },
            )
          : const HomeShell(),
    );
  }
}

/// Leaving or returning to a page drops the keyboard focus, so coming back
/// to the chat (or any page) never raises the keyboard by itself; a tap on
/// a field still focuses it as usual.
class _DropFocusOnNavigate extends NavigatorObserver {
  // On push at once, before the new page's own autofocus; on pop after the
  // page below has taken its focus back.
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => FocusManager.instance.primaryFocus?.unfocus();
  // Only a text field on the page now on top loses its focus: focus that
  // is still in the closing route (or elsewhere) is left alone, so Escape
  // and other keys keep reaching the page below.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => WidgetsBinding.instance.addPostFrameCallback((_) {
        final focus = FocusManager.instance.primaryFocus;
        final ctx = focus?.context;
        if (focus == null || ctx == null || !ctx.mounted) return;
        if (ctx.findAncestorWidgetOfExactType<EditableText>() == null && ctx.widget is! EditableText) return;
        if (ModalRoute.of(ctx) == previousRoute) focus.unfocus();
      });
}
