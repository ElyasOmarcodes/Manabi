import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../state/nav_controller.dart';
import '../../state/downloads.dart';
import '../../state/pdf_flags.dart';
import '../../state/reading_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/chat_list.dart' show confirmDialog;
import '../widgets/common.dart';
import '../widgets/save_offline.dart';
import '../widgets/scope_picker.dart';
import 'author_screen.dart';
import 'book_screen.dart';
import 'reader_screen.dart';
import 'text_search.dart';

void _push(BuildContext context, Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

/// Library home: one search for books and authors, the books being read,
/// and one clear tile per section; each section opens its own page.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final catalog = context.read<CatalogService>();
    return AuraPage(
      titleText: l.library,
      body: Column(children: [
        ReadingWidth(
          maxWidth: 940,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
            child: _SearchBar(
              controller: _search,
              hint: l.libSearchHint,
              count: _q.isEmpty ? '${catalog.books.length} ${l.books}' : '',
              rtl: false,
              onChanged: (v) => setState(() => _q = v),
              onSubmitted: (_) {},
              actions: [
                if (_q.isNotEmpty)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => setState(() {
                      _q = '';
                      _search.clear();
                    }),
                  ),
              ],
            ),
          ),
        ),
        Expanded(child: _q.trim().isEmpty ? const _LibraryHome() : _SearchResults(query: _q.trim())),
      ]),
    );
  }
}

class _LibraryHome extends StatelessWidget {
  const _LibraryHome();
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final downloads = context.watch<DownloadController>();
    final recent = [for (final p in reading.recent.take(10)) (catalog.book(p.bookId), p)];
    final tiles = <(IconData, Color, String, String, Widget)>[
      (Icons.menu_book_rounded, AuraHues.violet, l.allBooks, '${catalog.books.length}', const AllBooksPage()),
      (Icons.category_rounded, AuraHues.teal, l.categories, '${catalog.categories.length}', const CategoriesPage()),
      (Icons.person_rounded, AuraHues.amber, l.authors, '${catalog.authors.length}', const AuthorsPage()),
      (Icons.groups_rounded, AuraHues.blue, l.narrators, '18,989', const NarratorsPage()),
      (Icons.star_rounded, AuraHues.amber, l.tabFavorites, '${reading.favorites.length}', const FavoritesPage()),
      (Icons.download_done_rounded, AuraHues.green, l.tabDownloaded, '${downloads.books.length}', const DownloadsPage()),
      (Icons.manage_search_rounded, AuraHues.rose, l.fullTextSearch, '', const FullTextPage()),
      (Icons.border_color_outlined, AuraHues.amber, l.highlights, '${reading.highlights.length}', const HighlightsScreen()),
      (Icons.bookmarks_outlined, AuraHues.rose, l.bookmarks, '${reading.bookmarks.length}', const BookmarksScreen()),
    ];
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      if (recent.isNotEmpty) ...[
        ReadingWidth(maxWidth: 940, child: _Heading(l.continueReading)),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            itemCount: recent.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final (book, pos) = recent[i];
              return Pressable(
                onTap: () => openReader(context, pos.bookId, pos.page, title: pos.bookTitle),
                child: Container(
                  width: 236,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: a.border)),
                  child: Row(children: [
                    BookCover(title: pos.bookTitle, color: AuraHues.category(book?.categoryId), width: 52, height: 76),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(pos.bookTitle, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 14.5, weight: FontWeight.w700).copyWith(height: 1.5)),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(Icons.play_circle_fill_rounded, size: 15, color: a.accent),
                          const SizedBox(width: 4),
                          Text('${l.turathPage} ${pos.page}', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.accent, fontWeight: FontWeight.w600)),
                        ]),
                      ]),
                    ),
                  ]),
                ),
              );
            },
          ),
        ),
      ],
      ReadingWidth(maxWidth: 940, child: _Heading(l.librarySections)),
      ReadingWidth(
        maxWidth: 940,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth > 760 ? 3 : 2;
            final width = (box.maxWidth - (columns - 1) * 10) / columns;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final (icon, color, title, count, page) in tiles)
                SizedBox(
                  width: width,
                  child: Pressable(
                    onTap: () => _push(context, page),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                      decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: a.border)),
                      child: Row(children: [
                        IconTile(icon: icon, color: color, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, fontWeight: FontWeight.w700, color: a.text)),
                            if (count.isNotEmpty) Text(count, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
                          ]),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]);
          }),
        ),
      ),
    ]);
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, {this.trailing});
  final String text;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 16, 14, 8),
        child: Row(children: [
          Expanded(child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w800, color: context.aura.muted))),
          ?trailing,
        ]),
      );
}

