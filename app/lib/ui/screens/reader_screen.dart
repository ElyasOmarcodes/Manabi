import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../core/turath/arabic_match.dart';
import '../../state/nav_controller.dart';
import '../../state/reading_controller.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'settings_pages.dart' show ReadingSettingsPage;

/// Opens a book at an internal page. [highlight] marks a quote or search
/// term on that page; [search] opens the in-book search right away.
void openReader(BuildContext context, String bookId, int page, {String? title, String? highlight, bool search = false}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId, page: page, title: title, highlight: highlight, openSearch: search)));
}

typedef ReaderColors = ({Color bg, Color text, Color muted, Color bar});

/// Reader colours: warm paper, yellow paper, the app theme, or a dim night page.
ReaderColors readerColors(BuildContext context, String paper) {
  final a = context.aura;
  return switch (paper) {
    'night' => (bg: const Color(0xFF0B0B0E), text: const Color(0xFFCFCFD6), muted: const Color(0xFF7D7D88), bar: const Color(0xFF16161B)),
    'plain' => (bg: a.bg, text: a.text, muted: a.muted, bar: a.surface),
    'sepia' => a.dark
        ? (bg: const Color(0xFF221D12), text: const Color(0xFFEADFC4), muted: const Color(0xFFA1957A), bar: const Color(0xFF2B2517))
        : (bg: const Color(0xFFF7EDCF), text: const Color(0xFF33291A), muted: const Color(0xFF8C7B57), bar: const Color(0xFFFBF4DE)),
    _ => a.dark
        ? (bg: const Color(0xFF1B1916), text: const Color(0xFFE8E1D3), muted: const Color(0xFF9C9486), bar: const Color(0xFF24211D))
        : (bg: const Color(0xFFF8F4EB), text: const Color(0xFF2B2620), muted: const Color(0xFF8A8172), bar: const Color(0xFFFFFCF5)),
  };
}

/// The book text style for the reader settings.
TextStyle bookTextStyle(BuildContext context, ReadingController r, {double size = 20, required Color color, FontWeight weight = FontWeight.w400}) {
  final scale = context.read<SettingsController>().arabicScale * r.fontScale;
  return TextStyle(
    fontFamily: r.fontFamily == 'vazir' ? uiFont : arabicFont,
    fontSize: size * scale,
    height: r.lineHeight,
    fontWeight: weight,
    color: color,
  );
}

/// "Vol 1 · p. 11" for an internal page, in the reader's digit style.
String pageLabel(BuildContext context, BookDetails? book, int page, {PagePassage? passage, String digits = 'latin'}) {
  final l = context.l;
  final at = book?.locate(page);
  final volume = at?.volume ?? passage?.volume;
  final printed = at?.printed ?? passage?.printedPage;
  final parts = [
    if (volume != null && (book?.volumes.length ?? 2) > 1) '${l.volumeShort} ${readerDigits(volume, digits)}',
    if (printed != null) '${l.page} ${readerDigits(printed, digits)}',
  ];
  return parts.isEmpty ? '${l.turathPage} ${readerDigits(page, digits)}' : parts.join(' · ');
}

