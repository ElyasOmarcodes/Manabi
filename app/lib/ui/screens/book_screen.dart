import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../state/nav_controller.dart';
import '../../state/reading_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/scope_picker.dart' show categoryIcon;
import 'author_screen.dart';
import 'reader_screen.dart';

void openBook(BuildContext context, String id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookScreen(bookId: id)));

class BookScreen extends StatefulWidget {
  const BookScreen({super.key, required this.bookId});
  final String bookId;
  @override
  State<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends State<BookScreen> {
  late Future<BookDetails> _future = context.read<SettingsController>().backend.book(widget.bookId);

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final entry = catalog.book(widget.bookId);
    final l = context.l;
    final a = context.aura;
    final reading = context.watch<ReadingController>();
    final position = reading.positionOf(widget.bookId);
    final marks = reading.bookmarksOf(widget.bookId);
    void ask() {
      context.read<NavController>().askWithin(SearchScope.all.withBook(widget.bookId, entry?.title).withAuthor(entry?.authorId, catalog.author(entry?.authorId)?.name));
      Navigator.of(context).popUntil((r) => r.isFirst);
    }

    return AuraPage(
      body: FutureBuilder<BookDetails>(
        future: _future,
        builder: (context, snap) {
          final details = snap.data;
          final title = details?.title ?? entry?.title ?? l.book;
          final author = catalog.author(details?.authorId ?? entry?.authorId);
          final category = catalog.category(details?.categoryId ?? entry?.categoryId);
          return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
            ReadingWidth(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Reveal(
                  child: AuraCard(
                    padding: const EdgeInsets.all(20),
                    gradientBorder: true,
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      BookCover(title: title, color: AuraHues.category(category?.id), width: 92, height: 124),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 22, weight: FontWeight.w700).copyWith(height: 1.55)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            if (author != null) SoftButton(dense: true, icon: Icons.person_rounded, label: author.name, color: AuraHues.pink, onTap: () => openAuthor(context, author.id)),
                            if (category != null) SoftButton(dense: true, icon: categoryIcon(category.id), label: category.title, color: AuraHues.mint),
                            SoftButton(dense: true, icon: Icons.open_in_new_rounded, label: l.openLink, color: AuraHues.blue, onTap: () => openUrl('https://app.turath.io/book/${widget.bookId}')),
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: GradientButton(
                      height: 48,
                      icon: Icons.chrome_reader_mode_rounded,
                      label: position == null ? l.readBook : '${l.continueReading} · ${position.page}',
                      onTap: () => openReader(context, widget.bookId, position?.page ?? details?.toc.firstOrNull?.page ?? 1, title: title),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: SoftButton(icon: Icons.manage_search_rounded, label: l.searchInBook, onTap: () => openReader(context, widget.bookId, position?.page ?? 1, title: title, search: true)),
                  ),
                ]),
                const SizedBox(height: 8),
                SoftButton(icon: Icons.auto_awesome_rounded, label: l.askInThisBook, color: AuraHues.violet, onTap: ask),
                if (details != null && (details.pageCount != null || details.volumes.length > 1))
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      if (details.pageCount != null) StatusBadge(icon: Icons.description_outlined, color: AuraHues.teal, label: l.pagesCount(details.pageCount!)),
                      if (details.volumes.length > 1) StatusBadge(icon: Icons.layers_outlined, color: AuraHues.amber, label: '${details.volumes.length} ${l.volumeShort}'),
                    ]),
                  ),
                if (marks.isNotEmpty) ...[
                  SectionLabel(l.bookmarks),
                  AuraCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(children: [
                      for (final b in marks)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.bookmark_rounded, color: AuraHues.rose),
                          title: Text(b.heading ?? title, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15).copyWith(height: 1.5)),
                          subtitle: Text([if (b.volume != null) '${l.volumeShort} ${b.volume}', '${l.page} ${b.printed ?? b.page}'].join(' · '), style: TextStyle(fontFamily: uiFont, fontSize: 12)),
                          onTap: () => openReader(context, widget.bookId, b.page, title: title),
                        ),
                    ]),
                  ),
                ],
                if (snap.connectionState != ConnectionState.done)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: AuraOrb(size: 70)))
                else if (snap.hasError)
                  SizedBox(
                    height: 320,
                    child: ErrorPanel(
                      code: mapError(snap.error!).code,
                      onRetry: () => setState(() => _future = context.read<SettingsController>().backend.book(widget.bookId)),
                    ),
                  )
                else ...[
                  if (details!.description?.trim().isNotEmpty == true) ...[
                    SectionLabel(l.description),
                    Reveal(
                      delay: 60,
                      child: AuraCard(child: SelectableText(details.description!.trim(), textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15.5).copyWith(height: 1.95))),
                    ),
                  ],
                  SectionLabel(l.tableOfContents,
                      trailing: SoftButton(dense: true, icon: Icons.chrome_reader_mode_outlined, label: l.readPage, onTap: () => openReader(context, widget.bookId, details.toc.firstOrNull?.page ?? 1, title: details.title))),
                  if (details.toc.isNotEmpty)
                    Reveal(
                      delay: 120,
                      child: AuraCard(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Column(children: [
                            for (final (i, e) in details.toc.indexed)
                              InkWell(
                                onTap: e.page == null ? null : () => openReader(context, widget.bookId, e.page!, title: details.title, reveal: e.title),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(16.0 + (e.level - 1).clamp(0, 4) * 18, 9, 16, 9),
                                  child: Row(children: [
                                    Container(
                                      width: e.level <= 1 ? 10 : 7,
                                      height: e.level <= 1 ? 10 : 7,
                                      decoration: BoxDecoration(shape: BoxShape.circle, color: e.level <= 1 ? null : a.faint, gradient: e.level <= 1 ? a.brand : null),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(e.title,
                                          style: arabicStyle(context, size: e.level <= 1 ? 16.5 : 15.5, weight: e.level <= 1 ? FontWeight.w700 : FontWeight.w400).copyWith(height: 1.6)),
                                    ),
                                    if (e.page != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(color: AuraHues.at(i).withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(12)),
                                        child: Text('${e.page}', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, fontWeight: FontWeight.w700, color: AuraHues.at(i))),
                                      ),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                ],
              ]),
            ),
          ]);
        },
      ),
    );
  }
}
