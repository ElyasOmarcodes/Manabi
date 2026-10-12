import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../theme.dart';
import 'common.dart';

enum PickKind { book, author, category }

/// Searchable bottom sheet over the offline catalog.
Future<T?> pickFromCatalog<T>(BuildContext context, PickKind kind, {String? authorId, String? categoryId}) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _CatalogPicker(kind: kind, authorId: authorId, categoryId: categoryId)),
    );

class _CatalogPicker extends StatefulWidget {
  const _CatalogPicker({required this.kind, this.authorId, this.categoryId});
  final PickKind kind;
  final String? authorId;
  final String? categoryId;
  @override
  State<_CatalogPicker> createState() => _CatalogPickerState();
}

class _CatalogPickerState extends State<_CatalogPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final a = context.aura;
    final (title, hint, icon, color) = switch (widget.kind) {
      PickKind.book => (l.chooseBook, l.searchBooks, Icons.menu_book_rounded, AuraHues.blue),
      PickKind.author => (l.chooseAuthor, l.searchAuthors, Icons.person_rounded, AuraHues.pink),
      PickKind.category => (l.chooseCategory, l.categories, Icons.category_rounded, AuraHues.mint),
    };
    final List<Widget> tiles;
    switch (widget.kind) {
      case PickKind.book:
        tiles = [for (final b in catalog.findBooks(_q, authorId: widget.authorId, categoryId: widget.categoryId, limit: 80)) BookTile(book: b, onTap: () => Navigator.pop(context, b))];
      case PickKind.author:
        tiles = [for (final x in catalog.findAuthors(_q, limit: 80)) AuthorTile(author: x, onTap: () => Navigator.pop(context, x))];
      case PickKind.category:
        final q = normalizeForSearch(_q);
        tiles = [
          for (final c in catalog.categories.where((c) => q.isEmpty || normalizeForSearch(c.title).contains(q)))
            CategoryTile(category: c, onTap: () => Navigator.pop(context, c)),
        ];
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Row(children: [
          IconTile(icon: icon, color: color, size: 42, gradient: true),
          const SizedBox(width: 12),
          Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 19, fontWeight: FontWeight.w800, color: a.text)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AuraSearchField(hint: hint, autofocus: widget.kind != PickKind.category, onChanged: (v) => setState(() => _q = v)),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: tiles.isEmpty
            ? EmptyState(icon: Icons.search_off_rounded, text: l.noResults)
            : ListView(padding: const EdgeInsets.fromLTRB(10, 0, 10, 24), children: tiles),
      ),
    ]);
  }
}

class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.onTap});
  final CatalogBook book;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final a = context.aura;
    final author = catalog.author(book.authorId)?.name;
    final category = catalog.category(book.categoryId)?.title;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          BookCover(title: book.title, color: AuraHues.category(book.categoryId)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 16.5, weight: FontWeight.w700).copyWith(height: 1.55)),
              Text([?author, ?category].join('  •  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class AuthorTile extends StatelessWidget {
  const AuthorTile({super.key, required this.author, this.onTap});
  final CatalogAuthor author;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final hue = AuraHues.at(int.tryParse(author.id) ?? 0);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [hue, AuraHues.at((int.tryParse(author.id) ?? 0) + 2)]),
            ),
            child: Text(author.name.characters.first, style: const TextStyle(fontFamily: arabicFont, fontSize: 21, color: Colors.white, fontWeight: FontWeight.w700, height: 1.3)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(author.name, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 16.5, weight: FontWeight.w700).copyWith(height: 1.55)),
              Text(context.l.booksCount(author.bookCount), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({super.key, required this.category, this.onTap});
  final CatalogCategory category;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(children: [
            IconTile(icon: categoryIcon(category.id), color: AuraHues.at(int.tryParse(category.id) ?? 0), size: 46),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(category.title, style: arabicStyle(context, size: 16.5, weight: FontWeight.w700).copyWith(height: 1.55)),
                Text(context.l.booksCount(category.bookCount), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: context.aura.muted)),
              ]),
            ),
          ]),
        ),
      );
}