/// A Turath-style book reader: continuous or page-by-page reading, a side
/// panel with contents, bookmarks, highlights and history, in-book search,
/// go to a volume and printed page, reading tools and highlighting.
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

  /// First page of the forward list in continuous mode; pages before it
  /// grow upwards, so jumping anywhere is instant.
  late int _anchor = _page;
  ScrollController _scroll = ScrollController();
  late PageController _pages = PageController(initialPage: _page - 1);
  String? _modeInUse;

  final _viewKey = GlobalKey();
  final _scaffold = GlobalKey<ScaffoldState>();
  final _pageKeys = <int, GlobalKey>{};
  final _cache = <int, Future<PagePassage>>{};
  final _loaded = <int, PagePassage>{};
  BookDetails? _book;
  String? _mark;
  int? _markPage;
  bool _immersive = false;
  bool _panel = true;
  bool _wake = false;
  Timer? _scrollTick;

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
    _scrollTick?.cancel();
    _scroll.dispose();
    _pages.dispose();
    if (_wake) WakelockPlus.disable().catchError((Object _) {});
    if (_immersive) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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

  bool _exists(int p) => p >= 1 && (_book?.pageCount == null || p <= _book!.pageCount!);

  void _prefetch(int page) {
    for (final p in [page + 1, page + 2, page - 1]) {
      if (_exists(p)) _passage(p);
    }
  }

  void _remember() => context.read<ReadingController>().savePosition(widget.bookId, _title, _page);

  void _setPage(int page) {
    if (page == _page) return;
    setState(() => _page = page);
    _remember();
    _prefetch(page);
  }

  void _jump(int page, {String? mark}) {
    final count = _book?.pageCount;
    final target = count == null ? (page < 1 ? 1 : page) : page.clamp(1, count);
    setState(() {
      _mark = mark;
      _markPage = mark == null ? null : target;
      _page = target;
      if (_modeInUse == 'pages') {
        if (_pages.hasClients) _pages.jumpToPage(target - 1);
      } else {
        final old = _scroll;
        _anchor = target;
        _scroll = ScrollController();
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
    });
    _remember();
  }

  /// Rebuilds the scroll controllers when the reading mode changes, so both
  /// modes open at the current page.
  void _syncMode(String mode) {
    if (_modeInUse == mode) return;
    if (_modeInUse != null) {
      final oldScroll = _scroll;
      final oldPages = _pages;
      _anchor = _page;
      _scroll = ScrollController();
      _pages = PageController(initialPage: _page - 1);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldScroll.dispose();
        oldPages.dispose();
      });
    }
    _modeInUse = mode;
  }

  void _syncWake(bool on) {
    if (on == _wake) return;
    _wake = on;
    (on ? WakelockPlus.enable() : WakelockPlus.disable()).catchError((Object _) {});
  }

  /// In continuous mode, the current page is the one under the top third.
  void _onScroll() {
    if (_scrollTick?.isActive ?? false) return;
    _scrollTick = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      final view = _viewKey.currentContext?.findRenderObject() as RenderBox?;
      if (view == null || !view.attached) return;
      final probe = view.localToGlobal(Offset(0, view.size.height * 0.3)).dy;
      for (final e in _pageKeys.entries) {
        final box = e.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached) continue;
        final top = box.localToGlobal(Offset.zero).dy;
        if (top <= probe && top + box.size.height > probe) {
          _setPage(e.key);
          break;
        }
      }
      _pageKeys.removeWhere((p, k) => (p - _page).abs() > 40 && k.currentContext == null);
    });
  }

  Future<void> _openSearch() async {
    final hit = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookSearchSheet(bookId: widget.bookId, backend: _backend),
    );
    if (hit != null) _jump(hit.$1, mark: hit.$2);
  }

  Future<void> _openGoTo() async {
    final page = await showDialog<int>(context: context, builder: (_) => _GoToDialog(book: _book, current: _page));
    if (page != null) _jump(page);
  }

  void _openPanel(bool wide) {
    if (wide) {
      setState(() => _panel = !_panel);
    } else if (Directionality.of(context) == TextDirection.rtl) {
      _scaffold.currentState?.openDrawer();
    } else {
      _scaffold.currentState?.openEndDrawer();
    }
  }

  Future<void> _openTools() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ToolsSheet(
          book: _book,
          current: _page,
          onGo: _jump,
          onShare: () => _pageAction('share', _page),
          onFullScreen: _toggleImmersive,
        ),
      );

  void _toggleImmersive() {
    setState(() => _immersive = !_immersive);
    if (!kIsWeb) SystemChrome.setEnabledSystemUIMode(_immersive ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge);
  }

  String _citation(PagePassage p) => '${p.citation ?? p.bookTitle}\n${p.url}';

  Future<void> _pageAction(String action, int page) async {
    final l = context.l;
    final p = _loaded[page];
    final reading = context.read<ReadingController>();
    switch (action) {
      case 'bookmark':
        final at = _book?.locate(page);
        await reading.toggleBookmark(Bookmark(
          bookId: widget.bookId,
          bookTitle: _title,
          page: page,
          volume: at?.volume ?? p?.volume,
          printed: at?.printed ?? p?.printedPage,
          heading: _book?.headingFor(page)?.title ?? p?.headings.lastOrNull,
          savedAt: DateTime.now(),
        ));
      case 'copy' when p != null:
        await copyText(context, '${p.text}\n\n— ${_citation(p)}');
      case 'cite' when p != null:
        await copyText(context, _citation(p));
      case 'share' when p != null:
        await SharePlus.instance.share(ShareParams(text: '${p.text}\n\n— ${_citation(p)}', subject: p.bookTitle));
      case 'ask':
        final catalog = context.read<CatalogService>();
        final entry = catalog.book(widget.bookId);
        context.read<NavController>().askWithin(SearchScope.all.withBook(widget.bookId, _title).withAuthor(entry?.authorId, catalog.author(entry?.authorId)?.name));
        Navigator.of(context).popUntil((r) => r.isFirst);
      case 'turath':
        await openUrl(p?.url ?? 'https://app.turath.io/book/${widget.bookId}?page=$page');
      case 'shamela' when p?.shamelaUrl != null:
        await openUrl(p!.shamelaUrl!);
      case 'settings':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadingSettingsPage()));
      default:
        if (p == null && mounted) toast(context, l.loading);
    }
  }

  Future<void> _highlight(int page, String text) async {
    final reading = context.read<ReadingController>();
    await reading.addHighlight(Highlight(bookId: widget.bookId, bookTitle: _title, page: page, text: text.trim(), color: reading.highlightColor, savedAt: DateTime.now()));
    if (mounted) toast(context, context.l.highlightSaved);
  }

  Future<void> _copyQuote(int page, String text) async {
    final p = _loaded[page];
    await copyText(context, '«${text.trim()}»\n\n— ${p == null ? _title : _citation(p)}');
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final ctrl = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
    if (ctrl && e.logicalKey == LogicalKeyboardKey.keyF) {
      _openSearch();
      return KeyEventResult.handled;
    }
    // Book order is right to left: the left arrow goes forward.
    final next = {LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.pageDown};
    final prev = {LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.pageUp};
    if (next.contains(e.logicalKey) && _exists(_page + 1)) {
      _jump(_page + 1);
      return KeyEventResult.handled;
    }
    if (prev.contains(e.logicalKey) && _page > 1) {
      _jump(_page - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final reading = context.watch<ReadingController>();
    _syncMode(reading.readingMode);
    _syncWake(reading.keepAwake);
    final c = readerColors(context, reading.paper);
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= 980;
      final rtlApp = Directionality.of(context) == TextDirection.rtl;
      final panel = _BookPanel(
        bookId: widget.bookId,
        title: _title,
        book: _book,
        current: _page,
        digits: reading.digits,
        onJump: (page, {mark}) {
          if (!wide) Navigator.of(context).maybePop();
          _jump(page, mark: mark);
        },
      );
      final drawer = Drawer(width: box.maxWidth.clamp(0, 420) * 0.9, backgroundColor: context.aura.surface, child: SafeArea(child: panel));
      final reader = Column(children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _immersive ? const SizedBox(width: double.infinity) : _topBar(context, c, wide),
        ),
        Expanded(child: Stack(children: [
          Positioned.fill(child: reading.readingMode == 'pages' ? _pagesView(c) : _scrollView(c)),
          if (_immersive)
            PositionedDirectional(
              end: 14,
              bottom: MediaQuery.paddingOf(context).bottom + 14,
              child: Material(
                color: c.bar.withValues(alpha: 0.92),
                shape: const CircleBorder(),
                elevation: 2,
                child: IconButton(tooltip: context.l.exitFullScreen, icon: Icon(Icons.fullscreen_exit_rounded, color: c.text), onPressed: _toggleImmersive),
              ),
            ),
        ])),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _immersive ? const SizedBox(width: double.infinity) : _bottomBar(context, c, wide),
        ),
      ]);
      return Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Scaffold(
          key: _scaffold,
          backgroundColor: c.bg,
          drawer: !wide && rtlApp ? drawer : null,
          endDrawer: !wide && !rtlApp ? drawer : null,
          body: SafeArea(
            top: !_immersive,
            bottom: false,
            child: wide && _panel && !_immersive
                ? Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(children: [
                      Container(
                        width: 350,
                        decoration: BoxDecoration(color: context.aura.surface, border: BorderDirectional(end: BorderSide(color: context.aura.border))),
                        child: Directionality(textDirection: Directionality.of(context), child: panel),
                      ),
                      Expanded(child: Directionality(textDirection: Directionality.of(context), child: reader)),
                    ]),
                  )
                : reader,
          ),
        ),
      );
    });
  }

  Widget _topBar(BuildContext context, ReaderColors c, bool wide) {
    final l = context.l;
    final reading = context.read<ReadingController>();
    final path = _book?.headingPath(_page).map((e) => e.title).toList() ?? _loaded[_page]?.headings ?? const <String>[];
    final catalog = context.read<CatalogService>();
    final author = catalog.author(_book?.authorId ?? catalog.book(widget.bookId)?.authorId)?.name;
    final bookmarked = reading.isBookmarked(widget.bookId, _page);
    final current = _loaded[_page];
    return Container(
      color: c.bar,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: Row(children: [
        RoundIconButton(
          icon: Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          filled: false,
          color: c.text,
          onTap: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: _title, style: arabicStyle(context, size: 15, weight: FontWeight.w700, color: c.text)),
                  if (author != null) TextSpan(text: '  ·  $author', style: arabicStyle(context, size: 12.5, color: c.muted)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(height: 1.45),
              ),
              if (path.isNotEmpty)
                Text(path.join('  ←  '), maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 12, color: c.muted).copyWith(height: 1.4)),
            ]),
          ),
        ),
        RoundIconButton(
          icon: bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          tooltip: bookmarked ? l.removeBookmark : l.bookmarkPage,
          filled: false,
          color: bookmarked ? AuraHues.rose : c.text,
          onTap: () => _pageAction('bookmark', _page),
        ),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded, color: c.text),
          onSelected: (v) => _pageAction(v, _page),
          itemBuilder: (_) => [
            menuItem('copy', Icons.copy_rounded, l.copyPage),
            menuItem('cite', Icons.format_quote_rounded, l.copyCitation),
            menuItem('share', Icons.ios_share_rounded, l.sharePage),
            menuItem('ask', Icons.auto_awesome_rounded, l.askInThisBook),
            menuItem('turath', Icons.open_in_new_rounded, l.openLink),
            if (current?.shamelaUrl != null) menuItem('shamela', Icons.public_rounded, l.openShamela),
            menuItem('settings', Icons.settings_outlined, l.moreReadingSettings),
          ],
        ),
      ]),
    );
  }

  Widget _bottomBar(BuildContext context, ReaderColors c, bool wide) {
    final l = context.l;
    final reading = context.read<ReadingController>();
    final count = _book?.pageCount;
    Widget tool(IconData icon, String tip, VoidCallback onTap, {bool active = false}) => Tooltip(
          message: tip,
          child: Pressable(
            onTap: onTap,
            scale: 0.9,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: active ? context.aura.accent.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 21, color: active ? context.aura.accent : c.text),
            ),
          ),
        );
    final pagesMode = reading.readingMode == 'pages';
    return Container(
      color: c.bar,
      padding: EdgeInsets.fromLTRB(6, 2, 6, MediaQuery.paddingOf(context).bottom + 4),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(children: [
          tool(Icons.toc_rounded, l.tableOfContents, () => _openPanel(wide), active: wide && _panel),
          tool(Icons.manage_search_rounded, l.searchInBook, _openSearch),
          tool(Icons.tune_rounded, l.readerTools, _openTools),
          tool(Icons.fullscreen_rounded, l.fullScreen, _toggleImmersive),
          Expanded(
            child: count != null && count > 1
                ? SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                      inactiveTrackColor: c.muted.withValues(alpha: 0.25),
                    ),
                    child: Slider(
                      value: _page.clamp(1, count).toDouble(),
                      min: 1,
                      max: count.toDouble(),
                      label: pageLabel(context, _book, _page, digits: reading.digits),
                      onChanged: (v) => setState(() => _page = v.round()),
                      onChangeEnd: (v) => _jump(v.round()),
                    ),
                  )
                : const SizedBox(),
          ),
          if (pagesMode) tool(Icons.chevron_left_rounded, l.previousPage, () => _page > 1 ? _jump(_page - 1) : null),
          Pressable(
            onTap: _openGoTo,
            child: Container(
              constraints: const BoxConstraints(minWidth: 64),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(pageLabel(context, _book, _page, passage: _loaded[_page], digits: reading.digits),
                    style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
                if (count != null)
                  Text('${readerDigits(((_page / count) * 100).round(), reading.digits)}٪',
                      style: TextStyle(fontFamily: uiFont, fontSize: 10.5, color: c.muted)),
              ]),
            ),
          ),
          if (pagesMode) tool(Icons.chevron_right_rounded, l.nextPage, () => _exists(_page + 1) ? _jump(_page + 1) : null),
        ]),
      ),
    );
  }

  Widget _block(int page, ReaderColors c, {required bool continuous}) => _PageBlock(
        key: _pageKeys.putIfAbsent(page, GlobalKey.new),
        page: page,
        future: _passage(page),
        colors: c,
        continuous: continuous,
        mark: _markPage == page ? _mark : null,
        book: _book,
        onRetry: () => setState(() => _cache.remove(page)),
        onAction: (a) => _pageAction(a, page),
        onHighlight: (t) => _highlight(page, t),
        onCopyQuote: (t) => _copyQuote(page, t),
      );

  Widget _scrollView(ReaderColors c) {
    final count = _book?.pageCount;
    final center = ValueKey('center-$_anchor');
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        _onScroll();
        return false;
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scrollbar(
          controller: _scroll,
          child: CustomScrollView(
            key: _viewKey,
            controller: _scroll,
            center: center,
            scrollCacheExtent: const ScrollCacheExtent.pixels(1400),
            slivers: [
              SliverList(
                delegate: SliverChildBuilderDelegate((context, i) => _block(_anchor - 1 - i, c, continuous: true), childCount: _anchor - 1),
              ),
              SliverList(
                key: center,
                delegate: SliverChildBuilderDelegate((context, i) => _block(_anchor + i, c, continuous: true), childCount: count == null ? null : count - _anchor + 1),
              ),
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.sizeOf(context).height * 0.4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pagesView(ReaderColors c) => Directionality(
        textDirection: TextDirection.rtl,
        child: PageView.builder(
          key: _viewKey,
          controller: _pages,
          itemCount: _book?.pageCount,
          onPageChanged: (i) => _setPage(i + 1),
          itemBuilder: (context, i) => SingleChildScrollView(child: _block(i + 1, c, continuous: false)),
        ),
      );
}

PopupMenuItem<String> menuItem(String value, IconData icon, String label) => PopupMenuItem(
      value: value,
      child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Flexible(child: Text(label, style: const TextStyle(fontFamily: uiFont)))]),
    );

/// One book page: chapter, text with highlights and search matches,
/// footnotes and a footer with the page number and a menu.
class _PageBlock extends StatelessWidget {
  const _PageBlock({
    super.key,
    required this.page,
    required this.future,
    required this.colors,
    required this.continuous,
    required this.mark,
    required this.book,
    required this.onRetry,
    required this.onAction,
    required this.onHighlight,
    required this.onCopyQuote,
  });
  final int page;
  final Future<PagePassage> future;
  final ReaderColors colors;
  final bool continuous;
  final String? mark;
  final BookDetails? book;
  final VoidCallback onRetry;
  final ValueChanged<String> onAction;
  final ValueChanged<String> onHighlight;
  final ValueChanged<String> onCopyQuote;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    final reading = context.watch<ReadingController>();
    return FutureBuilder<PagePassage>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return SizedBox(height: continuous ? 420 : MediaQuery.sizeOf(context).height * 0.6, child: const Center(child: TypingDots()));
        }
        if (snap.hasError) return SizedBox(height: 320, child: ErrorPanel(code: mapError(snap.error!).code, onRetry: onRetry));
        final p = snap.data!;
        final split = RegExp(r'\n?_{5,}\n?').firstMatch(p.text);
        var body = (split == null ? p.text : p.text.substring(0, split.start)).trim();
        var notes = split == null ? '' : p.text.substring(split.end).trim();
        if (reading.hideDiacritics) {
          body = stripDiacritics(body);
          notes = stripDiacritics(notes);
        }
        // The chapter title usually opens the page text: show it once, styled.
        String? title;
        if (p.headings.isNotEmpty) {
          final nl = body.indexOf('\n');
          final first = nl < 0 ? body : body.substring(0, nl);
          if (first.length < 160 && normalizeForSearch(first).contains(normalizeForSearch(p.headings.last))) {
            title = first.trim();
            body = nl < 0 ? '' : body.substring(nl + 1).trim();
          }
        }
        final marks = reading.highlightsOf(p.bookId, page);
        final bookmarked = reading.isBookmarked(p.bookId, page);
        final style = bookTextStyle(context, reading, color: colors.text);
        final align = reading.justify ? TextAlign.justify : TextAlign.start;
        return Container(
          decoration: continuous ? BoxDecoration(border: Border(bottom: BorderSide(color: colors.muted.withValues(alpha: 0.22)))) : null,
          padding: EdgeInsets.fromLTRB(22, continuous ? 16 : 20, 22, 8),
          child: ReadingWidth(
            maxWidth: 760,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (title != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(title, style: bookTextStyle(context, reading, size: 17, weight: FontWeight.w700, color: a.accent).copyWith(height: 1.7)),
                ),
              SelectableText.rich(
                _marked(context, body, mark, marks, style),
                textDirection: TextDirection.rtl,
                textAlign: align,
                contextMenuBuilder: (context, state) => _menu(context, state),
              ),
              if (notes.isNotEmpty && reading.showFootnotes) ...[
                const SizedBox(height: 14),
                Align(alignment: AlignmentDirectional.centerStart, child: SizedBox(width: 90, child: Divider(color: colors.muted.withValues(alpha: 0.5)))),
                const SizedBox(height: 4),
                SelectableText.rich(
                  _marked(context, notes, mark, marks, bookTextStyle(context, reading, size: 15.5, color: colors.muted).copyWith(height: reading.lineHeight * 0.88)),
                  textDirection: TextDirection.rtl,
                  textAlign: align,
                  contextMenuBuilder: (context, state) => _menu(context, state),
                ),
              ],
              const SizedBox(height: 10),
              Row(children: [
                SizedBox(
                  width: 40,
                  child: bookmarked ? Icon(Icons.bookmark_rounded, color: AuraHues.rose, size: 18) : null,
                ),
                Expanded(
                  child: Text(pageLabel(context, book, page, passage: p, digits: reading.digits),
                      textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: colors.muted)),
                ),
                SizedBox(
                  width: 40,
                  child: PopupMenuButton<String>(
                    tooltip: l.options,
                    icon: Icon(Icons.more_horiz_rounded, color: colors.muted, size: 20),
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      menuItem('bookmark', bookmarked ? Icons.bookmark_remove_rounded : Icons.bookmark_add_outlined, bookmarked ? l.removeBookmark : l.bookmarkPage),
                      menuItem('copy', Icons.copy_rounded, l.copyPage),
                      menuItem('cite', Icons.format_quote_rounded, l.copyCitation),
                      menuItem('share', Icons.ios_share_rounded, l.sharePage),
                      menuItem('ask', Icons.auto_awesome_rounded, l.askInThisBook),
                      menuItem('turath', Icons.open_in_new_rounded, l.openLink),
                      if (p.shamelaUrl != null) menuItem('shamela', Icons.public_rounded, l.openShamela),
                    ],
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  /// Text selection menu: highlight and copy with citation come first.
  Widget _menu(BuildContext context, EditableTextState state) {
    final l = context.l;
    final value = state.textEditingValue;
    final selected = value.selection.isValid && !value.selection.isCollapsed ? value.selection.textInside(value.text) : '';
    final items = [
      if (selected.trim().isNotEmpty) ...[
        ContextMenuButtonItem(label: l.highlight, onPressed: () {
          state.hideToolbar();
          onHighlight(selected);
        }),
        ContextMenuButtonItem(label: l.copyWithCitation, onPressed: () {
          state.hideToolbar();
          onCopyQuote(selected);
        }),
      ],
      ...state.contextMenuButtonItems,
    ];
    return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: items);
  }

  TextSpan _marked(BuildContext context, String text, String? query, List<Highlight> highlights, TextStyle style) {
    final dark = context.aura.dark;
    final ranges = <(int, int, TextStyle)>[
      for (final h in highlights)
        for (final (s, e) in arabicMatches(text, h.text))
          (s, e, TextStyle(backgroundColor: highlightColors[h.color.clamp(0, highlightColors.length - 1)].withValues(alpha: dark ? 0.38 : 0.45))),
      for (final (s, e) in arabicMatches(text, query))
        (s, e, TextStyle(backgroundColor: AuraHues.amber.withValues(alpha: dark ? 0.42 : 0.38), decoration: TextDecoration.underline, decorationColor: AuraHues.amber)),
    ]..sort((x, y) => x.$1.compareTo(y.$1));
    if (ranges.isEmpty) return TextSpan(text: text, style: style);
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e, st) in ranges) {
      if (s < at) continue;
      spans
        ..add(TextSpan(text: text.substring(at, s)))
        ..add(TextSpan(text: text.substring(s, e), style: st));
      at = e;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }
}

/// The book side panel: contents, bookmarks, highlights and visited pages.
class _BookPanel extends StatefulWidget {
  const _BookPanel({required this.bookId, required this.title, required this.book, required this.current, required this.digits, required this.onJump});
  final String bookId;
  final String title;
  final BookDetails? book;
  final int current;
  final String digits;
  final void Function(int page, {String? mark}) onJump;
  @override
  State<_BookPanel> createState() => _BookPanelState();
}

class _BookPanelState extends State<_BookPanel> {
  final _expanded = <int>{};
  String _filter = '';
  final _selectedKey = GlobalKey();
  bool _scrolled = false;
  int? _expandedFor;

  /// Opens the branches above the current chapter.
  void _expandCurrent(BookDetails book) {
    final here = book.headingFor(widget.current);
    if (here == null || _expandedFor == widget.current) return;
    _expandedFor = widget.current;
    var level = here.level;
    for (var i = book.toc.indexOf(here); i >= 0; i--) {
      if (book.toc[i].level < level || i == book.toc.indexOf(here)) {
        _expanded.add(i);
        level = book.toc[i].level;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontFamily: uiFont, fontSize: 13.5),
          labelColor: a.accent,
          unselectedLabelColor: a.muted,
          indicatorColor: a.accent,
          dividerColor: a.border,
          tabs: [
            Tab(icon: const Icon(Icons.toc_rounded, size: 19), iconMargin: const EdgeInsets.only(bottom: 2), text: l.tableOfContents),
            Tab(icon: const Icon(Icons.bookmarks_outlined, size: 19), iconMargin: const EdgeInsets.only(bottom: 2), text: l.bookmarks),
            Tab(icon: const Icon(Icons.border_color_outlined, size: 19), iconMargin: const EdgeInsets.only(bottom: 2), text: l.highlights),
            Tab(icon: const Icon(Icons.history_rounded, size: 19), iconMargin: const EdgeInsets.only(bottom: 2), text: l.visitedPages),
          ],
        ),
        Expanded(
          child: TabBarView(children: [
            _contents(context),
            _bookmarks(context),
            _highlights(context),
            _history(context),
          ]),
        ),
      ]),
    );
  }

  Widget _contents(BuildContext context) {
    final a = context.aura;
    final book = widget.book;
    if (book == null) return const Center(child: TypingDots());
    if (book.toc.isEmpty) return EmptyState(icon: Icons.toc_rounded, text: context.l.tableOfContents);
    _expandCurrent(book);
    final here = book.headingFor(widget.current);
    final toc = book.toc;
    final q = _filter.trim();
    // Visible rows: every entry whose ancestors are all expanded (or matches).
    final rows = <int>[];
    if (q.isNotEmpty) {
      for (var i = 0; i < toc.length; i++) {
        if (arabicMatches(toc[i].title, q).isNotEmpty) rows.add(i);
      }
    } else {
      var hideBelow = 1 << 20;
      for (var i = 0; i < toc.length; i++) {
        final e = toc[i];
        if (e.level > hideBelow) continue;
        hideBelow = 1 << 20;
        rows.add(i);
        if (!_expanded.contains(i)) hideBelow = e.level;
      }
    }
    if (!_scrolled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _selectedKey.currentContext;
        if (ctx != null && !_scrolled) {
          _scrolled = true;
          Scrollable.ensureVisible(ctx, alignment: 0.3);
        }
      });
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: TextField(
          onChanged: (v) => setState(() => _filter = v),
          textDirection: TextDirection.rtl,
          style: TextStyle(fontFamily: uiFont, fontSize: 14, color: a.text),
          decoration: InputDecoration(
            isDense: true,
            hintText: context.l.searchHeadings,
            prefixIcon: Icon(Icons.search_rounded, size: 20, color: a.muted),
            filled: true,
            fillColor: a.surfaceAlt,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(children: [
              for (final i in rows) _tocRow(context, book, i, selected: identical(toc[i], here), flat: q.isNotEmpty),
            ]),
          ),
        ),
      ),
    ]);
  }

  Widget _tocRow(BuildContext context, BookDetails book, int i, {required bool selected, required bool flat}) {
    final a = context.aura;
    final e = book.toc[i];
    final hasChildren = i + 1 < book.toc.length && book.toc[i + 1].level > e.level;
    final open = _expanded.contains(i);
    final indent = flat ? 0.0 : (e.level - 1).clamp(0, 5) * 14.0;
    return InkWell(
      key: selected ? _selectedKey : null,
      onTap: e.page == null ? null : () => widget.onJump(e.page!),
      child: Container(
        color: selected ? a.accentTint : null,
        padding: EdgeInsetsDirectional.fromSTEB(10 + indent, 7, 6, 7),
        child: Row(children: [
          SizedBox(
            width: 26,
            child: hasChildren && !flat
                ? InkResponse(
                    radius: 16,
                    onTap: () => setState(() => open ? _expanded.remove(i) : _expanded.add(i)),
                    child: Icon(open ? Icons.expand_more_rounded : Icons.chevron_left_rounded, size: 20, color: selected ? a.accent : a.muted),
                  )
                : null,
          ),
          Expanded(
            child: Text(e.title,
                style: arabicStyle(context, size: e.level <= 1 ? 15 : 14, weight: e.level <= 1 || selected ? FontWeight.w700 : FontWeight.w400, color: selected ? a.accent : a.text)
                    .copyWith(height: 1.55)),
          ),
          if (e.page != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8),
              child: Text(_short(book, e.page!), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: selected ? a.accent : a.muted)),
            ),
        ]),
      ),
    );
  }

  /// Compact "volume/page" like Turath's contents (١/١٠).
  String _short(BookDetails book, int page) {
    final at = book.locate(page);
    if (at.printed == null) return readerDigits(page, widget.digits);
    final p = readerDigits(at.printed!, widget.digits);
    return book.volumes.length > 1 && at.volume != null ? '${readerDigits(at.volume!, widget.digits)}/$p' : p;
  }

  Widget _bookmarks(BuildContext context) {
    final reading = context.watch<ReadingController>();
    final marks = reading.bookmarksOf(widget.bookId);
    if (marks.isEmpty) return EmptyState(icon: Icons.bookmarks_outlined, text: context.l.noBookmarksYet, color: AuraHues.rose);
    return ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
      for (final b in marks)
        ListTile(
          dense: true,
          leading: const Icon(Icons.bookmark_rounded, color: AuraHues.rose),
          title: Text(b.heading ?? widget.title, maxLines: 2, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 14.5).copyWith(height: 1.5)),
          subtitle: Text(pageLabel(context, widget.book, b.page, digits: widget.digits), style: const TextStyle(fontFamily: uiFont, fontSize: 12)),
          trailing: IconButton(icon: const Icon(Icons.close_rounded, size: 18), tooltip: context.l.removeBookmark, onPressed: () => reading.toggleBookmark(b)),
          onTap: () => widget.onJump(b.page),
        ),
    ]);
  }

  Widget _highlights(BuildContext context) {
    final reading = context.watch<ReadingController>();
    final marks = reading.highlightsOf(widget.bookId)..sort((x, y) => x.page.compareTo(y.page));
    if (marks.isEmpty) return EmptyState(icon: Icons.border_color_outlined, text: context.l.noHighlights, color: AuraHues.amber);
    return ListView(padding: const EdgeInsets.all(10), children: [for (final h in marks) HighlightTile(highlight: h, book: widget.book, digits: widget.digits, onTap: () => widget.onJump(h.page, mark: h.text))]);
  }

  Widget _history(BuildContext context) {
    final reading = context.watch<ReadingController>();
    final pages = reading.visitedOf(widget.bookId);
    if (pages.isEmpty) return EmptyState(icon: Icons.history_rounded, text: context.l.noVisited);
    return ListView(padding: const EdgeInsets.symmetric(vertical: 6), children: [
      for (final p in pages)
        ListTile(
          dense: true,
          leading: Icon(p == widget.current ? Icons.radio_button_checked_rounded : Icons.history_rounded, size: 20, color: p == widget.current ? context.aura.accent : context.aura.muted),
          title: Text(widget.book?.headingFor(p)?.title ?? widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 14.5).copyWith(height: 1.5)),
          subtitle: Text(pageLabel(context, widget.book, p, digits: widget.digits), style: const TextStyle(fontFamily: uiFont, fontSize: 12)),
          onTap: () => widget.onJump(p),
        ),
    ]);
  }
}

