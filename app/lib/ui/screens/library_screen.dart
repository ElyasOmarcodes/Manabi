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
import '../widgets/chat_list.dart' show confirmDialog;
import '../widgets/common.dart';
import '../widgets/scope_picker.dart';
import 'author_screen.dart';
import 'book_screen.dart';
import 'reader_screen.dart';

enum _Tab { books, favorites, authors, categories, search }

_Tab _tabFrom(String name) => _Tab.values.firstWhere((t) => t.name == name, orElse: () => _Tab.books);

/// Library home in the Turath layout: tabs for all books, favourites,
/// authors, categories and full-text search, a search field with the
/// result count, and compact book rows with info and favourite actions.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late _Tab _tab = _tabFrom(context.read<ReadingController>().libraryTab);
  String _q = '';
  CatalogCategory? _category;
  CatalogAuthor? _author;
  CatalogBook? _book;
  String _sort = 'relevance';
  final _openAuthors = <String>{};
  final _openCategories = <String>{};
  final _search = TextEditingController();
  final _fullText = GlobalKey<_FullTextState>();

  SearchScope get _scope => SearchScope(
        bookId: _book?.id,
        bookTitle: _book?.title,
        authorId: _author?.id,
        authorName: _author?.name,
        categoryId: _category?.id,
        categoryTitle: _category?.title,
      );

  void _rerunFullText() {
    if (_tab == _Tab.search && _q.trim().isNotEmpty) _fullText.currentState?.search(_q, scope: _scope);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _select(_Tab t) => setState(() {
        _tab = t;
        _q = '';
        _search.clear();
      });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final hint = switch (_tab) {
      _Tab.books || _Tab.favorites => l.searchBooks,
      _Tab.authors => l.searchAuthors,
      _Tab.categories => l.categories,
      _Tab.search => l.searchInText,
    };
    final total = switch (_tab) {
      _Tab.books => '${catalog.books.length} ${l.books}',
      _Tab.favorites => '${reading.favorites.length} ${l.books}',
      _Tab.authors => '${catalog.authors.length} ${l.authors}',
      _Tab.categories => '${catalog.categories.length} ${l.categories}',
      _Tab.search => '',
    };
    return AuraPage(
      titleText: l.library,
      actions: [
        RoundIconButton(
          icon: Icons.border_color_outlined,
          tooltip: l.highlights,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HighlightsScreen())),
        ),
        const SizedBox(width: 6),
        RoundIconButton(
          icon: Icons.bookmarks_outlined,
          tooltip: l.bookmarks,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BookmarksScreen())),
        ),
      ],
      body: Column(children: [
        // Tabs: underlined, like Turath's library header.
        ReadingWidth(
          maxWidth: 940,
          child: Container(
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.border))),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(children: [
                for (final (t, label, icon) in [
                  (_Tab.books, l.allBooks, Icons.menu_book_rounded),
                  (_Tab.favorites, l.tabFavorites, Icons.star_rounded),
                  (_Tab.authors, l.authors, Icons.person_rounded),
                  (_Tab.categories, l.categories, Icons.category_rounded),
                  (_Tab.search, l.fullTextSearch, Icons.manage_search_rounded),
                ])
                  _TabButton(label: label, icon: icon, selected: _tab == t, onTap: () => _select(t)),
              ]),
            ),
          ),
        ),
        ReadingWidth(
          maxWidth: 940,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _SearchBar(
                controller: _search,
                hint: hint,
                count: total,
                rtl: _tab == _Tab.search,
                onChanged: (v) => setState(() => _q = v),
                onSubmitted: (_) => _rerunFullText(),
                actions: [
                  if (_tab == _Tab.books || _tab == _Tab.favorites)
                    PopupMenuButton<String>(
                      tooltip: l.sortBy,
                      icon: Icon(Icons.swap_vert_rounded, color: _sort == 'relevance' ? a.muted : a.accent),
                      onSelected: (v) => setState(() => _sort = v),
                      itemBuilder: (_) => [
                        for (final (v, label) in [('relevance', l.sortRelevance), ('title', l.sortTitle), ('author', l.sortAuthor)])
                          CheckedPopupMenuItem(value: v, checked: _sort == v, child: Text(label, style: const TextStyle(fontFamily: uiFont))),
                      ],
                    ),
                  if (_tab == _Tab.books && reading.recent.isNotEmpty)
                    IconButton(
                      tooltip: l.clearReadingHistory,
                      icon: Icon(Icons.history_toggle_off_rounded, color: a.muted),
                      onPressed: () async {
                        if (await confirmDialog(context, l.clearReadingHistoryConfirm) && context.mounted) await reading.clearHistory();
                      },
                    ),
                ],
              ),
              if (_tab == _Tab.search) _filterBar(context),
            ]),
          ),
        ),
        Expanded(
          child: switch (_tab) {
            _Tab.books => _books(context),
            _Tab.favorites => _favorites(context),
            _Tab.authors => _authors(context),
            _Tab.categories => _categories(context),
            _Tab.search => ReadingWidth(maxWidth: 940, child: _FullText(key: _fullText, query: _q, scope: _scope)),
          },
        ),
      ]),
    );
  }

  List<CatalogBook> _sorted(List<CatalogBook> books) {
    final catalog = context.read<CatalogService>();
    if (_sort == 'title') books.sort((x, y) => x.title.compareTo(y.title));
    if (_sort == 'author') books.sort((x, y) => (catalog.author(x.authorId)?.name ?? '').compareTo(catalog.author(y.authorId)?.name ?? ''));
    return books;
  }

  Widget _books(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final l = context.l;
    final home = _q.trim().isEmpty;
    final books = _sorted(catalog.findBooks(_q, limit: catalog.books.length));
    final recent = home ? [for (final p in reading.recent.take(6)) if (catalog.book(p.bookId) != null) (catalog.book(p.bookId)!, p)] : const <(CatalogBook, ReadingPosition)>[];
    if (books.isEmpty) return EmptyState(icon: Icons.search_off_rounded, text: l.noResults);
    return CustomScrollView(slivers: [
      if (recent.isNotEmpty) ...[
        _header(context, l.recentlyRead),
        SliverList.builder(
          itemCount: recent.length,
          itemBuilder: (context, i) => _width(LibraryBookRow(book: recent[i].$1, position: recent[i].$2)),
        ),
        _header(context, l.allBooks),
      ] else if (!home)
        _header(context, l.matches(books.length)),
      SliverList.builder(itemCount: books.length, itemBuilder: (context, i) => _width(LibraryBookRow(book: books[i]))),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
    ]);
  }

  Widget _favorites(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final q = normalizeForSearch(_q);
    final books = _sorted([
      for (final f in reading.favorites)
        if (catalog.book(f.bookId) case final b? when q.isEmpty || normalizeForSearch(b.title).contains(q)) b,
    ]);
    if (books.isEmpty) return EmptyState(icon: Icons.star_outline_rounded, text: context.l.noFavoriteBooks, color: AuraHues.amber);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: books.length,
      itemBuilder: (context, i) => _width(LibraryBookRow(book: books[i], position: reading.positionOf(books[i].id))),
    );
  }

  Widget _authors(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final a = context.aura;
    final authors = catalog.findAuthors(_q, limit: catalog.authors.length);
    if (authors.isEmpty) return EmptyState(icon: Icons.search_off_rounded, text: l.noResults);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: authors.length,
      itemBuilder: (context, i) {
        final author = authors[i];
        final open = _openAuthors.contains(author.id);
        return _width(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _GroupRow(
            title: author.name,
            count: author.bookCount,
            open: open,
            leading: _Initial(text: author.name, seed: int.tryParse(author.id) ?? 0),
            onTap: () => setState(() => open ? _openAuthors.remove(author.id) : _openAuthors.add(author.id)),
            trailing: IconButton(
              tooltip: l.author,
              icon: Icon(Icons.person_search_outlined, size: 20, color: a.muted),
              onPressed: () => openAuthor(context, author.id),
            ),
          ),
          if (open)
            for (final b in catalog.booksByAuthor(author.id)) Padding(padding: const EdgeInsetsDirectional.only(start: 28), child: LibraryBookRow(book: b, showAuthor: false)),
        ]));
      },
    );
  }

  Widget _categories(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final q = normalizeForSearch(_q);
    final cats = catalog.categories.where((c) => q.isEmpty || normalizeForSearch(c.title).contains(q)).toList();
    if (cats.isEmpty) return EmptyState(icon: Icons.search_off_rounded, text: l.noResults);
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        final open = _openCategories.contains(cat.id);
        final books = open ? catalog.findBooks('', categoryId: cat.id, limit: 25) : const <CatalogBook>[];
        return _width(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _GroupRow(
            title: cat.title,
            count: cat.bookCount,
            open: open,
            leading: IconTile(icon: categoryIcon(cat.id), color: AuraHues.category(cat.id), size: 34),
            onTap: () => setState(() => open ? _openCategories.remove(cat.id) : _openCategories.add(cat.id)),
          ),
          if (open) ...[
            for (final b in books) Padding(padding: const EdgeInsetsDirectional.only(start: 28), child: LibraryBookRow(book: b, showCategory: false)),
            if (cat.bookCount > books.length)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(40, 4, 16, 12),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SoftButton(
                    dense: true,
                    icon: Icons.arrow_outward_rounded,
                    label: '${l.allBooks} (${cat.bookCount})',
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CategoryBooksScreen(category: cat))),
                  ),
                ),
              ),
          ],
        ]));
      },
    );
  }

  Widget _width(Widget child) => ReadingWidth(maxWidth: 940, child: child);

  Widget _header(BuildContext context, String text) => SliverToBoxAdapter(
        child: _width(Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
          child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: context.aura.muted)),
        )),
      );

  /// Full-text filters: category, author and book.
  Widget _filterBar(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    Widget chip(String label, IconData icon, bool active, VoidCallback onTap, VoidCallback onClear) => Padding(
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
                if (active)
                  GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 15, color: a.accent))
                else
                  Icon(Icons.expand_more_rounded, size: 16, color: a.muted),
              ]),
            ),
          ),
        );
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
          }, () {
            setState(() => _category = null);
            _rerunFullText();
          }),
          chip(_author?.name ?? l.anyAuthor, Icons.person_outline_rounded, _author != null, () async {
            final x = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
            if (x != null) setState(() => _author = x);
            _rerunFullText();
          }, () {
            setState(() => _author = null);
            _rerunFullText();
          }),
          chip(_book?.title ?? l.anyBook, Icons.menu_book_outlined, _book != null, () async {
            final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: _author?.id, categoryId: _category?.id);
            if (b != null) setState(() => _book = b);
            _rerunFullText();
          }, () {
            setState(() => _book = null);
            _rerunFullText();
          }),
        ]),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: selected ? a.accent : Colors.transparent, width: 2.4))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 17, color: selected ? a.accent : a.muted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? a.accent : a.text)),
        ]),
      ),
    );
  }
}

