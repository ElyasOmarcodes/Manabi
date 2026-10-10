import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/backend/backend.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../core/turath/arabic_match.dart';
import '../../state/reading_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Opens a book at an internal page. [highlight] marks a quote or search
/// term on that page; [search] opens the in-book search right away.
void openReader(BuildContext context, String bookId, int page, {String? title, String? highlight, bool search = false}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId, page: page, title: title, highlight: highlight, openSearch: search)));
}

/// Reader colours: warm paper, the app theme, or a dim night page.
({Color bg, Color text, Color muted, Color bar}) readerColors(BuildContext context, String paper) {
  final a = context.aura;
  return switch (paper) {
    'night' => (bg: const Color(0xFF0B0B0E), text: const Color(0xFFCFCFD6), muted: const Color(0xFF7D7D88), bar: const Color(0xFF16161B)),
    'plain' => (bg: a.bg, text: a.text, muted: a.muted, bar: a.surface),
    _ => a.dark
        ? (bg: const Color(0xFF1B1916), text: const Color(0xFFE8E1D3), muted: const Color(0xFF9C9486), bar: const Color(0xFF24211D))
        : (bg: const Color(0xFFF8F4EB), text: const Color(0xFF2B2620), muted: const Color(0xFF8A8172), bar: const Color(0xFFFFFCF5)),
  };
}

