import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backend/backend.dart';
import '../ui/theme.dart' show appUiFont;
import 'downloads.dart';
import '../core/catalog/catalog_service.dart';

enum ConnectionMode { server, direct }

const supportedUiLanguages = ['ps', 'fa', 'ar', 'en'];

/// Server address baked in at build time (`--dart-define=MANABI_SERVER_URL=…`).
/// Never a secret: the Gemini key lives on the server.
const defaultServerUrl = String.fromEnvironment('MANABI_SERVER_URL');

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs, this._secure, this._catalog);

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  final CatalogService _catalog;

  ThemeMode themeMode = ThemeMode.system;
  String uiLanguage = 'ps';

  /// Always show the first starter questions (for screenshots and tests).
  bool fixedSuggestions = false;
  String answerLanguage = 'auto';
  ConnectionMode mode = ConnectionMode.server;
  String serverUrl = defaultServerUrl;
  String accessToken = '';
  String geminiKey = '';
  String modelOverride = '';
  int maxSources = 12;
  double arabicScale = 1.0;

  /// 'quick', 'standard' or 'deep' – how widely questions are researched.
  String researchDepth = 'standard';

  /// User text size on top of the platform default (phones start smaller).
  double textScale = 1.0;

  ManabiBackend? _backend;

  bool get directAvailable => !kIsWeb;

  static Future<SettingsController> load(CatalogService catalog) async {
    final prefs = await SharedPreferences.getInstance();
    const secure = FlutterSecureStorage();
    final c = SettingsController(prefs, secure, catalog);
    c.themeMode = ThemeMode.values.asNameMap()[prefs.getString('themeMode')] ?? ThemeMode.system;
    final systemLang = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    c.uiLanguage = prefs.getString('uiLanguage') ?? (supportedUiLanguages.contains(systemLang) ? systemLang : 'ps');
    c.answerLanguage = prefs.getString('answerLanguage') ?? 'auto';
    c.fixedSuggestions = prefs.getBool('fixedSuggestions') ?? false;
    c.uiFontFamily = prefs.getString('uiFont') == 'IBMPlexSansArabic' ? 'IBMPlexSansArabic' : 'Vazirmatn';
    appUiFont = c.uiFontFamily;
    c.serverUrl = prefs.getString('serverUrl') ?? defaultServerUrl;
    final savedMode = ConnectionMode.values.asNameMap()[prefs.getString('mode')];
    c.mode = savedMode ?? (c.serverUrl.isEmpty && c.directAvailable ? ConnectionMode.direct : ConnectionMode.server);
    if (!c.directAvailable) c.mode = ConnectionMode.server;
    c.modelOverride = prefs.getString('modelOverride') ?? '';
    c.maxSources = prefs.getInt('maxSources') ?? 12;
    c.arabicScale = prefs.getDouble('arabicScale') ?? 1.0;
    c.researchDepth = prefs.getString('researchDepth') ?? 'standard';
    c.textScale = prefs.getDouble('textScale') ?? 1.0;
    try {
      c.geminiKey = await secure.read(key: 'geminiKey') ?? '';
      c.accessToken = await secure.read(key: 'accessToken') ?? '';
    } catch (_) {
      // Secure storage can be unavailable (e.g. Linux without a keyring).
    }
    return c;
  }

  Locale get locale => Locale(uiLanguage);

  /// The configured backend, reading saved books from the device first.
  ManabiBackend get backend => _backend ??= OfflineFirstBackend(_raw = _createBackend());
  ManabiBackend? _raw;

  ManabiBackend _createBackend() {
    if (mode == ConnectionMode.direct) {
      if (!directAvailable) return const UnconfiguredBackend('DIRECT_NOT_ON_WEB');
      if (geminiKey.trim().isEmpty) return const UnconfiguredBackend('NO_API_KEY');
      return DirectBackend(apiKey: geminiKey.trim(), catalog: _catalog, model: modelOverride.trim().isEmpty ? null : modelOverride.trim());
    }
    if (serverUrl.trim().isEmpty) return const UnconfiguredBackend('SERVER_NOT_CONFIGURED');
    return ServerBackend(serverUrl.trim(), accessToken: accessToken.trim());
  }

  bool get isConfigured {
    backend;
    return _raw is! UnconfiguredBackend;
  }

  void _changed({bool backendChanged = false}) {
    if (backendChanged) _backend = null;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode v) async {
    themeMode = v;
    await _prefs.setString('themeMode', v.name);
    _changed();
  }

  Future<void> setUiLanguage(String v) async {
    uiLanguage = v;
    await _prefs.setString('uiLanguage', v);
    _changed();
  }

  Future<void> setAnswerLanguage(String v) async {
    answerLanguage = v;
    await _prefs.setString('answerLanguage', v);
    _changed();
  }

  Future<void> setMode(ConnectionMode v) async {
    mode = v;
    await _prefs.setString('mode', v.name);
    _changed(backendChanged: true);
  }

  Future<void> setServerUrl(String v) async {
    serverUrl = v.trim();
    await _prefs.setString('serverUrl', serverUrl);
    _changed(backendChanged: true);
  }

  Future<void> setAccessToken(String v) async {
    accessToken = v.trim();
    await _secureWrite('accessToken', accessToken);
    _changed(backendChanged: true);
  }

  Future<void> setGeminiKey(String v) async {
    geminiKey = v.trim();
    await _secureWrite('geminiKey', geminiKey);
    _changed(backendChanged: true);
  }

  Future<void> setModelOverride(String v) async {
    modelOverride = v.trim();
    await _prefs.setString('modelOverride', modelOverride);
    _changed(backendChanged: true);
  }

  Future<void> setMaxSources(int v) async {
    maxSources = v;
    await _prefs.setInt('maxSources', v);
    _changed();
  }

  /// Interface face: 'Vazirmatn' or 'IBMPlexSansArabic'.
  String uiFontFamily = 'Vazirmatn';

  Future<void> setUiFont(String v) async {
    uiFontFamily = v;
    appUiFont = v;
    await _prefs.setString('uiFont', v);
    _changed();
    // Styles name the face directly, so every widget is rebuilt once.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      void rebuild(Element e) {
        e.markNeedsBuild();
        e.visitChildren(rebuild);
      }

      WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
    });
  }

  Future<void> setArabicScale(double v) async {
    arabicScale = v;
    await _prefs.setDouble('arabicScale', v);
    _changed();
  }

  Future<void> setResearchDepth(String v) async {
    researchDepth = v;
    await _prefs.setString('researchDepth', v);
    _changed();
  }

  Future<void> setTextScale(double v) async {
    textScale = v;
    await _prefs.setDouble('textScale', v);
    _changed();
  }

  /// Removes every stored preference and secret (used by "Reset settings").
  Future<void> resetAll() async {
    await _prefs.clear();
    for (final k in ['geminiKey', 'accessToken']) {
      await _secureWrite(k, '');
    }
    themeMode = ThemeMode.system;
    answerLanguage = 'auto';
    serverUrl = defaultServerUrl;
    accessToken = '';
    geminiKey = '';
    modelOverride = '';
    maxSources = 12;
    arabicScale = 1.0;
    researchDepth = 'standard';
    textScale = 1.0;
    mode = serverUrl.isEmpty && directAvailable ? ConnectionMode.direct : ConnectionMode.server;
    _changed(backendChanged: true);
  }

  Future<void> _secureWrite(String key, String value) async {
    try {
      if (value.isEmpty) {
        await _secure.delete(key: key);
      } else {
        await _secure.write(key: key, value: value);
      }
    } catch (_) {
      // Keep the value for this session even if it cannot be persisted.
    }
  }
}