/// A fitting icon per Turath category group.
IconData categoryIcon(String id) {
  final n = int.tryParse(id) ?? 0;
  return switch (n) {
    1 || 2 => Icons.brightness_7_outlined,
    3 || 4 || 5 => Icons.menu_book_rounded,
    >= 6 && <= 10 => Icons.format_quote_rounded,
    >= 11 && <= 22 => Icons.balance_rounded,
    23 => Icons.favorite_border_rounded,
    24 || 25 || 26 || 27 => Icons.history_edu_rounded,
    28 => Icons.public_rounded,
    >= 29 && <= 35 => Icons.translate_rounded,
    38 => Icons.healing_outlined,
    _ => Icons.auto_stories_outlined,
  };
}

/// Several books, authors or categories at once, with "all" on top (which
/// clears the pick). Returns null when dismissed.
Future<List<ScopeRef>?> pickManyFromCatalog(BuildContext context, PickKind kind, {List<ScopeRef> selected = const [], List<String> authorIds = const [], List<String> categoryIds = const []}) =>
    showModalBottomSheet<List<ScopeRef>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.9, child: _ManyPicker(kind: kind, selected: selected, authorIds: authorIds, categoryIds: categoryIds)),
    );

class _ManyPicker extends StatefulWidget {
  const _ManyPicker({required this.kind, required this.selected, required this.authorIds, required this.categoryIds});
  final PickKind kind;
  final List<ScopeRef> selected;
  final List<String> authorIds;
  final List<String> categoryIds;
  @override
  State<_ManyPicker> createState() => _ManyPickerState();
}

class _ManyPickerState extends State<_ManyPicker> {
  String _q = '';
  late final List<ScopeRef> _picked = List.of(widget.selected);

  bool _has(String id) => _picked.any((r) => r.id == id);

  void _toggle(String id, String name) => setState(() {
        if (_has(id)) {
          _picked.removeWhere((r) => r.id == id);
        } else {
          _picked.add((id: id, name: name));
        }
      });

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final a = context.aura;
    final (title, hint, icon, color, allLabel) = switch (widget.kind) {
      PickKind.book => (l.scopeBook, l.searchBooks, Icons.menu_book_rounded, AuraHues.blue, l.allBooks),
      PickKind.author => (l.scopeAuthor, l.searchAuthors, Icons.person_rounded, AuraHues.pink, l.allAuthors),
      PickKind.category => (l.scopeCategory, l.categories, Icons.category_rounded, AuraHues.mint, l.allCategories),
    };
    Widget check(String id, String name, Widget tile) => Row(children: [
          Expanded(child: tile),
          Checkbox(value: _has(id), onChanged: (_) => _toggle(id, name)),
        ]);
    final List<Widget> tiles;
    switch (widget.kind) {
      case PickKind.book:
        // Books of the chosen authors and categories first, when some are chosen.
        final found = <CatalogBook>[];
        if (widget.authorIds.isEmpty && widget.categoryIds.isEmpty) {
          found.addAll(catalog.findBooks(_q, limit: 80));
        } else {
          for (final aId in widget.authorIds.isEmpty ? const <String?>[null] : widget.authorIds) {
            for (final cId in widget.categoryIds.isEmpty ? const <String?>[null] : widget.categoryIds) {
              found.addAll(catalog.findBooks(_q, authorId: aId, categoryId: cId, limit: 40));
            }
          }
        }
        tiles = [for (final b in found) check(b.id, b.title, BookTile(book: b, onTap: () => _toggle(b.id, b.title)))];
      case PickKind.author:
        tiles = [for (final x in catalog.findAuthors(_q, limit: 80)) check(x.id, x.name, AuthorTile(author: x, onTap: () => _toggle(x.id, x.name)))];
      case PickKind.category:
        final q = normalizeForSearch(_q);
        tiles = [
          for (final c in catalog.categories.where((c) => q.isEmpty || normalizeForSearch(c.title).contains(q)))
            check(c.id, c.title, CategoryTile(category: c, onTap: () => _toggle(c.id, c.title))),
        ];
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 12, 10),
        child: Row(children: [
          IconTile(icon: icon, color: color, size: 42, gradient: true),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(fontFamily: uiFont, fontSize: 19, fontWeight: FontWeight.w800, color: a.text)),
              Text(l.pickMany, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
            ]),
          ),
          FilledButton(onPressed: () => Navigator.pop(context, _picked), child: Text(l.doneCount('${_picked.length}'))),
        ]),
      ),
      if (_picked.isNotEmpty)
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final r in _picked)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
                child: InputChip(
                  label: Text(r.name, style: arabicStyle(context, size: 13.5).copyWith(height: 1.3)),
                  onDeleted: () => _toggle(r.id, r.name),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ]),
        ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: AuraSearchField(hint: hint, autofocus: widget.kind != PickKind.category, onChanged: (v) => setState(() => _q = v)),
      ),
      const SizedBox(height: 6),
      Expanded(
        child: ListView(padding: const EdgeInsets.fromLTRB(10, 0, 10, 24), children: [
          // "All": no restriction of this kind.
          ListTile(
            leading: Icon(Icons.all_inclusive_rounded, color: _picked.isEmpty ? a.accent : a.muted),
            title: Text(allLabel, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: _picked.isEmpty ? a.accent : a.text)),
            trailing: _picked.isEmpty ? Icon(Icons.check_rounded, color: a.accent) : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onTap: () => Navigator.pop(context, const <ScopeRef>[]),
          ),
          if (tiles.isEmpty) Padding(padding: const EdgeInsets.only(top: 40), child: EmptyState(icon: Icons.search_off_rounded, text: l.noResults)) else ...tiles,
        ]),
      ),
    ]);
  }
}