/// Results while typing: books, authors, books found on Turath, and a way
/// to search inside the texts.
class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query});
  final String query;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    final books = catalog.findBooks(query, limit: catalog.books.length);
    final authors = catalog.findAuthors(query, limit: 6);
    Widget w(Widget child) => ReadingWidth(maxWidth: 940, child: child);
    return ListView(padding: const EdgeInsets.only(bottom: 32), children: [
      w(ListTile(
        leading: IconTile(icon: Icons.manage_search_rounded, color: AuraHues.rose, size: 36),
        title: Text(l.searchInTextsFor(query), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w600, color: a.text)),
        trailing: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, color: a.faint),
        onTap: () => _push(context, FullTextPage(initialQuery: query)),
      )),
      if (books.isNotEmpty)
        w(_Heading('${l.books} · ${books.length}',
            trailing: books.length > 12 ? TextButton(onPressed: () => _push(context, AllBooksPage(initialQuery: query)), child: Text(l.seeAll(books.length))) : null)),
      for (final b in books.take(12)) w(LibraryBookRow(book: b)),
      w(_TurathBooks(key: ValueKey(query), query: query, exclude: {for (final b in books.take(200)) b.id})),
      if (authors.isNotEmpty) ...[
        w(_Heading(l.authors)),
        for (final x in authors) w(AuthorTile(author: x, onTap: () => openAuthor(context, x.id))),
      ],
      if (books.isEmpty && authors.isEmpty) Padding(padding: const EdgeInsets.all(28), child: Center(child: Text(l.noResults, style: TextStyle(fontFamily: uiFont, color: a.muted)))),
    ]);
  }
}

/// Scaffold of a library section: title, an optional search field, body.
class _SectionPage extends StatelessWidget {
  const _SectionPage({required this.title, required this.body, this.search, this.actions = const []});
  final String title;
  final Widget body;
  final Widget? search;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => AuraPage(
        titleText: title,
        actions: actions,
        body: Column(children: [
          if (search != null) ReadingWidth(maxWidth: 940, child: Padding(padding: const EdgeInsets.fromLTRB(14, 4, 14, 6), child: search)),
          Expanded(child: body),
        ]),
      );
}

class AllBooksPage extends StatefulWidget {
  const AllBooksPage({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  State<AllBooksPage> createState() => _AllBooksPageState();
}

class _AllBooksPageState extends State<AllBooksPage> {
  late final _search = TextEditingController(text: widget.initialQuery);
  late String _q = widget.initialQuery;
  String _sort = 'title';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    final books = catalog.findBooks(_q, limit: catalog.books.length);
    if (_sort == 'title') books.sort((x, y) => x.title.compareTo(y.title));
    if (_sort == 'author') books.sort((x, y) => (catalog.author(x.authorId)?.name ?? '').compareTo(catalog.author(y.authorId)?.name ?? ''));
    return _SectionPage(
      title: l.allBooks,
      search: _SearchBar(
        controller: _search,
        hint: l.searchBooks,
        count: '${books.length}',
        rtl: false,
        onChanged: (v) => setState(() => _q = v),
        onSubmitted: (_) {},
        actions: [
          PopupMenuButton<String>(
            tooltip: l.sortBy,
            icon: Icon(Icons.swap_vert_rounded, color: a.muted),
            onSelected: (v) => setState(() => _sort = v),
            itemBuilder: (_) => [
              for (final (v, label) in [('relevance', l.sortRelevance), ('title', l.sortTitle), ('author', l.sortAuthor)])
                CheckedPopupMenuItem(value: v, checked: _sort == v, child: Text(label, style: TextStyle(fontFamily: uiFont))),
            ],
          ),
        ],
      ),
      body: books.isEmpty
          ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: books.length,
              itemBuilder: (context, i) => ReadingWidth(maxWidth: 940, child: LibraryBookRow(book: books[i])),
            ),
    );
  }
}

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final catalog = context.read<CatalogService>();
    final reading = context.watch<ReadingController>();
    final books = [for (final f in reading.favorites) catalog.book(f.bookId) ?? CatalogBook(f.bookId, f.title, '', '')];
    return _SectionPage(
      title: l.tabFavorites,
      body: books.isEmpty
          ? EmptyState(icon: Icons.star_outline_rounded, text: l.noFavoriteBooks, color: AuraHues.amber)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: books.length,
              itemBuilder: (context, i) => ReadingWidth(maxWidth: 940, child: LibraryBookRow(book: books[i], position: reading.positionOf(books[i].id))),
            ),
    );
  }
}

