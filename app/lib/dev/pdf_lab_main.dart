// Development only: the PDF viewer alone, for timing it against a slowed
// range server.  flutter build web -t lib/dev/pdf_lab_main.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../l10n/gen/app_localizations.dart';
import '../ui/theme.dart';
import '../ui/widgets/pdf_pane.dart';

void main() {
  final q = Uri.base.queryParameters;
  runApp(MaterialApp(
    theme: buildTheme(Brightness.light),
    locale: const Locale('ps'),
    localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: PdfPane(
        url: q['pdf'] ?? '/scan.pdf',
        page: int.tryParse(q['page'] ?? '') ?? 1,
        onPage: (n) => debugPrint('PAGE $n'),
        offset: 0,
        onOffset: (_) {},
        onShowText: () {},
        background: const Color(0xFFEDEDF2),
        bar: Colors.white,
        text: Colors.black87,
        muted: Colors.black54,
        digits: (n) => '$n',
      ),
    ),
  ));
}
