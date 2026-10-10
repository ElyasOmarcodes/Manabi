import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/scope_picker.dart';
import 'book_screen.dart';

void openAuthor(BuildContext context, String id) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthorScreen(authorId: id)));

class AuthorScreen extends StatefulWidget {
  const AuthorScreen({super.key, required this.authorId});
  final String authorId;
  @override
  State<AuthorScreen> createState() => _AuthorScreenState();
}

class _AuthorScreenState extends State<AuthorScreen> {
  late final Future<AuthorDetails> _future = context.read<SettingsController>().backend.author(widget.authorId);

  @override
  Widget build(BuildContext context) {
    final catalog = context.read<CatalogService>();
    final entry = catalog.author(widget.authorId);
    final books = catalog.booksByAuthor(widget.authorId);
    final l = context.l;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.read<NavController>().askWithin(SearchScope.all.withAuthor(widget.authorId, entry?.name));
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
        icon: const Icon(Icons.chat_bubble_outline_rounded),
        label: Text(l.askThisAuthor),
      ),
      body: AmbientBackground(
        child: CustomScrollView(slivers: [
          SliverAppBar.large(title: Text(entry?.name ?? l.author, style: arabicStyle(context, size: 22, weight: FontWeight.w700).copyWith(height: 1.4))),
          SliverToBoxAdapter(
            child: ReadingWidth(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: FutureBuilder<AuthorDetails>(
                  future: _future,
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(24), child: Center(child: TypingDots()));
                    final bio = snap.data?.biography?.trim();
                    if (bio == null || bio.isEmpty) return const SizedBox.shrink();
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      SectionTitle(l.biography),
                      SoftCard(child: _ExpandableText(bio)),
                    ]);
                  },
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ReadingWidth(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: SectionTitle('${l.authorBooks} · ${l.booksCount(books.length)}')),
            ),
          ),
          SliverList.builder(
            itemCount: books.length,
            itemBuilder: (context, i) => ReadingWidth(child: BookTile(book: books[i], onTap: () => openBook(context, books[i].id))),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ),
    );
  }
}

class _ExpandableText extends StatefulWidget {
  const _ExpandableText(this.text);
  final String text;
  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _open ? null : 8,
            overflow: _open ? null : TextOverflow.fade,
            textDirection: TextDirection.rtl,
            style: arabicStyle(context, size: 16).copyWith(height: 1.95),
          ),
        ),
        if (widget.text.length > 400)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: IconButton(
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded),
            ),
          ),
      ]);
}