/// A saved highlight: colour rail, passage and location.
class HighlightTile extends StatelessWidget {
  const HighlightTile({super.key, required this.highlight, this.book, this.digits = 'latin', this.showBook = false, required this.onTap});
  final Highlight highlight;
  final BookDetails? book;
  final String digits;
  final bool showBook;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final h = highlight;
    final color = highlightColors[h.color.clamp(0, highlightColors.length - 1)];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: a.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 15).copyWith(height: 1.8)),
                      const SizedBox(height: 4),
                      Row(children: [
                        Expanded(
                          child: Text(showBook ? '${h.bookTitle} · ${pageLabel(context, book, h.page, digits: digits)}' : pageLabel(context, book, h.page, digits: digits),
                              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: context.l.removeHighlight,
                          icon: Icon(Icons.delete_outline_rounded, size: 18, color: a.muted),
                          onPressed: () => context.read<ReadingController>().removeHighlight(h),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Turath-style reading tools: text size, paper, toggles, go to a page and
/// quick actions.
class _ToolsSheet extends StatefulWidget {
  const _ToolsSheet({required this.book, required this.current, required this.onGo, required this.onShare, required this.onFullScreen});
  final BookDetails? book;
  final int current;
  final void Function(int page, {String? mark}) onGo;
  final VoidCallback onShare;
  final VoidCallback onFullScreen;
  @override
  State<_ToolsSheet> createState() => _ToolsSheetState();
}

class _ToolsSheetState extends State<_ToolsSheet> {
  late String _volume = widget.book?.locate(widget.current).volume ?? widget.book?.volumes.firstOrNull ?? '1';
  late final _number = TextEditingController(text: '${widget.book?.locate(widget.current).printed ?? widget.current}');

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _go() {
    final n = int.tryParse(_number.text.trim());
    if (n == null) return;
    final hasMap = widget.book?.pageMap.isNotEmpty ?? false;
    final page = hasMap ? widget.book!.internalFor(_volume, n) : n;
    if (page == null) return;
    Navigator.of(context).pop();
    widget.onGo(page);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    final volumes = widget.book?.volumes ?? const <String>[];
    Widget toggle(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => SwitchListTile.adaptive(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: Icon(icon, size: 20, color: a.muted),
          title: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, color: a.text)),
          value: value,
          onChanged: onChanged,
        );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.86),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 0, 18, 16 + MediaQuery.viewInsetsOf(context).bottom),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(l.readerTools, style: TextStyle(fontFamily: uiFont, fontSize: 16.5, fontWeight: FontWeight.w800, color: a.text))),
              TextButton.icon(
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: Text(l.moreReadingSettings, style: const TextStyle(fontFamily: uiFont)),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadingSettingsPage()));
                },
              ),
            ]),
            const SizedBox(height: 6),
            ReaderTextControls(reading: r),
            const SizedBox(height: 10),
            PaperPicker(reading: r),
            const SizedBox(height: 6),
            ModePicker(reading: r),
            const Divider(height: 22),
            toggle(l.justifyText, Icons.format_align_justify_rounded, r.justify, r.setJustify),
            toggle(l.hideDiacritics, Icons.text_format_rounded, r.hideDiacritics, r.setHideDiacritics),
            toggle(l.showFootnotes, Icons.notes_rounded, r.showFootnotes, r.setShowFootnotes),
            if (!kIsWeb) toggle(l.keepScreenOn, Icons.light_mode_outlined, r.keepAwake, r.setKeepAwake),
            const Divider(height: 22),
            // Go to a volume and printed page.
            Row(children: [
              if (volumes.length > 1) ...[
                SizedBox(
                  width: 96,
                  child: DropdownButtonFormField<String>(
                    initialValue: volumes.contains(_volume) ? _volume : volumes.first,
                    isDense: true,
                    decoration: InputDecoration(labelText: l.volume, isDense: true),
                    items: [for (final v in volumes) DropdownMenuItem(value: v, child: Text(v))],
                    onChanged: (v) => setState(() => _volume = v ?? _volume),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: (widget.book?.pageMap.isNotEmpty ?? false) ? l.printedPage : l.turathPage, isDense: true),
                  onSubmitted: (_) => _go(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _go, child: Text(l.go)),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: SoftButton(icon: Icons.ios_share_rounded, label: l.sharePage, onTap: () {
                Navigator.of(context).pop();
                widget.onShare();
              })),
              const SizedBox(width: 8),
              Expanded(child: SoftButton(icon: Icons.fullscreen_rounded, label: l.fullScreen, onTap: () {
                Navigator.of(context).pop();
                widget.onFullScreen();
              })),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Text size and line spacing steppers.
class ReaderTextControls extends StatelessWidget {
  const ReaderTextControls({super.key, required this.reading});
  final ReadingController reading;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    Widget stepper(String label, String value, VoidCallback? minus, VoidCallback? plus, IconData lo, IconData hi) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            Expanded(child: Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, color: a.text)))),
            IconButton(visualDensity: VisualDensity.compact, tooltip: l.smaller, onPressed: minus, icon: Icon(lo, size: 18)),
            SizedBox(width: 44, child: Text(value, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, fontSize: 13, color: a.accent))),
            IconButton(visualDensity: VisualDensity.compact, tooltip: l.larger, onPressed: plus, icon: Icon(hi, size: 18)),
          ]),
        );
    final size = reading.fontScale;
    final line = reading.lineHeight;
    return Column(children: [
      stepper(l.textSize, '${(size * 100).round()}%', size > 0.75 ? () => reading.setFontScale(((size - 0.1) * 10).round() / 10) : null,
          size < 1.8 ? () => reading.setFontScale(((size + 0.1) * 10).round() / 10) : null, Icons.text_decrease_rounded, Icons.text_increase_rounded),
      const SizedBox(height: 8),
      stepper(l.lineSpacing, line.toStringAsFixed(1), line > 1.65 ? () => reading.setLineHeight(((line - 0.2) * 10).round() / 10) : null,
          line < 2.85 ? () => reading.setLineHeight(((line + 0.2) * 10).round() / 10) : null, Icons.density_small_rounded, Icons.density_large_rounded),
    ]);
  }
}

