import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
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
          BookCover(title: book.title, seed: int.tryParse(book.categoryId) ?? book.title.length),
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
