import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'author_screen.dart';
import 'reader_screen.dart';

void openBook(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => BookScreen(bookId: id)));

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
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final title = entry?.title;
          context.read<NavController>().askWithin(SearchScope.all.withBook(widget.bookId, title));
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: Text(l.askInThisBook),
      ),
      body: AmbientBackground(
        child: FutureBuilder<BookDetails>(
          future: _future,
          builder: (context, snap) {
            final details = snap.data;
            final title = details?.title ?? entry?.title ?? l.book;
            final authorId = details?.authorId ?? entry?.authorId;
            final author = catalog.author(authorId);
            final category = catalog.category(details?.categoryId ?? entry?.categoryId);
            return CustomScrollView(slivers: [
              SliverAppBar.large(
                title: Text(title, maxLines: 2, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 21, weight: FontWeight.w700).copyWith(height: 1.4)),
              ),
              SliverToBoxAdapter(
                child: ReadingWidth(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(spacing: 8, runSpacing: 8, children: [
                      if (author != null)
                        ActionChip(
                          avatar: const Icon(Icons.person_outline_rounded, size: 18),
                          label: Text(author.name),
                          onPressed: () => openAuthor(context, author.id),
                        ),
                      if (category != null) Chip(avatar: const Icon(Icons.category_outlined, size: 18), label: Text(category.title)),
                      ActionChip(
                        avatar: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(l.openLink),
                        onPressed: () => openUrl('https://app.turath.io/book/${widget.bookId}'),
                      ),
                    ]),
                  ),
                ),
              ),
              if (snap.connectionState != ConnectionState.done)
                const SliverFillRemaining(hasScrollBody: false, child: Center(child: TypingDots()))
              else if (snap.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: ErrorPanel(
                    code: mapError(snap.error!).code,
                    onRetry: () => setState(() => _future = context.read<SettingsController>().backend.book(widget.bookId)),
                  ),
                )
              else ...[
                if (details!.description?.trim().isNotEmpty == true)
                  SliverToBoxAdapter(
                    child: ReadingWidth(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          SectionTitle(l.description),
                          SoftCard(
                            child: SelectableText(details.description!.trim(), textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15.5).copyWith(height: 1.9)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                if (details.toc.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: ReadingWidth(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SectionTitle(l.tableOfContents))),
                  ),
                  SliverList.builder(
                    itemCount: details.toc.length,
                    itemBuilder: (context, i) {
                      final e = details.toc[i];
                      return ReadingWidth(
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsetsDirectional.only(start: 16.0 + (e.level - 1).clamp(0, 4) * 18, end: 16),
                            title: Text(e.title, style: arabicStyle(context, size: e.level <= 1 ? 16.5 : 15.5, weight: e.level <= 1 ? FontWeight.w700 : FontWeight.w400).copyWith(height: 1.6)),
                            trailing: e.page == null ? null : Text('${e.page}', style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                            onTap: e.page == null ? null : () => openReader(context, widget.bookId, e.page!, title: details.title),
                          ),
                        ),
                      );
                    },
                  ),
                ] else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(child: FilledButton.tonalIcon(onPressed: () => openReader(context, widget.bookId, 1, title: details.title), icon: const Icon(Icons.chrome_reader_mode_outlined), label: Text(l.readPage))),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ]);
          },
        ),
      ),
    );
  }
}
