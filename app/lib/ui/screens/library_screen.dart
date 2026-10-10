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
import '../widgets/scope_picker.dart';
import 'author_screen.dart';
import 'book_screen.dart';
import 'reader_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return DefaultTabController(
      length: 4,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(children: [
              Icon(Icons.local_library_rounded, color: context.cs.primary),
              const SizedBox(width: 10),
              Flexible(child: Text(l.library, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            ]),
          ),
          TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            dividerColor: Colors.transparent,
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontFamily: uiFont),
            tabs: [Tab(text: l.books), Tab(text: l.authors), Tab(text: l.categories), Tab(text: l.fullTextSearch)],
          ),
          const Expanded(child: TabBarView(children: [_BooksTab(), _AuthorsTab(), _CategoriesTab(), _FullTextTab()])),
        ]),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.hint, required this.onChanged, this.onSubmitted, this.rtl = false});
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool rtl;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: ReadingWidth(
          child: TextField(
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            textDirection: rtl ? TextDirection.rtl : null,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded)),
          ),
        ),
      );
}

class _BooksTab extends StatefulWidget {
  const _BooksTab();
  @override
  State<_BooksTab> createState() => _BooksTabState();
}

class _BooksTabState extends State<_BooksTab> with AutomaticKeepAliveClientMixin {
  String _q = '';
  CatalogCategory? _category;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final books = catalog.findBooks(_q, categoryId: _category?.id, limit: 200);
    return Column(children: [
      _SearchField(hint: l.searchBooks, onChanged: (v) => setState(() => _q = v)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ReadingWidth(
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: InputChip(
              avatar: const Icon(Icons.category_outlined, size: 17),
              label: Text(_category?.title ?? l.allCategories),
              onPressed: () async {
                final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
                if (c != null) setState(() => _category = c);
              },
              onDeleted: _category == null ? null : () => setState(() => _category = null),
            ),
          ),
        ),
      ),
      Expanded(
        child: books.isEmpty
            ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                itemCount: books.length,
                itemBuilder: (context, i) => ReadingWidth(child: BookTile(book: books[i], onTap: () => openBook(context, books[i].id))),
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

class _AuthorsTabState extends State<_AuthorsTab> with AutomaticKeepAliveClientMixin {
  String _q = '';
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final authors = catalog.findAuthors(_q, limit: 200);
    return Column(children: [
      _SearchField(hint: l.searchAuthors, onChanged: (v) => setState(() => _q = v)),
      Expanded(
        child: authors.isEmpty
            ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                itemCount: authors.length,
                itemBuilder: (context, i) {
                  final a = authors[i];
                  return ReadingWidth(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.mc.glow,
                        child: Text(a.name.characters.first, style: arabicStyle(context, size: 18).copyWith(height: 1.2, color: context.cs.primary)),
                      ),
                      title: Text(a.name, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 17, weight: FontWeight.w700).copyWith(height: 1.5)),
                      subtitle: Text(l.booksCount(a.bookCount)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => openAuthor(context, a.id),
                    ),
                  );
                },
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
    return LayoutBuilder(builder: (context, c) {
      final columns = (c.maxWidth / 260).floor().clamp(1, 4);
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, mainAxisExtent: 92, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: catalog.categories.length,
        itemBuilder: (context, i) {
          final cat = catalog.categories[i];
          return SoftCard(
            padding: const EdgeInsets.all(14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _CategoryBooks(category: cat))),
            child: Row(children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: context.mc.glow, borderRadius: BorderRadius.circular(14)),
                child: Icon(Icons.auto_stories_outlined, color: context.cs.primary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(cat.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 16.5, weight: FontWeight.w700).copyWith(height: 1.5)),
                  Text(l.booksCount(cat.bookCount), style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                ]),
              ),
            ]),
          );
        },
      );
    });
  }
}

class _CategoryBooks extends StatelessWidget {
  const _CategoryBooks({required this.category});
  final CatalogCategory category;
  @override
  Widget build(BuildContext context) {
    final books = context.read<CatalogService>().findBooks('', categoryId: category.id, limit: 5000);
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(category.title, style: arabicStyle(context, size: 19, weight: FontWeight.w700).copyWith(height: 1.4))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<NavController>().askWithin(SearchScope.all.withCategory(category.id, category.title));
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: Text(l.askInCategory),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 96),
        itemCount: books.length,
        itemBuilder: (context, i) => ReadingWidth(child: BookTile(book: books[i], onTap: () => openBook(context, books[i].id))),
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

class _FullTextTabState extends State<_FullTextTab> with AutomaticKeepAliveClientMixin {
  String _q = '';
  final List<PagePassage> _items = [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

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
    super.build(context);
    final l = context.l;
    return Column(children: [
      _SearchField(hint: l.searchInText, rtl: true, onChanged: (v) => _q = v, onSubmitted: (_) => _search()),
      if (_items.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          child: ReadingWidth(child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.matches(_total), style: context.tt.labelMedium))),
        ),
      Expanded(
        child: _error != null && _items.isEmpty
            ? ErrorPanel(code: _error, onRetry: _search)
            : _items.isEmpty
                ? (_loading ? const Center(child: TypingDots()) : EmptyState(icon: Icons.manage_search_rounded, text: l.searchInText))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: _items.length + (_items.length < _total ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(12),
                          child: Center(
                            child: _loading ? const TypingDots() : OutlinedButton(onPressed: () => _search(more: true), child: Text(l.loadMore)),
                          ),
                        );
                      }
                      final p = _items[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReadingWidth(
                          child: SoftCard(
                            onTap: p.internalPage == null ? () => openUrl(p.url) : () => openReader(context, p.bookId, p.internalPage!, title: p.bookTitle),
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                                Text(p.bookTitle, style: arabicStyle(context, size: 16.5, weight: FontWeight.w700).copyWith(height: 1.5)),
                                Text(p.citation ?? '', style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                                const SizedBox(height: 6),
                                Text(p.snippet ?? p.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 16).copyWith(height: 1.9)),
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
