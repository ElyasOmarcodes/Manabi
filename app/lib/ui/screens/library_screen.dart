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
import '../widgets/answer_card.dart' show QueryChip;
import '../widgets/common.dart';
import '../widgets/scope_picker.dart';
import 'author_screen.dart';
import 'book_screen.dart';
import 'reader_screen.dart';

enum _Tab { books, authors, categories, fullText }

/// Library home: search, filter pills, overview cards and results.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _Tab _tab = _Tab.books;
  String _q = '';
  CatalogCategory? _category;
  CatalogAuthor? _author;
  CatalogBook? _book;
  String _sort = 'relevance';

  bool get _filtered => _category != null || _author != null || _book != null;

  SearchScope get _scope => SearchScope(
        bookId: _book?.id,
        bookTitle: _book?.title,
        authorId: _author?.id,
        authorName: _author?.name,
        categoryId: _category?.id,
        categoryTitle: _category?.title,
      );

  void _rerunFullText() {
    if (_tab == _Tab.fullText && _q.trim().isNotEmpty) _fullText.currentState?.search(_q, scope: _scope);
  }
  final _search = TextEditingController();
  final _fullText = GlobalKey<_FullTextState>();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final hint = switch (_tab) {
      _Tab.books => l.searchBooks,
      _Tab.authors => l.searchAuthors,
      _Tab.categories => l.categories,
      _Tab.fullText => l.searchInText,
    };
    return AuraPage(
      titleText: l.library,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(
          child: ReadingWidth(
            maxWidth: 900,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                AuraSearchField(
                  controller: _search,
                  hint: hint,
                  rtl: _tab == _Tab.fullText,
                  onChanged: (v) => setState(() => _q = v),
                  onSubmitted: (_) {
                    if (_tab == _Tab.fullText) _fullText.currentState?.search(_q, scope: _scope);
                  },
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    for (final (t, label, icon) in [
                      (_Tab.books, l.books, Icons.menu_book_rounded),
                      (_Tab.authors, l.authors, Icons.person_rounded),
                      (_Tab.categories, l.categories, Icons.category_rounded),
                      (_Tab.fullText, l.fullTextSearch, Icons.manage_search_rounded),
                    ])
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: AuraChip(
                          icon: icon,
                          label: label,
                          selected: _tab == t,
                          onTap: () => setState(() {
                            _tab = t;
                            _q = '';
                            _search.clear();
                          }),
                        ),
                      ),
                  ]),
                ),
                if (_tab == _Tab.books || _tab == _Tab.fullText) _filterBar(context),
              ]),
            ),
          ),
        ),
        ...switch (_tab) {
          _Tab.books => _booksSlivers(context),
          _Tab.authors => _authorsSlivers(context),
          _Tab.categories => [_categoriesSliver(context)],
          _Tab.fullText => [SliverFillRemaining(hasScrollBody: true, child: _FullText(key: _fullText, query: _q, scope: _scope))],
        },
        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ]),
    );
  }

  List<Widget> _booksSlivers(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final reading = context.watch<ReadingController>();
    final home = _q.isEmpty && !_filtered;
    final books = catalog.findBooks(_q, authorId: _author?.id, categoryId: _category?.id, limit: home ? 60 : 400);
    if (_sort == 'title') books.sort((x, y) => x.title.compareTo(y.title));
    if (_sort == 'author') books.sort((x, y) => (catalog.author(x.authorId)?.name ?? '').compareTo(catalog.author(y.authorId)?.name ?? ''));
    return [
      if (!home)
        SliverToBoxAdapter(
          child: ReadingWidth(
            maxWidth: 900,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 4),
              child: Text(l.matches(books.length), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: context.aura.muted)),
            ),
          ),
        ),
      if (home)
        SliverToBoxAdapter(
          child: ReadingWidth(
            maxWidth: 900,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _Hero(),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: StatTile(value: '${catalog.books.length}', label: l.books, icon: Icons.menu_book_rounded, color: AuraHues.teal)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(value: '${catalog.authors.length}', label: l.authors, icon: Icons.person_rounded, color: AuraHues.amber)),
                  const SizedBox(width: 10),
                  Expanded(child: StatTile(value: '${catalog.categories.length}', label: l.categories, icon: Icons.category_rounded, color: AuraHues.rose)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FeatureCard(
                      icon: Icons.category_rounded,
                      title: l.browseCategories,
                      subtitle: l.browseCategoriesSub,
                      color: AuraHues.blue,
                      onTap: () => setState(() => _tab = _Tab.categories),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FeatureCard(
                      icon: Icons.manage_search_rounded,
                      title: l.fullTextSearch,
                      subtitle: l.fullTextSub,
                      color: AuraHues.green,
                      onTap: () => setState(() => _tab = _Tab.fullText),
                    ),
                  ),
                ]),
                if (reading.recent.isNotEmpty || reading.bookmarks.isNotEmpty) ...[
                  SectionLabel(l.continueReading,
                      trailing: reading.bookmarks.isEmpty
                          ? null
                          : SoftButton(
                              dense: true,
                              icon: Icons.bookmarks_outlined,
                              label: '${l.bookmarks} (${reading.bookmarks.length})',
                              color: AuraHues.rose,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookmarksScreen())),
                            )),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: reading.recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, i) {
                        final p = reading.recent[i];
                        final entry = catalog.book(p.bookId);
                        return Pressable(
                          onTap: () => openReader(context, p.bookId, p.page, title: p.bookTitle),
                          child: Container(
                            width: 250,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: context.aura.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.aura.border)),
                            child: Row(children: [
                              BookCover(title: p.bookTitle, color: AuraHues.category(entry?.categoryId), width: 46, height: 64),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Text(p.bookTitle, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 14.5, weight: FontWeight.w700).copyWith(height: 1.5)),
                                  Text('${l.turathPage} ${p.page}', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: context.aura.muted)),
                                ]),
                              ),
                            ]),
                          ),
                        );
                      },
                    ),
                  ),
                ],
                SectionLabel(l.allBooks),
              ]),
            ),
          ),
        ),
      if (books.isEmpty)
        SliverToBoxAdapter(child: SizedBox(height: 280, child: EmptyState(icon: Icons.search_off_rounded, text: l.noResults)))
      else
        SliverList.builder(
          itemCount: books.length,
          itemBuilder: (context, i) => ReadingWidth(
            maxWidth: 900,
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: BookTile(book: books[i], onTap: () => openBook(context, books[i].id))),
          ),
        ),
    ];
  }

  /// Filter chips: category, author, book (full text) and sort (books).
  Widget _filterBar(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    Widget chip(String label, IconData icon, bool active, VoidCallback onTap, {VoidCallback? onClear}) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Pressable(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 8, 6),
              decoration: BoxDecoration(
                color: active ? a.accentTint : a.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: active ? a.accent.withValues(alpha: 0.5) : a.border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 15, color: active ? a.accent : a.muted),
                const SizedBox(width: 5),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? a.accent : a.text)),
                ),
                const SizedBox(width: 2),
                if (active && onClear != null)
                  GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 15, color: a.accent))
                else
                  Icon(Icons.expand_more_rounded, size: 16, color: a.muted),
              ]),
            ),
          ),
        );
    final sortLabel = switch (_sort) { 'title' => l.sortTitle, 'author' => l.sortAuthor, _ => l.sortRelevance };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          Padding(padding: const EdgeInsetsDirectional.only(end: 6), child: Icon(Icons.tune_rounded, size: 18, color: a.muted)),
          chip(_category?.title ?? l.anyCategory, Icons.category_outlined, _category != null, () async {
            final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
            if (c != null) setState(() => _category = c);
            _rerunFullText();
          }, onClear: () {
            setState(() => _category = null);
            _rerunFullText();
          }),
          chip(_author?.name ?? l.anyAuthor, Icons.person_outline_rounded, _author != null, () async {
            final x = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
            if (x != null) setState(() => _author = x);
            _rerunFullText();
          }, onClear: () {
            setState(() => _author = null);
            _rerunFullText();
          }),
          if (_tab == _Tab.fullText)
            chip(_book?.title ?? l.anyBook, Icons.menu_book_outlined, _book != null, () async {
              final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: _author?.id, categoryId: _category?.id);
              if (b != null) setState(() => _book = b);
              _rerunFullText();
            }, onClear: () {
              setState(() => _book = null);
              _rerunFullText();
            }),
          if (_tab == _Tab.books)
            PopupMenuButton<String>(
              onSelected: (v) => setState(() => _sort = v),
              itemBuilder: (_) => [
                for (final (v, label) in [('relevance', l.sortRelevance), ('title', l.sortTitle), ('author', l.sortAuthor)])
                  CheckedPopupMenuItem(value: v, checked: _sort == v, child: Text(label, style: const TextStyle(fontFamily: uiFont))),
              ],
              child: IgnorePointer(child: chip('${l.sortBy}: $sortLabel', Icons.sort_rounded, _sort != 'relevance', () {})),
            ),
        ]),
      ),
    );
  }

  List<Widget> _authorsSlivers(BuildContext context) {
    final authors = context.read<CatalogService>().findAuthors(_q, limit: 200);
    if (authors.isEmpty) return [SliverToBoxAdapter(child: SizedBox(height: 280, child: EmptyState(icon: Icons.search_off_rounded, text: context.l.noResults)))];
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverList.builder(
        itemCount: authors.length,
        itemBuilder: (context, i) => ReadingWidth(
          maxWidth: 900,
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: AuthorTile(author: authors[i], onTap: () => openAuthor(context, authors[i].id))),
        ),
      ),
    ];
  }

  Widget _categoriesSliver(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final a = context.aura;
    final q = normalizeForSearch(_q);
    final cats = catalog.categories.where((c) => q.isEmpty || normalizeForSearch(c.title).contains(q)).toList();
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      sliver: SliverLayoutBuilder(builder: (context, constraints) {
        final columns = (constraints.crossAxisExtent / 240).floor().clamp(2, 4);
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 118, crossAxisSpacing: 10, mainAxisSpacing: 10),
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final cat = cats[i];
            final color = AuraHues.category(cat.id);
            return Pressable(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryBooksScreen(category: cat))),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(22), border: Border.all(color: a.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    IconTile(icon: categoryIcon(cat.id), color: color, size: 36),
                    const Spacer(),
                    Text('${cat.bookCount}', style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w800, color: a.faint)),
                  ]),
                  const Spacer(),
                  Text(cat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.5)),
                  Text(l.booksCount(cat.bookCount), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
                ]),
              ),
            );
          },
        );
      }),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      decoration: BoxDecoration(
        gradient: a.brand,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.32), blurRadius: 30, offset: const Offset(0, 14), spreadRadius: -12)],
      ),
      child: Stack(children: [
        PositionedDirectional(
          end: -10,
          bottom: -18,
          child: Icon(Icons.auto_stories_rounded, size: 120, color: Colors.white.withValues(alpha: 0.13)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 6),
            Text('turath.io', style: TextStyle(fontFamily: uiFont, color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(l.libraryHeroTitle, style: const TextStyle(fontFamily: uiFont, color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, height: 1.35)),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(l.libraryHeroBody, style: TextStyle(fontFamily: uiFont, color: Colors.white.withValues(alpha: 0.9), fontSize: 14, height: 1.7)),
          ),
        ]),
      ]),
    );
  }
}

