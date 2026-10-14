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
    home: _Lab(url: q['pdf'] ?? '/scan.pdf', page: int.tryParse(q['page'] ?? '') ?? 1, echo: q['echo'] == '1'),
  ));
}

/// With echo=1 the page reported comes back one lower, the way the reader
/// maps a PDF page to its text page and back.
class _Lab extends StatefulWidget {
  const _Lab({required this.url, required this.page, required this.echo});
  final String url;
  final int page;
  final bool echo;
  @override
  State<_Lab> createState() => _LabState();
}

class _LabState extends State<_Lab> {
  late int _page = widget.page;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: PdfPane(
          url: widget.url,
          page: _page,
          onPage: (n) {
            debugPrint('PAGE $n');
            if (widget.echo) setState(() => _page = n > 1 ? n - 1 : n);
          },
          offset: 0,
          onOffset: (_) {},
          onShowText: () {},
          background: const Color(0xFFEDEDF2),
          bar: Colors.white,
          text: Colors.black87,
          muted: Colors.black54,
          digits: (n) => '$n',
        ),
      );
}