/// Books saved on the device, with their size; ones being saved show progress.
class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    final downloads = context.watch<DownloadController>();
    final books = downloads.books;
    return _SectionPage(
      title: l.tabDownloaded,
      actions: [
        if (books.isNotEmpty)
          RoundIconButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: l.deleteAllDownloads,
            onTap: () async {
              if (await confirmDialog(context, l.deleteAllDownloadsConfirm)) await downloads.removeAll();
            },
          ),
      ],
      body: books.isEmpty
          ? EmptyState(icon: Icons.download_for_offline_outlined, text: l.noDownloads, color: AuraHues.green)
          : ListView(padding: const EdgeInsets.only(bottom: 32), children: [
              ReadingWidth(
                maxWidth: 940,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(20, 6, 20, 6),
                  child: Text(l.downloadsSize(formatBytes(downloads.totalBytes)), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted)),
                ),
              ),
              for (final b in books)
                ReadingWidth(
                  maxWidth: 940,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    LibraryBookRow(book: catalog.book(b.bookId) ?? CatalogBook(b.bookId, b.title, b.authorId ?? '', b.categoryId ?? '')),
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(30, 0, 14, 8),
                      child: Row(children: [
                        Icon(b.complete ? Icons.offline_pin_rounded : Icons.downloading_rounded, size: 16, color: b.complete ? AuraHues.green : AuraHues.amber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('${l.pagesShort(b.pages)} · ${formatBytes(b.bytes)}', style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
                        ),
                        TextButton.icon(
                          onPressed: () => downloads.remove(b.bookId),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18),
                          label: Text(l.removeDownload, style: TextStyle(fontFamily: uiFont)),
                        ),
                      ]),
                    ),
                  ]),
                ),
            ]),
    );
  }
}

class AuthorsPage extends StatefulWidget {
  const AuthorsPage({super.key});
  @override
  State<AuthorsPage> createState() => _AuthorsPageState();
}

class _AuthorsPageState extends State<AuthorsPage> {
  final _search = TextEditingController();
  String _q = '';
  final _open = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final catalog = context.read<CatalogService>();
    final authors = catalog.findAuthors(_q, limit: catalog.authors.length);
    return _SectionPage(
      title: l.authors,
      search: _SearchBar(controller: _search, hint: l.searchAuthors, count: '${authors.length}', rtl: false, onChanged: (v) => setState(() => _q = v), onSubmitted: (_) {}),
      body: authors.isEmpty
          ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults)
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 32),
              itemCount: authors.length,
              itemBuilder: (context, i) {
                final author = authors[i];
                final open = _open.contains(author.id);
                return ReadingWidth(
                  maxWidth: 940,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    _GroupRow(
                      title: author.name,
                      count: author.bookCount,
                      open: open,
                      leading: _Initial(text: author.name, seed: int.tryParse(author.id) ?? 0),
                      onTap: () => setState(() => open ? _open.remove(author.id) : _open.add(author.id)),
                      trailing: IconButton(tooltip: l.author, icon: Icon(Icons.person_search_outlined, size: 20, color: a.muted), onPressed: () => openAuthor(context, author.id)),
                    ),
                    if (open)
                      for (final b in catalog.booksByAuthor(author.id)) Padding(padding: const EdgeInsetsDirectional.only(start: 28), child: LibraryBookRow(book: b, showAuthor: false)),
                  ]),
                );
              },
            ),
    );
  }
}