class CategoryBooksScreen extends StatelessWidget {
  const CategoryBooksScreen({super.key, required this.category});
  final CatalogCategory category;
  @override
  Widget build(BuildContext context) {
    final books = context.read<CatalogService>().findBooks('', categoryId: category.id, limit: 5000);
    final l = context.l;
    final color = AuraHues.category(category.id);
    return AuraPage(
      title: Row(children: [
        IconTile(icon: categoryIcon(category.id), color: color, size: 36),
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
class _FullText extends StatefulWidget {
  const _FullText({super.key, required this.query, this.scope = SearchScope.all});
  final String query;
  final SearchScope scope;
  @override
  State<_FullText> createState() => _FullTextState();
}

class _FullTextState extends State<_FullText> {
  final List<PagePassage> _items = [];
  String _q = '';
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  SearchScope _scope = SearchScope.all;

  Future<void> search(String q, {bool more = false, SearchScope? scope}) async {
    if (scope != null) _scope = scope;
    if (q.trim().isEmpty || _loading) return;
    final backend = context.read<SettingsController>().backend;
    setState(() {
      _q = q.trim();
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _page = 0;
      }
    });
    try {
      final r = await backend.search(_q, page: _page + 1, scope: _scope);
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
    if (_error != null && _items.isEmpty) return ErrorPanel(code: _error, onRetry: () => search(widget.query));
    if (_items.isEmpty) {
      return _loading ? const Center(child: TypingDots()) : EmptyState(icon: Icons.manage_search_rounded, text: l.fullTextSub, color: AuraHues.green);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: _items.length + 1,
      itemBuilder: (context, i) {
        if (i == _items.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _items.length >= _total
                  ? Text(l.matches(_total), style: TextStyle(fontFamily: uiFont, color: a.faint))
                  : _loading
                      ? const TypingDots()
                      : SoftButton(onTap: () => search(_q, more: true), label: l.loadMore, icon: Icons.expand_more_rounded),
            ),
          );
        }
        final p = _items[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: ReadingWidth(
            maxWidth: 900,
            child: AuraCard(
              padding: const EdgeInsets.all(16),
              onTap: p.internalPage == null ? () => openUrl(p.url) : () => openReader(context, p.bookId, p.internalPage!, title: p.bookTitle, highlight: _q),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    BookCover(title: p.bookTitle, color: AuraHues.category(p.categoryId), width: 32, height: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.bookTitle, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.5)),
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
    );
  }
}

/// Every bookmarked page, newest first.
class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final reading = context.watch<ReadingController>();
    final marks = reading.bookmarks;
    return AuraPage(
      titleText: l.bookmarks,
      body: marks.isEmpty
          ? EmptyState(icon: Icons.bookmarks_outlined, text: l.bookmarks, color: AuraHues.rose)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
              itemCount: marks.length,
              itemBuilder: (context, i) {
                final b = marks[i];
                return ReadingWidth(
                  maxWidth: 800,
                  child: Dismissible(
                    key: ValueKey('${b.bookId}-${b.page}'),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) => reading.toggleBookmark(b),
                    child: ListTile(
                      leading: const Icon(Icons.bookmark_rounded, color: AuraHues.rose),
                      title: Text(b.bookTitle, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.5)),
                      subtitle: Text([if (b.heading != null) b.heading!, if (b.volume != null) '${l.volumeShort} ${b.volume}', '${l.page} ${b.printed ?? b.page}'].join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: uiFont, fontSize: 12.5)),
                      onTap: () => openReader(context, b.bookId, b.page, title: b.bookTitle),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
