import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Flutter ships Material and Widgets localizations for Pashto but not
/// Cupertino ones. The few Cupertino strings (text selection menu on iOS)
/// fall back to Persian, the closest supported RTL language.
class PashtoCupertinoFallback extends LocalizationsDelegate<CupertinoLocalizations> {
  const PashtoCupertinoFallback();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ps';

  @override
  Future<CupertinoLocalizations> load(Locale locale) => GlobalCupertinoLocalizations.delegate.load(const Locale('fa'));

  @override
  bool shouldReload(PashtoCupertinoFallback old) => false;
}
