import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/answer_card.dart' show QueryChip;
import '../widgets/common.dart';
import '../widgets/scope_picker.dart';
import 'author_screen.dart';
import 'book_screen.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final catalog = context.read<CatalogService>();
    return SafeArea(
      bottom: false,
      child: Column(children: [
        ReadingWidth(
          maxWidth: 900,
          child: PageHeader(
            title: l.library,
            subtitle: '${l.booksCount(catalog.books.length)} · ${catalog.authors.length} ${l.authors}',
            icon: Icons.auto_stories_rounded,
            color: AuraHues.blue,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: ReadingWidth(
            maxWidth: 900,
            child: SegmentedPills<int>(
              values: const [0, 1, 2, 3],
              labels: [l.books, l.authors, l.categories, l.fullTextSearch],
              value: _tab,
              onChanged: (v) => setState(() => _tab = v),
            ),
          ),
        ),
        Expanded(
          child: IndexedStack(index: _tab, children: const [_BooksTab(), _AuthorsTab(), _CategoriesTab(), _FullTextTab()]),
        ),
      ]),
    );
  }
}

EdgeInsets _listPadding(BuildContext context) => EdgeInsets.fromLTRB(10, 4, 10, MediaQuery.paddingOf(context).bottom + 24);

class _BooksTab extends StatefulWidget {
  const _BooksTab();
  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> {
  String _q = '';
  CatalogCategory? _category;

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final books = catalog.findBooks(_q, categoryId: _category?.id, limit: 200);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: ReadingWidth(
          maxWidth: 900,
          child: Row(children: [
            Expanded(child: AuraSearchField(hint: l.searchBooks, onChanged: (v) => setState(() => _q = v))),
            const SizedBox(width: 10),
            AuraChip(
              icon: Icons.tune_rounded,
              color: AuraHues.mint,
              label: _category?.title ?? l.allCategories,
              selected: _category != null,
              onTap: () async {
                final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
                if (c != null) setState(() => _category = c);
              },
              onClear: () => setState(() => _category = null),
            ),
          ]),
        ),
      ),
      Expanded(
        child: books.isEmpty
            ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults)
            : ListView.builder(
                padding: _listPadding(context),
                itemCount: books.length,
                itemBuilder: (context, i) => ReadingWidth(maxWidth: 900, child: BookTile(book: books[i], onTap: () => openBook(context, books[i].id))),
              ),
      ),
    ]);
  }
}

class _AuthorsTab extends StatefulWidget {
  const _AuthorsTab();
  @override
  State<_AuthorsTab> createState() => _AuthorsTabState();
}

class _AuthorsTabState extends State<_AuthorsTab> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final authors = catalog.findAuthors(_q, limit: 200);
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: ReadingWidth(maxWidth: 900, child: AuraSearchField(hint: l.searchAuthors, onChanged: (v) => setState(() => _q = v))),
      ),
      Expanded(
        child: authors.isEmpty
            ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults, color: AuraHues.pink)
            : ListView.builder(
                padding: _listPadding(context),
                itemCount: authors.length,
                itemBuilder: (context, i) => ReadingWidth(maxWidth: 900, child: AuthorTile(author: authors[i], onTap: () => openAuthor(context, authors[i].id))),
              ),
      ),
    ]);
  }
}

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();
  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final a = context.aura;
    return LayoutBuilder(builder: (context, c) {
      final columns = (c.maxWidth / 250).floor().clamp(2, 4);
      return GridView.builder(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.paddingOf(context).bottom + 24),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 128, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: catalog.categories.length,
        itemBuilder: (context, i) {
          final cat = catalog.categories[i];
          final hue = AuraHues.at(i);
          return Reveal(
            delay: (i % 12) * 30,
            child: AuraCard(
              padding: const EdgeInsets.all(14),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CategoryBooks(category: cat, color: hue))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  IconTile(icon: categoryIcon(cat.id), color: hue, size: 40, gradient: true),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: hue.withValues(alpha: a.dark ? 0.18 : 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('${cat.bookCount}', style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w800, color: hue)),
                  ),
                ]),
                const Spacer(),
                Text(cat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 16, weight: FontWeight.w700).copyWith(height: 1.5)),
                Text(l.booksCount(cat.bookCount), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
              ]),
            ),
          );
        },
      );
    });
  }
}

