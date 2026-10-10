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
    final a = context.aura;
    final scale = context.watch<SettingsController>().arabicScale;
    return AuraPage(
      title: Text(widget.title ?? l.book,
          maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 18, weight: FontWeight.w700).copyWith(height: 1.4)),
      bottom: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Glass(
          radius: 30,
          padding: const EdgeInsets.all(6),
          child: Row(children: [
            // Book pages advance right-to-left: "next" sits on the left.
            Expanded(child: _PageButton(icon: Icons.chevron_left_rounded, label: l.nextPage, onTap: () => _go(_page + 1))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: GradientText('$_page', style: const TextStyle(fontFamily: uiFont, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Expanded(child: _PageButton(icon: Icons.chevron_right_rounded, label: l.previousPage, onTap: _page > 1 ? () => _go(_page - 1) : null, trailingIcon: true)),
          ]),
        ),
      ),
      body: FutureBuilder<PagePassage>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: AuraOrb(size: 80));
          if (snap.hasError) return ErrorPanel(code: mapError(snap.error!).code, onRetry: () => _go(_page));
          final p = snap.data!;
          final highlighted = _page == widget.page ? widget.highlight : null;
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
            ReadingWidth(
              maxWidth: 760,
              child: Reveal(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (p.headings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Directionality(
                        textDirection: TextDirection.rtl,
                        child: Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final (i, h) in p.headings.indexed)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                              decoration: BoxDecoration(color: AuraHues.at(i).withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(20)),
                              child: Text(h, style: arabicStyle(context, size: 13.5, color: AuraHues.at(i), weight: FontWeight.w700).copyWith(height: 1.6)),
                            ),
                        ]),
                      ),
                    ),
                  AuraCard(
                    padding: const EdgeInsets.fromLTRB(26, 22, 26, 22),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Directionality(
                        textDirection: TextDirection.rtl,
                        child: Row(children: [
                          Container(width: 4, height: 28, decoration: BoxDecoration(gradient: a.brand, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              [if (p.authorName != null) p.authorName!, if (p.volume != null) '${l.volume} ${p.volume}', if (p.printedPage != null) '${l.page} ${p.printedPage}'].join('  ·  '),
                              style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      SelectableText.rich(_highlight(context, p.text, highlighted, scale), textDirection: TextDirection.rtl),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    SoftButton(icon: Icons.open_in_new_rounded, label: l.openLink, color: AuraHues.blue, onTap: () => openUrl(p.url)),
                    if (p.shamelaUrl != null) SoftButton(label: l.openShamela, color: AuraHues.mint, onTap: () => openUrl(p.shamelaUrl!)),
                    SoftButton(icon: Icons.copy_rounded, label: l.copy, color: AuraHues.violet, onTap: () => copyText(context, '${p.text}\n\n— ${p.citation ?? p.bookTitle}\n${p.url}')),
                  ]),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  TextSpan _highlight(BuildContext context, String text, String? quote, double scale) {
    final style = arabicStyle(context, size: 20, scale: scale).copyWith(height: 2.15);
    if (quote == null || quote.isEmpty) return TextSpan(text: text, style: style);
    final i = text.indexOf(quote);
    if (i < 0) return TextSpan(text: text, style: style);
    return TextSpan(style: style, children: [
      TextSpan(text: text.substring(0, i)),
      TextSpan(text: quote, style: TextStyle(backgroundColor: AuraHues.violet.withValues(alpha: context.aura.dark ? 0.32 : 0.16))),
      TextSpan(text: text.substring(i + quote.length)),
    ]);
  }
}

class _PageButton extends StatelessWidget {
  const _PageButton({required this.icon, required this.label, this.onTap, this.trailingIcon = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool trailingIcon;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final children = [
      Icon(icon, color: onTap == null ? a.faint : a.accent),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: onTap == null ? a.faint : a.text))),
    ];
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(24)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: trailingIcon ? children.reversed.toList() : children),
      ),
    );
  }
}
