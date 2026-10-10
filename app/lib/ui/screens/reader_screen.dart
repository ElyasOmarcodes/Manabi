import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/models/library.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

void openReader(BuildContext context, String bookId, int page, {String? title, String? highlight}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId, page: page, title: title, highlight: highlight)));
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.bookId, required this.page, this.title, this.highlight});
  final String bookId;
  final int page;
  final String? title;
  final String? highlight;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _page = widget.page;
  late Future<PagePassage> _future = _load();

  Future<PagePassage> _load() => context.read<SettingsController>().backend.page(widget.bookId, _page);

  void _go(int page) {
    if (page < 1) return;
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final scale = context.watch<SettingsController>().arabicScale;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? l.book, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 18, weight: FontWeight.w700).copyWith(height: 1.4)),
      ),
      body: AmbientBackground(
        child: FutureBuilder<PagePassage>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return const Center(child: TypingDots());
            if (snap.hasError) return ErrorPanel(code: mapError(snap.error!).code, onRetry: () => _go(_page));
            final p = snap.data!;
            final highlighted = _page == widget.page ? widget.highlight : null;
            return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
              ReadingWidth(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (p.headings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final h in p.headings)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              decoration: BoxDecoration(color: context.mc.glow, borderRadius: BorderRadius.circular(20)),
                              child: Text(h, style: arabicStyle(context, size: 13.5).copyWith(height: 1.6, color: context.cs.primary)),
                            ),
                        ]),
                      ),
                    ),
                  SoftCard(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Text(
                          [if (p.authorName != null) p.authorName!, if (p.volume != null) '${l.volume} ${p.volume}', if (p.printedPage != null) '${l.page} ${p.printedPage}'].join(' · '),
                          style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SelectableText.rich(_highlight(context, p.text, highlighted, scale), textDirection: TextDirection.rtl),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(onPressed: () => openUrl(p.url), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: Text(l.openLink)),
                    if (p.shamelaUrl != null) OutlinedButton(onPressed: () => openUrl(p.shamelaUrl!), child: Text(l.openShamela)),
                    OutlinedButton.icon(
                      onPressed: () => copyText(context, '${p.text}\n\n— ${p.citation ?? p.bookTitle}\n${p.url}'),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(l.copy),
                    ),
                  ]),
                ]),
              ),
            ]);
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Row(children: [
            Expanded(
              child: FilledButton.tonalIcon(
                // Book pages advance right-to-left: "next" sits on the left.
                onPressed: () => _go(_page + 1),
                icon: const Icon(Icons.chevron_left_rounded),
                label: Text(l.nextPage),
              ),
            ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Text('${l.turathPage} $_page', style: context.tt.labelLarge)),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _page > 1 ? () => _go(_page - 1) : null,
                icon: const Icon(Icons.chevron_right_rounded),
                label: Text(l.previousPage),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  TextSpan _highlight(BuildContext context, String text, String? quote, double scale) {
    final style = arabicStyle(context, size: 19, scale: scale);
    if (quote == null || quote.isEmpty) return TextSpan(text: text, style: style);
    final i = text.indexOf(quote);
    if (i < 0) return TextSpan(text: text, style: style);
    return TextSpan(style: style, children: [
      TextSpan(text: text.substring(0, i)),
      TextSpan(text: quote, style: TextStyle(backgroundColor: context.mc.gold.withValues(alpha: 0.28))),
      TextSpan(text: text.substring(i + quote.length)),
    ]);
  }
}