class CategoriesPage extends StatefulWidget {
  const CategoriesPage({super.key});
  @override
  State<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends State<CategoriesPage> {
  final _search = TextEditingController();
  String _q = '';
  final _open = <String>{};

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final catalog = context.read<CatalogService>();
    final q = normalizeForSearch(_q);
    final cats = catalog.categories.where((c) => q.isEmpty || normalizeForSearch(c.title).contains(q)).toList();
    return _SectionPage(
      title: l.categories,
      search: _SearchBar(controller: _search, hint: l.categories, count: '${cats.length}', rtl: false, onChanged: (v) => setState(() => _q = v), onSubmitted: (_) {}),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 32),
        itemCount: cats.length,
        itemBuilder: (context, i) {
          final cat = cats[i];
          final open = _open.contains(cat.id);
          final books = open ? catalog.findBooks('', categoryId: cat.id, limit: 25) : const <CatalogBook>[];
          return ReadingWidth(
            maxWidth: 940,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              _GroupRow(
                title: cat.title,
                count: cat.bookCount,
                open: open,
                leading: IconTile(icon: categoryIcon(cat.id), color: AuraHues.category(cat.id), size: 34),
                onTap: () => setState(() => open ? _open.remove(cat.id) : _open.add(cat.id)),
              ),
              if (open) ...[
                for (final b in books) Padding(padding: const EdgeInsetsDirectional.only(start: 28), child: LibraryBookRow(book: b, showCategory: false)),
                if (cat.bookCount > books.length)
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(40, 4, 16, 12),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: SoftButton(dense: true, icon: Icons.arrow_outward_rounded, label: l.seeAll(cat.bookCount), onTap: () => _push(context, CategoryBooksScreen(category: cat))),
                    ),
                  ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

/// Turath's narrator index: search, grade and death year; a tap opens the
/// biography.
class NarratorsPage extends StatefulWidget {
  const NarratorsPage({super.key});
  @override
  State<NarratorsPage> createState() => _NarratorsPageState();
}

class _NarratorsPageState extends State<NarratorsPage> {
  final _search = TextEditingController();
  final _items = <Narrator>[];
  int _count = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;
  String _q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading) return;
    final backend = context.read<SettingsController>().backend;
    final q = _q;
    setState(() {
      _loading = true;
      _error = null;
      if (!more) {
        _items.clear();
        _page = 0;
      }
    });
    try {
      final r = await backend.narrators(q, page: _page + 1);
      if (!mounted || q != _q) return;
      setState(() {
        _items.addAll(r.items);
        _count = r.count;
        _page = r.page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = mapError(e).code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return _SectionPage(
      title: l.narrators,
      search: _SearchBar(
        controller: _search,
        hint: l.searchNarrators,
        count: _count == 0 ? '' : l.narratorsCount('$_count'),
        rtl: true,
        onChanged: (v) {
          _q = v.trim();
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 450), _load);
        },
        onSubmitted: (_) => _load(),
      ),
      body: _error != null && _items.isEmpty
          ? ErrorPanel(code: _error, onRetry: _load)
          : _items.isEmpty
              ? Center(child: _loading ? const TypingDots() : Text(l.noResults, style: TextStyle(fontFamily: uiFont, color: a.muted)))
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 600 && _items.length < _count) _load(more: true);
                    return false;
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 32),
                    itemCount: _items.length + (_items.length < _count ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: TypingDots()));
                      final n = _items[i];
                      return ReadingWidth(maxWidth: 940, child: NarratorTile(narrator: n));
                    },
                  ),
                ),
    );
  }
}