/// Category, author and book chips, each picking several (or "all").
class ScopeChipsRow extends StatelessWidget {
  const ScopeChipsRow({super.key, required this.scope, required this.onChanged});
  final SearchScope scope;
  final ValueChanged<SearchScope> onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    String names(List<ScopeRef> r, String any) => r.isEmpty ? any : (r.length == 1 ? r.first.name : '${r.first.name} +${r.length - 1}');
    Widget chip(String label, IconData icon, bool active, Future<void> Function() pick, VoidCallback clear) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Pressable(
            onTap: pick,
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
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? a.accent : a.text)),
                ),
                const SizedBox(width: 2),
                if (active)
                  GestureDetector(onTap: clear, child: Icon(Icons.close_rounded, size: 15, color: a.accent))
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
          chip(names(scope.categories, l.allCategories), Icons.category_outlined, scope.categories.isNotEmpty, () async {
            final r = await pickManyFromCatalog(context, PickKind.category, selected: scope.categories);
            if (r != null) onChanged(scope.copyWith(categories: r));
          }, () => onChanged(scope.copyWith(categories: const []))),
          chip(names(scope.authors, l.allAuthors), Icons.person_outline_rounded, scope.authors.isNotEmpty, () async {
            final r = await pickManyFromCatalog(context, PickKind.author, selected: scope.authors);
            if (r != null) onChanged(scope.copyWith(authors: r));
          }, () => onChanged(scope.copyWith(authors: const []))),
          chip(names(scope.books, l.allBooks), Icons.menu_book_outlined, scope.books.isNotEmpty, () async {
            final r = await pickManyFromCatalog(context, PickKind.book,
                selected: scope.books, authorIds: [for (final x in scope.authors) x.id], categoryIds: [for (final x in scope.categories) x.id]);
            if (r != null) onChanged(scope.copyWith(books: r));
          }, () => onChanged(scope.copyWith(books: const []))),
        ]),
      ),
    );
  }
}