/// A Turath-style book reader: swipe between pages, table of contents,
/// search inside the book, go to a volume and printed page, bookmarks and
/// display settings.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.bookId, required this.page, this.title, this.highlight, this.openSearch = false});
  final String bookId;
  final int page;
  final String? title;
  final String? highlight;
  final bool openSearch;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _page = widget.page < 1 ? 1 : widget.page;
  late final PageController _pages = PageController(initialPage: _page - 1);
  final _cache = <int, Future<PagePassage>>{};
  final _loaded = <int, PagePassage>{};
  BookDetails? _book;
  String? _mark;
  int? _markPage;

  ManabiBackend get _backend => context.read<SettingsController>().backend;

  @override
  void initState() {
    super.initState();
    _mark = widget.highlight;
    _markPage = widget.highlight == null ? null : _page;
    _backend.book(widget.bookId).then((b) {
      if (mounted) setState(() => _book = b);
    }).catchError((Object _) {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remember();
      if (widget.openSearch) _openSearch();
    });
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String get _title => _book?.title ?? widget.title ?? _loaded[_page]?.bookTitle ?? '';

  Future<PagePassage> _passage(int page) => _cache.putIfAbsent(page, () {
        final f = _backend.page(widget.bookId, page);
        f.then((p) {
          if (mounted) setState(() => _loaded[page] = p);
        }).catchError((Object _) {
          _cache.remove(page);
        });
        return f;
      });

  void _prefetch(int page) {
    for (final p in [page + 1, page - 1]) {
      if (p >= 1 && (_book?.pageCount == null || p <= _book!.pageCount!)) _passage(p);
    }
  }

  void _remember() => context.read<ReadingController>().savePosition(widget.bookId, _title, _page);

  void _jump(int page, {String? mark}) {
    final count = _book?.pageCount;
    final target = page.clamp(1, count ?? (page < 1 ? 1 : page));
    setState(() {
      _mark = mark;
      _markPage = mark == null ? null : target;
    });
    _pages.jumpToPage(target - 1);
  }

  String _locationLabel(BuildContext context, int page) {
    final l = context.l;
    final at = _book?.locate(page);
    final p = _loaded[page];
    final volume = at?.volume ?? p?.volume;
    final printed = at?.printed ?? p?.printedPage;
    return [
      if (volume != null && (_book?.volumes.length ?? 2) > 1) '${l.volumeShort} $volume',
      if (printed != null) '${l.page} $printed',
    ].join(' · ');
  }

  String _citation(PagePassage p) => '${p.citation ?? p.bookTitle}\n${p.url}';

  Future<void> _openSearch() async {
    final hit = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookSearchSheet(bookId: widget.bookId, backend: _backend),
    );
    if (hit != null) _jump(hit.$1, mark: hit.$2);
  }

  Future<void> _openToc() async {
    final book = _book;
    if (book == null || book.toc.isEmpty) return;
    final page = await showModalBottomSheet<int>(context: context, isScrollControlled: true, builder: (_) => _TocSheet(book: book, current: _page));
    if (page != null) _jump(page);
  }

  Future<void> _openGoTo() async {
    final page = await showDialog<int>(context: context, builder: (_) => _GoToDialog(book: _book, current: _page));
    if (page != null) _jump(page);
  }

  Future<void> _openDisplay() => showModalBottomSheet(context: context, builder: (_) => const _DisplaySheet());

  Future<void> _menu(String action) async {
    final l = context.l;
    final p = _loaded[_page];
    switch (action) {
      case 'bookmark':
        final at = _book?.locate(_page);
        await context.read<ReadingController>().toggleBookmark(Bookmark(
              bookId: widget.bookId,
              bookTitle: _title,
              page: _page,
              volume: at?.volume ?? p?.volume,
              printed: at?.printed ?? p?.printedPage,
              heading: _book?.headingFor(_page)?.title ?? p?.headings.lastOrNull,
              savedAt: DateTime.now(),
            ));
      case 'copy' when p != null:
        await copyText(context, '${p.text}\n\n— ${_citation(p)}');
      case 'cite' when p != null:
        await copyText(context, _citation(p));
      case 'share' when p != null:
        await SharePlus.instance.share(ShareParams(text: '${p.text}\n\n— ${_citation(p)}', subject: p.bookTitle));
      case 'turath':
        await openUrl(p?.url ?? 'https://app.turath.io/book/${widget.bookId}?page=$_page');
      case 'shamela' when p?.shamelaUrl != null:
        await openUrl(p!.shamelaUrl!);
      case 'display':
        await _openDisplay();
    }
    if (action == 'copy' && p == null && mounted) toast(context, l.loading);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final reading = context.watch<ReadingController>();
    final c = readerColors(context, reading.paper);
    final count = _book?.pageCount;
    final heading = _book?.headingFor(_page)?.title ?? _loaded[_page]?.headings.lastOrNull;
    final bookmarked = reading.isBookmarked(widget.bookId, _page);
    final current = _loaded[_page];

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          // Top bar: book and chapter, search, contents, more.
          Container(
            color: c.bar,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Row(children: [
              RoundIconButton(
                icon: Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                filled: false,
                color: c.text,
                onTap: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700, color: c.text).copyWith(height: 1.45)),
                    if (heading != null)
                      Text(heading, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 12.5, color: c.muted).copyWith(height: 1.4)),
                  ]),
                ),
              ),
              RoundIconButton(icon: Icons.search_rounded, tooltip: l.searchInBook, filled: false, color: c.text, onTap: _openSearch),
              if (_book?.toc.isNotEmpty ?? false) RoundIconButton(icon: Icons.list_rounded, tooltip: l.tableOfContents, filled: false, color: c.text, onTap: _openToc),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: c.text),
                onSelected: _menu,
                itemBuilder: (_) => [
                  _item('bookmark', bookmarked ? Icons.bookmark_remove_rounded : Icons.bookmark_add_outlined, bookmarked ? l.removeBookmark : l.bookmarkPage),
                  _item('copy', Icons.copy_rounded, l.copyPage),
                  _item('cite', Icons.format_quote_rounded, l.copyCitation),
                  _item('share', Icons.ios_share_rounded, l.sharePage),
                  _item('turath', Icons.open_in_new_rounded, l.openLink),
                  if (current?.shamelaUrl != null) _item('shamela', Icons.public_rounded, l.openShamela),
                  _item('display', Icons.text_fields_rounded, l.readerDisplay),
                ],
              ),
            ]),
          ),
          // Pages: book order is right to left whatever the app language.
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                onPageChanged: (i) {
                  setState(() => _page = i + 1);
                  _remember();
                  _prefetch(_page);
                },
                itemBuilder: (context, i) => _PageView(
                  key: ValueKey(i),
                  future: _passage(i + 1),
                  colors: c,
                  mark: _markPage == i + 1 ? _mark : null,
                  bookmarked: reading.isBookmarked(widget.bookId, i + 1),
                  location: _locationLabel(context, i + 1),
                  onRetry: () => setState(() => _cache.remove(i + 1)),
                ),
              ),
            ),
          ),
          // Bottom bar: page slider and navigation.
          Container(
            color: c.bar,
            padding: EdgeInsets.fromLTRB(8, 4, 8, MediaQuery.paddingOf(context).bottom + 6),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (count != null && count > 1)
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7)),
                    child: Slider(
                      value: _page.clamp(1, count).toDouble(),
                      min: 1,
                      max: count.toDouble(),
                      onChanged: (v) => setState(() => _page = v.round()),
                      onChangeEnd: (v) => _jump(v.round()),
                    ),
                  ),
                Row(children: [
                  RoundIconButton(icon: Icons.chevron_right_rounded, tooltip: l.previousPage, filled: false, color: c.text, onTap: _page > 1 ? () => _jump(_page - 1) : null),
                  Expanded(
                    child: Pressable(
                      onTap: _openGoTo,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_locationLabel(context, _page).isEmpty ? '${l.page} $_page' : _locationLabel(context, _page),
                            style: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w700, color: c.text)),
                        Text(count == null ? '${l.turathPage} $_page' : l.pageOf(_page, count), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: c.muted)),
                      ]),
                    ),
                  ),
                  RoundIconButton(
                    icon: Icons.chevron_left_rounded,
                    tooltip: l.nextPage,
                    filled: false,
                    color: c.text,
                    onTap: count == null || _page < count ? () => _jump(_page + 1) : null,
                  ),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) => PopupMenuItem(
        value: value,
        child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Flexible(child: Text(label, style: const TextStyle(fontFamily: uiFont)))]),
      );
}