/// A narrator row: name, grade and death.
class NarratorTile extends StatelessWidget {
  const NarratorTile({super.key, required this.narrator});
  final Narrator narrator;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    final n = narrator;
    return InkWell(
      onTap: () => showNarrator(context, n.id, n.name),
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.border.withValues(alpha: 0.7)))),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(children: [
            _Initial(text: n.name.isEmpty ? '؟' : n.name, seed: int.tryParse(n.id) ?? 0),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.55)),
                if (n.deathText.isNotEmpty)
                  Text('${l.narratorDeath}: ${n.deathText}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
              ]),
            ),
            if (n.rank.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 150),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(10)),
                child: Text(n.rank, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, fontWeight: FontWeight.w700, color: a.accent)),
              ),
          ]),
        ),
      ),
    );
  }
}

/// A narrator's biography (from Turath), with a way to find them in the texts.
Future<void> showNarrator(BuildContext context, String id, String name) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NarratorSheet(id: id, name: name),
    );

class _NarratorSheet extends StatefulWidget {
  const _NarratorSheet({required this.id, required this.name});
  final String id;
  final String name;
  @override
  State<_NarratorSheet> createState() => _NarratorSheetState();
}

class _NarratorSheetState extends State<_NarratorSheet> {
  late final Future<Narrator> _future = context.read<SettingsController>().backend.narrator(widget.id);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.94,
      builder: (context, scroll) => FutureBuilder<Narrator>(
        future: _future,
        builder: (context, snap) {
          final n = snap.data;
          return Directionality(
            textDirection: TextDirection.rtl,
            child: ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
              Text(n?.name ?? widget.name, style: arabicStyle(context, size: 20, weight: FontWeight.w800).copyWith(height: 1.55)),
              if (n != null && n.fullName.isNotEmpty && n.fullName != n.name) Text(n.fullName, style: arabicStyle(context, size: 14.5, color: a.muted).copyWith(height: 1.7)),
              const SizedBox(height: 10),
              if (snap.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: TypingDots()))
              else if (snap.hasError)
                SizedBox(height: 220, child: ErrorPanel(code: mapError(snap.error!).code))
              else ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (n!.rank.isNotEmpty) StatusBadge(icon: Icons.verified_outlined, color: AuraHues.violet, label: '${l.narratorRank}: ${n.rank}'),
                  if (n.deathText.isNotEmpty) StatusBadge(icon: Icons.event_outlined, color: AuraHues.teal, label: '${l.narratorDeath}: ${n.deathText}'),
                ]),
                const SizedBox(height: 12),
                for (final (k, v) in n.summary)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: a.border.withValues(alpha: 0.6)))),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(width: 120, child: Text(k, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w700, color: a.muted, height: 1.6))),
                      Expanded(child: SelectableText(v, style: arabicStyle(context, size: 15).copyWith(height: 1.8))),
                    ]),
                  ),
              ],
              const SizedBox(height: 14),
              SoftButton(
                icon: Icons.manage_search_rounded,
                label: l.findInTexts,
                onTap: () {
                  Navigator.of(context).pop();
                  _push(context, FullTextPage(initialQuery: n?.name ?? widget.name));
                },
              ),
            ]),
          );
        },
      ),
    );
  }
}

/// Full-text search across Turath with category, author and book filters.
/// Books that are on Turath but not in the offline list (it is a snapshot):
/// found through Turath's search, whose hits name their books. A number or
/// a Turath link opens that book directly.
class _TurathBooks extends StatefulWidget {
  const _TurathBooks({super.key, required this.query, required this.exclude});
  final String query;
  final Set<String> exclude;
  @override
  State<_TurathBooks> createState() => _TurathBooksState();
}

class _TurathBooksState extends State<_TurathBooks> {
  Timer? _debounce;
  List<CatalogBook>? _books;
  bool _failed = false;