/// Search field with the total count and tab actions inside, as on Turath.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.hint, required this.count, required this.rtl, required this.onChanged, required this.onSubmitted, this.actions = const []});
  final TextEditingController controller;
  final String hint;
  final String count;
  final bool rtl;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      height: 48,
      decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(16), border: Border.all(color: a.border)),
      child: Row(children: [
        Padding(padding: const EdgeInsetsDirectional.only(start: 12, end: 4), child: Icon(Icons.search_rounded, color: a.accent, size: 21)),
        Expanded(
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textInputAction: TextInputAction.search,
            textDirection: rtl ? TextDirection.rtl : null,
            style: TextStyle(fontFamily: uiFont, color: a.text, fontSize: 14.5),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            ),
          ),
        ),
        if (count.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
            child: Text(count, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
          ),
        ...actions,
        const SizedBox(width: 4),
      ]),
    );
  }
}

/// A collapsible author or category row with its book count.
class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.title, required this.count, required this.open, required this.leading, required this.onTap, this.trailing});
  final String title;
  final int count;
  final bool open;
  final Widget leading;
  final VoidCallback onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.border.withValues(alpha: 0.7)))),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          leading,
          const SizedBox(width: 12),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.55))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, fontWeight: FontWeight.w700, color: a.muted)),
          ),
          ?trailing,
          AnimatedRotation(
            duration: const Duration(milliseconds: 200),
            turns: open ? 0.5 : 0,
            child: Icon(Icons.expand_more_rounded, color: a.muted),
          ),
        ]),
      ),
    );
  }
}