/// One page: chapter, text with highlighted matches, footnotes, page number.
class _PageView extends StatelessWidget {
  const _PageView({super.key, required this.future, required this.colors, required this.mark, required this.bookmarked, required this.location, required this.onRetry});
  final Future<PagePassage> future;
  final ({Color bg, Color text, Color muted, Color bar}) colors;
  final String? mark;
  final bool bookmarked;
  final String location;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final reading = context.watch<ReadingController>();
    final scale = context.watch<SettingsController>().arabicScale * reading.fontScale;
    return FutureBuilder<PagePassage>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) return const Center(child: TypingDots());
        if (snap.hasError) return ErrorPanel(code: mapError(snap.error!).code, onRetry: onRetry);
        final p = snap.data!;
        final split = RegExp(r'\n?_{5,}\n?').firstMatch(p.text);
        final body = split == null ? p.text : p.text.substring(0, split.start);
        final notes = split == null ? '' : p.text.substring(split.end).trim();
        final style = arabicStyle(context, size: 20, scale: scale, color: colors.text).copyWith(height: reading.lineHeight);
        return ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 28), children: [
          ReadingWidth(
            maxWidth: 720,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (p.headings.isNotEmpty || bookmarked)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    if (p.headings.isNotEmpty)
                      Expanded(
                        child: Text(p.headings.last, maxLines: 2, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 14.5, weight: FontWeight.w700, color: a.accent).copyWith(height: 1.6)),
                      )
                    else
                      const Spacer(),
                    if (bookmarked) Icon(Icons.bookmark_rounded, color: AuraHues.rose, size: 20),
                  ]),
                ),
              SelectableText.rich(_marked(context, body.trim(), mark, style), textDirection: TextDirection.rtl),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 18),
                Align(alignment: AlignmentDirectional.centerStart, child: SizedBox(width: 90, child: Divider(color: colors.muted.withValues(alpha: 0.5)))),
                const SizedBox(height: 6),
                SelectableText.rich(
                  _marked(context, notes, mark, arabicStyle(context, size: 15.5, scale: scale, color: colors.muted).copyWith(height: reading.lineHeight * 0.9)),
                  textDirection: TextDirection.rtl,
                ),
              ],
              const SizedBox(height: 22),
              Center(child: Text(location, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: colors.muted))),
            ]),
          ),
        ]);
      },
    );
  }

  TextSpan _marked(BuildContext context, String text, String? query, TextStyle style) {
    final ranges = arabicMatches(text, query);
    if (ranges.isEmpty) return TextSpan(text: text, style: style);
    final mark = TextStyle(backgroundColor: AuraHues.amber.withValues(alpha: context.aura.dark ? 0.35 : 0.3));
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e) in ranges) {
      if (s < at) continue;
      spans
        ..add(TextSpan(text: text.substring(at, s)))
        ..add(TextSpan(text: text.substring(s, e), style: mark));
      at = e;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

/// Search inside one book; returns (page, query) for the chosen hit.
class _BookSearchSheet extends StatefulWidget {
  const _BookSearchSheet({required this.bookId, required this.backend});
  final String bookId;
  final ManabiBackend backend;
  @override
  State<_BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<_BookSearchSheet> {
  final _field = TextEditingController();
  final _items = <PagePassage>[];
  String _q = '';
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    final q = more ? _q : _field.text.trim();
    if (q.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _q = q;
      if (!more) {
        _items.clear();
        _page = 0;
      }
    });
    try {
      final r = await widget.backend.search(q, page: _page + 1, scope: SearchScope(bookId: widget.bookId));
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
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: AuraSearchField(controller: _field, hint: l.searchInBookHint, rtl: true, autofocus: true, onSubmitted: (_) => _search()),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Align(alignment: AlignmentDirectional.centerStart, child: Text(l.matches(_total), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted))),
            ),
          Expanded(
            child: _error != null && _items.isEmpty
                ? ErrorPanel(code: _error, onRetry: _search)
                : _items.isEmpty
                    ? Center(child: _loading ? const TypingDots() : (_q.isEmpty ? const SizedBox() : Text(l.noMatchesInBook, style: TextStyle(fontFamily: uiFont, color: a.muted))))
                    : ListView.separated(
                        controller: scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          if (i == _items.length) {
                            return Center(
                              child: _items.length >= _total
                                  ? const SizedBox()
                                  : _loading
                                      ? const TypingDots()
                                      : SoftButton(onTap: () => _search(more: true), label: l.loadMore, icon: Icons.expand_more_rounded),
                            );
                          }
                          final p = _items[i];
                          final where = [if (p.volume != null) '${l.volumeShort} ${p.volume}', if (p.printedPage != null) '${l.page} ${p.printedPage}'].join(' · ');
                          return Material(
                            color: a.surfaceAlt,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: p.internalPage == null ? null : () => Navigator.of(context).pop((p.internalPage!, _q)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Icon(Icons.description_outlined, size: 15, color: a.accent),
                                      const SizedBox(width: 6),
                                      Text(where.isEmpty ? '${l.turathPage} ${p.internalPage}' : where,
                                          style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w700, color: a.accent)),
                                      if (p.headings.isNotEmpty) ...[
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(p.headings.last, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 12.5, color: a.muted))),
                                      ],
                                    ]),
                                    const SizedBox(height: 6),
                                    Text.rich(_hit(context, p.snippet ?? p.text), maxLines: 4, overflow: TextOverflow.ellipsis),
                                  ]),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  TextSpan _hit(BuildContext context, String text) {
    final style = arabicStyle(context, size: 15.5).copyWith(height: 1.85);
    final ranges = arabicMatches(text, _q);
    if (ranges.isEmpty) return TextSpan(text: text, style: style);
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e) in ranges) {
      if (s < at) continue;
      spans
        ..add(TextSpan(text: text.substring(at, s)))
        ..add(TextSpan(text: text.substring(s, e), style: TextStyle(color: context.aura.accent, fontWeight: FontWeight.w700)));
      at = e;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

/// Table of contents; the chapter of the current page is marked.
class _TocSheet extends StatelessWidget {
  const _TocSheet({required this.book, required this.current});
  final BookDetails book;
  final int current;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final here = book.headingFor(current);
    final index = here == null ? 0 : book.toc.indexOf(here);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(children: [
            Icon(Icons.list_rounded, color: a.accent),
            const SizedBox(width: 8),
            Text(l.tableOfContents, style: TextStyle(fontFamily: uiFont, fontSize: 16, fontWeight: FontWeight.w700, color: a.text)),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            controller: scroll,
            itemCount: book.toc.length,
            padding: const EdgeInsets.only(bottom: 24),
            itemBuilder: (context, i) {
              final e = book.toc[i];
              final selected = i == index;
              return Directionality(
                textDirection: TextDirection.rtl,
                child: InkWell(
                  onTap: e.page == null ? null : () => Navigator.of(context).pop(e.page),
                  child: Container(
                    color: selected ? a.accentTint : null,
                    padding: EdgeInsetsDirectional.fromSTEB(20.0 + (e.level - 1).clamp(0, 4) * 18, 10, 20, 10),
                    child: Row(children: [
                      Expanded(
                        child: Text(e.title,
                            style: arabicStyle(context, size: e.level <= 1 ? 16 : 15, weight: e.level <= 1 || selected ? FontWeight.w700 : FontWeight.w400, color: selected ? a.accent : a.text)
                                .copyWith(height: 1.6)),
                      ),
                      if (e.page != null) Text('${e.page}', style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Jump to a volume and printed page, or to a Turath page number.
class _GoToDialog extends StatefulWidget {
  const _GoToDialog({required this.book, required this.current});
  final BookDetails? book;
  final int current;
  @override
  State<_GoToDialog> createState() => _GoToDialogState();
}

class _GoToDialogState extends State<_GoToDialog> {
  late final hasMap = widget.book?.pageMap.isNotEmpty ?? false;
  late bool _printed = hasMap;
  late String _volume = widget.book?.locate(widget.current).volume ?? widget.book?.volumes.firstOrNull ?? '1';
  final _number = TextEditingController();

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _submit() {
    final n = int.tryParse(_number.text.trim());
    if (n == null) return;
    final page = _printed ? widget.book?.internalFor(_volume, n) : n;
    if (page != null) Navigator.of(context).pop(page);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final volumes = widget.book?.volumes ?? const <String>[];
    return AlertDialog(
      title: Text(l.goToPage, style: const TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (hasMap)
          SegmentedButton<bool>(
            segments: [ButtonSegment(value: true, label: Text(l.printedPage)), ButtonSegment(value: false, label: Text(l.turathPage))],
            selected: {_printed},
            onSelectionChanged: (s) => setState(() => _printed = s.first),
          ),
        const SizedBox(height: 14),
        if (_printed && volumes.length > 1) ...[
          DropdownButtonFormField<String>(
            initialValue: volumes.contains(_volume) ? _volume : volumes.first,
            decoration: InputDecoration(labelText: l.volume),
            items: [for (final v in volumes) DropdownMenuItem(value: v, child: Text(v))],
            onChanged: (v) => setState(() => _volume = v ?? _volume),
          ),
          const SizedBox(height: 12),
        ],
        TextField(
          controller: _number,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(labelText: _printed ? l.printedPage : l.turathPage),
          onSubmitted: (_) => _submit(),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: _submit, child: Text(l.go)),
      ],
    );
  }
}

/// Reader text size, line spacing and page colour.
class _DisplaySheet extends StatelessWidget {
  const _DisplaySheet();
  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 2),
          child: Text(t, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: a.muted)),
        );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.readerDisplay, style: TextStyle(fontFamily: uiFont, fontSize: 16, fontWeight: FontWeight.w700, color: a.text)),
          label(l.textSize),
          Slider(value: r.fontScale, min: 0.8, max: 1.6, divisions: 8, onChanged: r.setFontScale),
          label(l.lineSpacing),
          Slider(value: r.lineHeight, min: 1.7, max: 2.7, divisions: 5, onChanged: r.setLineHeight),
          label(l.paperTheme),
          const SizedBox(height: 6),
          Row(children: [
            for (final (value, name) in [('paper', l.paperWarm), ('plain', l.paperPlain), ('night', l.paperNight)])
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Pressable(
                    onTap: () => r.setPaper(value),
                    child: Container(
                      height: 54,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: readerColors(context, value).bg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: r.paper == value ? a.accent : a.border, width: r.paper == value ? 2 : 1),
                      ),
                      child: Text(name, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, color: readerColors(context, value).text)),
                    ),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
