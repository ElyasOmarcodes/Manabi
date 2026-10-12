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

void openAuthor(BuildContext context, String id) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AuthorScreen(authorId: id)));

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
    final a = context.aura;
    final seed = int.tryParse(widget.authorId) ?? 0;
    final name = entry?.name ?? l.author;
    return AuraPage(
      floating: GradientButton(
        icon: Icons.auto_awesome_rounded,
        label: l.askThisAuthor,
        onTap: () {
          context.read<NavController>().askWithin(SearchScope.all.withAuthor(widget.authorId, entry?.name));
          Navigator.of(context).popUntil((r) => r.isFirst);
        },
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), children: [
        ReadingWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Reveal(
              child: Column(children: [
                Container(
                  width: 104,
                  height: 104,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [AuraHues.at(seed), AuraHues.at(seed + 2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    boxShadow: [BoxShadow(color: AuraHues.at(seed).withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 12), spreadRadius: -8)],
                  ),
                  child: Text(name.characters.first, style: const TextStyle(fontFamily: arabicFont, fontSize: 46, color: Colors.white, fontWeight: FontWeight.w700, height: 1.3)),
                ),
                const SizedBox(height: 14),
                Text(name, textAlign: TextAlign.center, style: arabicStyle(context, size: 26, weight: FontWeight.w700).copyWith(height: 1.5)),
                const SizedBox(height: 6),
                StatusBadge(label: l.booksCount(books.length), color: AuraHues.blue, icon: Icons.auto_stories_rounded),
              ]),
            ),
            FutureBuilder<AuthorDetails>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) return const Padding(padding: EdgeInsets.all(28), child: Center(child: AuraProgress()));
                final bio = snap.data?.biography?.trim();
                if (bio == null || bio.isEmpty) return const SizedBox(height: 8);
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionLabel(l.biography),
                  Reveal(child: AuraCard(child: _ExpandableText(bio))),
                ]);
              },
            ),
            SectionLabel(l.authorBooks),
            AuraCard(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(children: [for (final b in books) BookTile(book: b, onTap: () => openBook(context, b.id))]),
            ),
            if (books.isEmpty) Padding(padding: const EdgeInsets.all(16), child: Text(l.noResults, style: TextStyle(color: a.muted))),
          ]),
        ),
      ]),
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
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
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
            child: AuraIconButton(icon: _open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 36, onTap: () => setState(() => _open = !_open)),
          ),
      ]);
}