class _Initial extends StatelessWidget {
  const _Initial({required this.text, required this.seed});
  final String text;
  final int seed;
  @override
  Widget build(BuildContext context) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: AuraHues.at(seed).withValues(alpha: context.aura.dark ? 0.24 : 0.14)),
        child: Text(text.characters.first, style: TextStyle(fontFamily: arabicFont, fontSize: 16, fontWeight: FontWeight.w700, height: 1.3, color: AuraHues.at(seed))),
      );
}

/// Opens a book at the page the reader left it (or its first page).
void readBook(BuildContext context, String bookId, String title) {
  final pos = context.read<ReadingController>().positionOf(bookId);
  openReader(context, bookId, pos?.page ?? 1, title: title);
}

/// A Turath-style book row: title, author and category, with "about the
/// book" and favourite buttons. Tapping it opens the reader.
class LibraryBookRow extends StatelessWidget {
  const LibraryBookRow({super.key, required this.book, this.position, this.showAuthor = true, this.showCategory = true});
  final CatalogBook book;
  final ReadingPosition? position;
  final bool showAuthor;
  final bool showCategory;
  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final a = context.aura;
    final l = context.l;
    final author = catalog.author(book.authorId);
    final category = catalog.category(book.categoryId);
    final fav = reading.isFavorite(book.id);
    final meta = [
      if (showAuthor && author != null) author.name,
      if (showCategory && category != null) category.title,
      if (position != null) '${l.continueReading} · ${l.turathPage} ${position!.page}',
    ].join('  ·  ');
    return InkWell(
      onTap: () => readBook(context, book.id, book.title),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.border.withValues(alpha: 0.7)))),
        padding: const EdgeInsetsDirectional.fromSTEB(14, 9, 4, 9),
        child: Row(children: [
          Container(width: 4, height: 38, decoration: BoxDecoration(color: AuraHues.category(book.categoryId), borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.55)),
              if (meta.isNotEmpty)
                Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: position != null ? a.accent : a.muted)),
            ]),
          ),
          IconButton(
            tooltip: l.bookInfo,
            icon: Icon(Icons.info_outline_rounded, size: 20, color: a.muted),
            onPressed: () => showBookInfo(context, book.id),
          ),
          IconButton(
            tooltip: fav ? l.removeFavorite : l.addFavorite,
            icon: Icon(fav ? Icons.star_rounded : Icons.star_outline_rounded, size: 21, color: fav ? AuraHues.amber : a.muted),
            onPressed: () => reading.toggleFavorite(book.id, book.title),
          ),
        ]),
      ),
    );
  }
}