class _CategoryBooks extends StatelessWidget {
  const _CategoryBooks({required this.category, required this.color});
  final CatalogCategory category;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final books = context.read<CatalogService>().findBooks('', categoryId: category.id, limit: 5000);
    final l = context.l;
    return AuraPage(
      title: Row(children: [
        IconTile(icon: categoryIcon(category.id), color: color, size: 38, gradient: true),
        const SizedBox(width: 10),
        Expanded(child: Text(category.title, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 19, weight: FontWeight.w700).copyWith(height: 1.4))),
      ]),
      floating: GradientButton(
        icon: Icons.auto_awesome_rounded,
        label: l.askInCategory,
        onTap: () {
          context.read<NavController>().askWithin(SearchScope.all.withCategory(category.id, category.title));
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 110),
        itemCount: books.length,
        itemBuilder: (context, i) => ReadingWidth(maxWidth: 900, child: BookTile(book: books[i], onTap: () => openBook(context, books[i].id))),
      ),
    );
  }
}

/// Live full-text search across Turath.
class _FullTextTab extends StatefulWidget {
  const _FullTextTab();
  @override
  State<_FullTextTab> createState() => _FullTextTabState();
}

class _FullTextTabState extends State<_FullTextTab> {
  String _q = '';
  final List<PagePassage> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  Future<void> _search({bool more = false}) async {
    if (_q.trim().isEmpty || _loading) return;
    final backend = context.read<SettingsController>().backend;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _page = 0;
      }
    });
    try {
      final r = await backend.search(_q.trim(), page: _page + 1);
      setState(() {
        _items.addAll(r.items);
        _total = r.totalMatches;
        _page = r.page;
      });
    } catch (e) {
      setState(() => _error = mapError(e).code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
        child: ReadingWidth(
          maxWidth: 900,
          child: Row(children: [
            Expanded(child: AuraSearchField(hint: l.searchInText, rtl: true, onChanged: (v) => _q = v, onSubmitted: (_) => _search())),
            const SizedBox(width: 10),
            AuraIconButton(icon: Icons.arrow_upward_rounded, onTap: _search, tooltip: l.fullTextSearch),
          ]),
        ),
      ),
      if (_items.isNotEmpty)
        ReadingWidth(
          maxWidth: 900,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
            child: Align(alignment: AlignmentDirectional.centerStart, child: StatusBadge(label: l.matches(_total), color: AuraHues.cyan, icon: Icons.manage_search_rounded)),
          ),
        ),
      Expanded(
        child: _error != null && _items.isEmpty
            ? ErrorPanel(code: _error, onRetry: _search)
            : _items.isEmpty
                ? (_loading ? const Center(child: AuraOrb(size: 80)) : EmptyState(icon: Icons.travel_explore_rounded, text: l.searchInText, color: AuraHues.cyan))
                : ListView.builder(
                    padding: EdgeInsets.fromLTRB(16, 6, 16, MediaQuery.paddingOf(context).bottom + 24),
                    itemCount: _items.length + (_items.length < _total ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(child: _loading ? const TypingDots() : SoftButton(onTap: () => _search(more: true), label: l.loadMore, icon: Icons.expand_more_rounded)),
                        );
                      }
                      final p = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ReadingWidth(
                          maxWidth: 900,
                          child: AuraCard(
                            padding: const EdgeInsets.all(16),
                            onTap: p.internalPage == null ? () => openUrl(p.url) : () => openReader(context, p.bookId, p.internalPage!, title: p.bookTitle),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Row(children: [
                                  BookCover(title: p.bookTitle, seed: int.tryParse(p.categoryId ?? '') ?? i, width: 34, height: 44),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text(p.bookTitle, style: arabicStyle(context, size: 16, weight: FontWeight.w700).copyWith(height: 1.5)),
                                      Text(p.citation ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
                                    ]),
                                  ),
                                ]),
                                const SizedBox(height: 8),
                                Text(p.snippet ?? p.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 16).copyWith(height: 1.95)),
                                if (p.headings.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: AlignmentDirectional.centerStart, child: QueryChip(p.headings.last))),
                              ]),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    ]);
  }
}