/// Paper colour swatches.
class PaperPicker extends StatelessWidget {
  const PaperPicker({super.key, required this.reading});
  final ReadingController reading;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return Row(children: [
      for (final (value, name) in [('paper', l.paperWarm), ('sepia', l.paperSepia), ('plain', l.paperPlain), ('night', l.paperNight)])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Pressable(
              onTap: () => reading.setPaper(value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: readerColors(context, value).bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: reading.paper == value ? a.accent : a.border, width: reading.paper == value ? 2 : 1),
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('أ', style: TextStyle(fontFamily: arabicFont, fontSize: 16, height: 1.2, color: readerColors(context, value).text)),
                  Text(name, style: TextStyle(fontFamily: uiFont, fontSize: 11, fontWeight: FontWeight.w600, color: readerColors(context, value).text)),
                ]),
              ),
            ),
          ),
        ),
    ]);
  }
}

/// Continuous or page-by-page.
class ModePicker extends StatelessWidget {
  const ModePicker({super.key, required this.reading});
  final ReadingController reading;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: 'scroll', icon: const Icon(Icons.view_day_outlined, size: 18), label: Text(l.modeScroll, style: const TextStyle(fontFamily: uiFont))),
        ButtonSegment(value: 'pages', icon: const Icon(Icons.auto_stories_outlined, size: 18), label: Text(l.modePages, style: const TextStyle(fontFamily: uiFont))),
      ],
      selected: {reading.readingMode},
      onSelectionChanged: (s) => reading.setReadingMode(s.first),
    );
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