  String? get _directId => RegExp(r'^(?:https?://app\.turath\.io/book/)?(\d{1,7})(?:\D.*)?$').firstMatch(widget.query)?.group(1);

  @override
  void initState() {
    super.initState();
    if (widget.query.length >= 3 && _directId == null) _debounce = Timer(const Duration(milliseconds: 650), _search);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    final backend = context.read<SettingsController>().backend;
    final catalog = context.read<CatalogService>();
    final words = normalizeForSearch(widget.query).split(' ').where((w) => w.length > 1).toList();
    try {
      final pages = await Future.wait([
        for (final page in [1, 2]) backend.search(widget.query, page: page).catchError((Object _) => const SearchResultPage(items: [], totalMatches: 0, page: 1)),
      ]);
      final found = <String, CatalogBook>{};
      for (final p in pages.expand((r) => r.items)) {
        if (widget.exclude.contains(p.bookId) || found.containsKey(p.bookId)) continue;
        final title = normalizeForSearch(p.bookTitle);
        if (words.isEmpty || !words.every(title.contains)) continue;
        found[p.bookId] = catalog.book(p.bookId) ?? CatalogBook(p.bookId, p.bookTitle, p.authorId ?? '', p.categoryId ?? '');
      }
      if (mounted) setState(() => _books = found.values.toList());
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final id = _directId;
    if (id != null) {
      return ListTile(
        leading: Icon(Icons.open_in_browser_rounded, color: a.accent),
        title: Text('${l.book} $id', style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: a.text)),
        subtitle: Text(l.onTurath, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
        onTap: () => openReader(context, id, 1),
      );
    }
    if (widget.query.length < 3 || _failed || (_books?.isEmpty ?? false)) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 2),
        child: Row(children: [
          Icon(Icons.travel_explore_rounded, size: 16, color: a.accent),
          const SizedBox(width: 6),
          Text(l.onTurath, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.accent)),
          if (_books == null) ...[const SizedBox(width: 10), const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))],
        ]),
      ),
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
        child: Text(_books == null ? l.searchingTurath : l.onTurathInfo, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
      ),
      for (final b in _books ?? const <CatalogBook>[]) LibraryBookRow(book: b),
    ]);
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
    final rest = [
      if (showCategory && category != null) category.title,
      if (position != null) '${l.continueReading} · ${l.turathPage} ${position!.page}',
    ].join('  ·  ');
    final metaStyle = TextStyle(fontFamily: uiFont, fontSize: 12, color: position != null ? a.accent : a.muted);
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
              Directionality(
                textDirection: TextDirection.rtl,
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Flexible(
                    child: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700).copyWith(height: 1.55)),
                  ),
                  // Books with Turath's scanned edition get a small red badge.
                  ValueListenableBuilder<int>(
                    valueListenable: PdfFlags.changes,
                    builder: (context, _, _) => PdfFlags.of(book.id) == true ? const PdfBadge() : const SizedBox.shrink(),
                  ),
                ]),
              ),
              if ((showAuthor && author != null) || rest.isNotEmpty)
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(children: [
                    if (showAuthor && author != null)
                      Flexible(
                        flex: 0,
                        child: InkWell(
                          // The author's name opens all their books.
                          onTap: () => openAuthor(context, author.id),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(author.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle.copyWith(color: a.accent, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    if (rest.isNotEmpty)
                      Expanded(child: Text('${showAuthor && author != null ? '  ·  ' : ''}$rest', maxLines: 1, overflow: TextOverflow.ellipsis, style: metaStyle)),
                  ]),
                ),
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

/// Small red "PDF" label for books that have Turath's scanned edition.
class PdfBadge extends StatelessWidget {
  const PdfBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsetsDirectional.only(start: 6, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(color: const Color(0xFFD32F2F), borderRadius: BorderRadius.circular(5)),
        child: const Text('PDF', style: TextStyle(fontFamily: 'Vazirmatn', fontSize: 9.5, fontWeight: FontWeight.w800, color: Colors.white, height: 1.3)),
      );
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
            SaveOfflineButton(bookId: widget.bookId, title: title),
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
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5)),
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
