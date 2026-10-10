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
      builder: (_) => FractionallySizedBox(heightFactor: 0.88, child: _CatalogPicker(kind: kind, authorId: authorId, categoryId: categoryId)),
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
    final title = switch (widget.kind) { PickKind.book => l.chooseBook, PickKind.author => l.chooseAuthor, PickKind.category => l.chooseCategory };
    final hint = switch (widget.kind) { PickKind.book => l.searchBooks, PickKind.author => l.searchAuthors, PickKind.category => l.categories };
    final List<Widget> tiles;
    switch (widget.kind) {
      case PickKind.book:
        final books = catalog.findBooks(_q, authorId: widget.authorId, categoryId: widget.categoryId, limit: 80);
        tiles = [
          for (final b in books)
            BookTile(book: b, onTap: () => Navigator.pop(context, b)),
        ];
      case PickKind.author:
        tiles = [
          for (final a in catalog.findAuthors(_q, limit: 80))
            ListTile(
              leading: const CircleAvatar(radius: 18, child: Icon(Icons.person_outline_rounded, size: 18)),
              title: Text(a.name, style: arabicStyle(context, size: 17).copyWith(height: 1.5)),
              subtitle: Text(l.booksCount(a.bookCount)),
              onTap: () => Navigator.pop(context, a),
            ),
        ];
      case PickKind.category:
        final q = normalizeForSearch(_q);
        tiles = [
          for (final c in catalog.categories.where((c) => q.isEmpty || normalizeForSearch(c.title).contains(q)))
            ListTile(
              leading: CircleAvatar(radius: 18, backgroundColor: context.mc.glow, child: Icon(Icons.category_outlined, size: 18, color: context.cs.primary)),
              title: Text(c.title, style: arabicStyle(context, size: 17).copyWith(height: 1.5)),
              subtitle: Text(l.booksCount(c.bookCount)),
              onTap: () => Navigator.pop(context, c),
            ),
        ];
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Text(title, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          autofocus: widget.kind != PickKind.category,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(hintText: hint, prefixIcon: const Icon(Icons.search_rounded)),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: tiles.isEmpty
            ? Center(child: Text(l.noResults))
            : ListView(padding: const EdgeInsets.fromLTRB(8, 0, 8, 24), children: tiles),
      ),
    ]);
  }
}

class BookTile extends StatelessWidget {
  const BookTile({super.key, required this.book, this.onTap, this.trailing});
  final CatalogBook book;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final author = catalog.author(book.authorId)?.name;
    final category = catalog.category(book.categoryId)?.title;
    return ListTile(
      leading: Container(
        width: 38,
        height: 46,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: LinearGradient(colors: [context.cs.primary.withValues(alpha: 0.85), context.cs.primary.withValues(alpha: 0.55)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: Icon(Icons.menu_book_rounded, size: 18, color: context.cs.onPrimary),
      ),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 17, weight: FontWeight.w700).copyWith(height: 1.55)),
      subtitle: Text([?author, ?category].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