/// "About the book" sheet: details, reading, search, favourite and ask.
Future<void> showBookInfo(BuildContext context, String bookId) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookInfoSheet(bookId: bookId),
    );

class _BookInfoSheet extends StatefulWidget {
  const _BookInfoSheet({required this.bookId});
  final String bookId;
  @override
  State<_BookInfoSheet> createState() => _BookInfoSheetState();
}

class _BookInfoSheetState extends State<_BookInfoSheet> {
  late final Future<BookDetails> _future = context.read<SettingsController>().backend.book(widget.bookId);

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final entry = catalog.book(widget.bookId);
    final l = context.l;
    final a = context.aura;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.94,
      builder: (context, scroll) => FutureBuilder<BookDetails>(
        future: _future,
        builder: (context, snap) {
          final d = snap.data;
          final title = d?.title ?? entry?.title ?? l.book;
          final author = catalog.author(d?.authorId ?? entry?.authorId);
          final category = catalog.category(d?.categoryId ?? entry?.categoryId);
          final pos = reading.positionOf(widget.bookId);
          final fav = reading.isFavorite(widget.bookId);
          return ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
            Directionality(
              textDirection: TextDirection.rtl,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                BookCover(title: title, color: AuraHues.category(category?.id), width: 64, height: 88),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: arabicStyle(context, size: 19, weight: FontWeight.w800).copyWith(height: 1.55)),
                    if (author != null)
                      InkWell(
                        onTap: () {
                          Navigator.of(context).pop();
                          openAuthor(context, author.id);
                        },
                        child: Text(author.name, style: arabicStyle(context, size: 14.5, color: a.accent).copyWith(height: 1.6)),
                      ),
                    if (category != null) Text(category.title, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted)),
                  ]),
                ),
              ]),
            ),
            if (d != null && (d.pageCount != null || d.volumes.length > 1))
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  if (d.pageCount != null) StatusBadge(icon: Icons.description_outlined, color: AuraHues.teal, label: l.pagesCount(d.pageCount!)),
                  if (d.volumes.length > 1) StatusBadge(icon: Icons.layers_outlined, color: AuraHues.amber, label: '${d.volumes.length} ${l.volumeShort}'),
                  if (d.toc.isNotEmpty) StatusBadge(icon: Icons.toc_rounded, color: AuraHues.violet, label: '${d.toc.length} ${l.tableOfContents}'),
                ]),
              ),
            const SizedBox(height: 16),
            GradientButton(
              height: 48,
              expand: true,
              icon: Icons.chrome_reader_mode_rounded,
              label: pos == null ? l.readBook : '${l.continueReading} · ${pos.page}',
              onTap: () {
                Navigator.of(context).pop();
                openReader(context, widget.bookId, pos?.page ?? d?.toc.firstOrNull?.page ?? 1, title: title);
              },
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SoftButton(
                  icon: Icons.manage_search_rounded,
                  label: l.searchInBook,
                  onTap: () {
                    Navigator.of(context).pop();
                    openReader(context, widget.bookId, pos?.page ?? 1, title: title, search: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftButton(
                  icon: fav ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AuraHues.amber,
                  label: fav ? l.removeFavorite : l.addFavorite,
                  onTap: () => reading.toggleFavorite(widget.bookId, title),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: SoftButton(
                  icon: Icons.auto_awesome_rounded,
                  color: AuraHues.violet,
                  label: l.askInThisBook,
                  onTap: () {
                    context.read<NavController>().askWithin(SearchScope.all.withBook(widget.bookId, title).withAuthor(author?.id, author?.name));
                    Navigator.of(context).popUntil((r) => r.isFirst);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SoftButton(
                  icon: Icons.toc_rounded,
                  label: l.tableOfContents,
                  onTap: () {
                    Navigator.of(context).pop();
                    openBook(context, widget.bookId);
                  },
                ),
              ),
            ]),
            const SizedBox(height: 8),
            SoftButton(icon: Icons.open_in_new_rounded, color: AuraHues.blue, label: l.openLink, onTap: () => openUrl('https://app.turath.io/book/${widget.bookId}')),
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: TypingDots()))
            else if (d?.description?.trim().isNotEmpty == true) ...[
              SectionLabel(l.description),
              SelectableText(d!.description!.trim(), textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15).copyWith(height: 1.95)),
            ],
          ]);
        },
      ),
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
        padding: const EdgeInsets.fromLTRB(0, 6, 0, 110),
        itemCount: books.length,
        itemBuilder: (context, i) => ReadingWidth(maxWidth: 940, child: LibraryBookRow(book: books[i], showCategory: false)),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: _items.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
            child: Text(l.matches(_total), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.muted)),
          );
        }
        if (i == _items.length + 1) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: _items.length >= _total
                  ? const SizedBox()
                  : _loading
                      ? const TypingDots()
                      : SoftButton(onTap: () => search(_q, more: true), label: l.loadMore, icon: Icons.expand_more_rounded),
            ),
          );
        }
        final p = _items[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AuraCard(
            padding: const EdgeInsets.all(16),
            onTap: p.internalPage == null ? () => openUrl(p.url) : () => openReader(context, p.bookId, p.internalPage!, title: p.bookTitle, highlight: _q),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text('$i', style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w800, color: a.faint)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.bookTitle, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700, color: a.accent).copyWith(height: 1.5)),
                      Text(p.citation ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
                    ]),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l.copy,
                    icon: Icon(Icons.copy_rounded, size: 18, color: a.muted),
                    onPressed: () => copyText(context, '${p.snippet ?? p.text}\n\n— ${p.citation ?? p.bookTitle}\n${p.url}'),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(p.snippet ?? p.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 16).copyWith(height: 1.95)),
                if (p.headings.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: AlignmentDirectional.centerStart, child: QueryChip(p.headings.last))),
              ]),
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

/// Every highlight across books, grouped by book.
class HighlightsScreen extends StatelessWidget {
  const HighlightsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final reading = context.watch<ReadingController>();
    final byBook = <String, List<Highlight>>{};
    for (final h in reading.highlights) {
      byBook.putIfAbsent(h.bookId, () => []).add(h);
    }
    return AuraPage(
      titleText: l.highlights,
      body: byBook.isEmpty
          ? EmptyState(icon: Icons.border_color_outlined, text: l.noHighlights, color: AuraHues.amber)
          : ListView(padding: const EdgeInsets.fromLTRB(14, 4, 14, 24), children: [
              for (final entry in byBook.entries)
                ReadingWidth(
                  maxWidth: 800,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
                      child: Text(entry.value.first.bookTitle, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 16, weight: FontWeight.w800).copyWith(height: 1.5)),
                    ),
                    for (final h in entry.value)
                      HighlightTile(highlight: h, digits: reading.digits, onTap: () => openReader(context, h.bookId, h.page, title: h.bookTitle, highlight: h.text)),
                  ]),
                ),
            ]),
    );
  }
}
