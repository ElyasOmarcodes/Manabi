import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show GestureRecognizer, PointerDeviceKind, TapGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent, SelectionStatus;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/backend/backend.dart';
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../core/turath/arabic_match.dart';
import '../../core/turath/text_layers.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/downloads.dart';
import '../../state/layer_ai.dart';
import '../../state/nav_controller.dart';
import '../../state/reading_controller.dart';
import '../../state/highlight_anchor.dart';
import '../../state/search_history.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/pdf_pane.dart';
import '../widgets/reveal_text.dart';
import '../widgets/save_offline.dart';
import '../widgets/scope_picker.dart' show PickKind, pickFromCatalog;
import '../widgets/search_hit.dart';
import '../widgets/search_suggestions.dart';
import '../widgets/selection_menu.dart';
import 'book_screen.dart' show openBook;
import 'library_screen.dart' show showNarrator;
import 'settings_pages.dart' show ReaderDisplaySettingsPage, ReadingSettingsPage;

/// Opens a book at an internal page. [highlight] marks a quote or search
/// term on that page; [search] opens the in-book search right away.
void openReader(BuildContext context, String bookId, int page, {String? title, String? highlight, String? reveal, bool search = false}) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => ReaderScreen(bookId: bookId, page: page, title: title, highlight: highlight, reveal: reveal, openSearch: search)));
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

/// Book faces: id, font family, display name. Amiri follows the classic
/// Naskh of printed editions (like Dar al-Kutub al-Ilmiyya's books).
List<(String, String, String)> readerFonts(AppLocalizations l) => [
      ('amiri', 'Amiri', l.fontAmiri),
      ('naskh', arabicFont, l.fontNotoNaskh),
      ('scheherazade', 'ScheherazadeNew', l.fontScheherazade),
      ('plex', 'IBMPlexSansArabic', l.fontPlex),
      ('vazir', uiFont, l.fontVazir),
    ];

String readerFontFamily(String id) => switch (id) {
      'amiri' => 'Amiri',
      'scheherazade' => 'ScheherazadeNew',
      'plex' => 'IBMPlexSansArabic',
      'vazir' => uiFont,
      _ => arabicFont,
    };

/// The book text style for the reader settings.
/// Faces tried for characters the chosen face lacks.
const bookFontFallback = ['NotoNaskhArabic', 'ScheherazadeNew'];

TextStyle bookTextStyle(BuildContext context, ReadingController r, {double size = 20, required Color color, FontWeight weight = FontWeight.w400}) {
  final scale = context.read<SettingsController>().arabicScale * r.fontScale * (r.fontFamily == 'amiri' || r.fontFamily == 'scheherazade' ? 1.08 : 1.0);
  return TextStyle(
    fontFamily: readerFontFamily(r.fontFamily),
    // Honorific ligatures (﵀ ﵁ ﵂ …) are missing from several faces.
    fontFamilyFallback: bookFontFallback,
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
  const ReaderScreen({super.key, required this.bookId, required this.page, this.title, this.highlight, this.reveal, this.openSearch = false, this.embedded = false, this.onClose});
  final String bookId;

  /// The second pane of a split view: a close button instead of back, and
  /// no keyboard focus of its own.
  final bool embedded;
  final VoidCallback? onClose;
  final int page;
  final String? title;
  final String? highlight;

  /// Text to scroll to on the page (a heading from the contents), unmarked.
  final String? reveal;
  final bool openSearch;
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  late int _page = widget.page < 1 ? 1 : widget.page;

  /// Split view on large screens: the scanned page ('pdf') or a second
  /// text pane ([_splitText]) beside the text.
  String? _splitKind;
  ({String bookId, int page, String title})? _splitText;

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

  /// Where on [_revealPage] to scroll after a jump (a search hit or heading).
  String? _reveal;
  int? _revealPage;
  bool _immersive = false;
  bool _panel = true;

  /// The printed PDF is shown instead of the text, at [_pdfPage] of the
  /// file for [_pdfVolume]; both follow the text page and back.
  bool _pdf = false;
  int _pdfPage = 1;
  String? _pdfVolume;
  bool _wake = false;
  Timer? _scrollTick;

  ManabiBackend get _backend => context.read<SettingsController>().backend;
  late final ReadingController _reading = context.read<ReadingController>();

  /// Bumped when the page or a loaded page changes: only the bars and the
  /// panel rebuild, never the pages, so scrolling stays smooth.
  final _bars = ValueNotifier<int>(0);
  void _barsChanged() => _bars.value++;

  /// Measured height of loaded pages, used for pages still loading.
  double _avgHeight = 640;

  @override
  void initState() {
    super.initState();
    _mark = widget.highlight;
    _reveal = widget.reveal ?? widget.highlight;
    _revealPage = _page;
    _markPage = widget.highlight == null ? null : _page;
    _loadBook();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _remember();
      if (widget.openSearch) _openSearch();
    });
  }

  /// The book's index (page count, volumes, PDF). The page slider and the
  /// volume labels need it, so a failure is tried again until it arrives.
  void _loadBook([int attempt = 0]) {
    _backend.book(widget.bookId).then((b) {
      if (mounted) setState(() => _book = b);
    }).catchError((Object _) {
      if (!mounted || attempt >= 8) return;
      _bookRetry = Timer(Duration(seconds: 3 + attempt * 4), () {
        if (mounted && _book == null) _loadBook(attempt + 1);
      });
    });
  }

  Timer? _bookRetry;

  @override
  void dispose() {
    _bookRetry?.cancel();
    _scrollTick?.cancel();
    _scroll.dispose();
    _pages.dispose();
    _barPager.dispose();
    _bars.dispose();
    // Positions were saved quietly while reading; tell the library now.
    final reading = _reading;
    WidgetsBinding.instance.addPostFrameCallback((_) => reading.notifyPositions());
    if (_wake) WakelockPlus.disable().catchError((Object _) {});
    if (_immersive) SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  String get _title => _book?.title ?? widget.title ?? _loaded[_page]?.bookTitle ?? '';

  Future<PagePassage> _passage(int page) => _cache.putIfAbsent(page, () {
        final f = _backend.page(widget.bookId, page);
        f.then((p) {
          _loaded[page] = p;
          if (mounted) {
            _barsChanged();
            _maybeDetectLayers();
          }
        }).catchError((Object _) {
          _cache.remove(page);
        });
        return f;
      });

  bool _exists(int p) => p >= 1 && (_book?.pageCount == null || p <= _book!.pageCount!);

  void _prefetch(int page) {
    // Two pages back too in commentaries, for the matn printed before.
    final layered = _reading.layersOf(widget.bookId).enabled;
    for (final p in [page + 1, page + 2, page - 1, if (layered) page - 2]) {
      if (_exists(p)) _passage(p);
    }
  }

  void _remember() {
    // The second pane of a split view does not move "continue reading".
    if (!widget.embedded) _reading.savePosition(widget.bookId, _title, _page, notify: false);
  }

  void _setPage(int page) {
    if (page == _page) return;
    _page = page;
    _barsChanged();
    _remember();
    _prefetch(page);
    // The scanned page beside the text follows it.
    if (_splitKind == 'pdf' && !_pdfDriving) {
      final before = (_pdfVolume, _pdfPage);
      _syncPdfToText();
      if (before != (_pdfVolume, _pdfPage)) setState(() {});
    }
  }

  /// The PDF pane is moving the text (not the other way round).
  bool _pdfDriving = false;

  // A phone's "desktop site" is about 980 wide; two panes still read well at 900.
  static const _splitWidth = 900.0;
  bool get _canSplit => !widget.embedded && MediaQuery.sizeOf(context).width >= _splitWidth;

  Future<void> _openSplit() async {
    final l = context.l;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (_book?.pdf != null)
            ListTile(leading: const Icon(Icons.picture_as_pdf_outlined, color: AuraHues.rose), title: Text(l.splitPdf), onTap: () => Navigator.pop(sheet, 'pdf')),
          ListTile(leading: const Icon(Icons.auto_stories_outlined, color: AuraHues.teal), title: Text(l.splitSameBook), onTap: () => Navigator.pop(sheet, 'same')),
          ListTile(leading: const Icon(Icons.library_books_outlined, color: AuraHues.blue), title: Text(l.splitOtherBook), onTap: () => Navigator.pop(sheet, 'other')),
          if (_splitKind != null)
            ListTile(leading: const Icon(Icons.close_rounded, color: AuraHues.rose), title: Text(l.splitClose), onTap: () => Navigator.pop(sheet, 'close')),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'pdf':
        setState(() {
          _syncPdfToText();
          _splitKind = 'pdf';
        });
      case 'same':
        setState(() {
          _splitText = (bookId: widget.bookId, page: _page, title: _title);
          _splitKind = 'text';
        });
      case 'other':
        final b = await pickFromCatalog<CatalogBook>(context, PickKind.book);
        if (b == null || !mounted) return;
        setState(() {
          _splitText = (bookId: b.id, page: 1, title: b.title);
          _splitKind = 'text';
        });
      case 'close':
        setState(() => _splitKind = null);
    }
  }

  void _jump(int page, {String? mark, String? reveal}) {
    final count = _book?.pageCount;
    final target = count == null ? (page < 1 ? 1 : page) : page.clamp(1, count);
    setState(() {
      _mark = mark;
      _markPage = mark == null ? null : target;
      _reveal = reveal ?? mark;
      _revealPage = _reveal == null ? null : target;
      _page = target;
      if (_pdf || _splitKind == 'pdf') _syncPdfToText();
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
      int? current;
      var sum = 0.0, n = 0;
      for (final e in _pageKeys.entries) {
        final box = e.value.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.attached || !box.hasSize) continue;
        if (_loaded.containsKey(e.key)) {
          sum += box.size.height;
          n++;
        }
        final top = box.localToGlobal(Offset.zero).dy;
        if (current == null && top <= probe && top + box.size.height > probe) current = e.key;
      }
      if (n > 0) _avgHeight = (sum / n).clamp(240.0, 2400.0);
      if (current != null) _setPage(current);
      _pageKeys.removeWhere((p, k) => (p - _page).abs() > 40 && k.currentContext == null);
    });
  }

  /// The last search in this book: reopening the search shows it again.
  final _searchMemory = BookSearchMemory();

  Future<void> _openSearch() async {
    final hit = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BookSearchSheet(bookId: widget.bookId, backend: _backend, memory: _searchMemory),
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
          bookId: widget.bookId,
          title: _title,
          samples: _layerSamples(),
          pdfShown: _pdf,
          onPdf: _togglePdf,
          current: _page,
          onGo: _jump,
        ),
      );

  /// Page texts around the current page, for detecting the book's layers.
  List<String> _layerSamples() {
    final near = (_loaded.keys.toList()..sort((a, b) => (a - _page).abs().compareTo((b - _page).abs()))).take(6).toList()..sort();
    return [for (final p in near) _loaded[p]!.text];
  }

  /// Points the PDF at the printed page of the current text page (as Turath
  /// does), shifted by the book's alignment.
  void _syncPdfToText() {
    final at = _book?.locate(_page);
    _pdfVolume = at?.volume ?? _loaded[_page]?.volume;
    final printed = at?.printed ?? _loaded[_page]?.printedPage ?? 1;
    _pdfPage = printed + _reading.pdfOffsetOf(widget.bookId);
    if (_pdfPage < 1) _pdfPage = 1;
  }

  /// Switches between the text and Turath's scanned edition, in place.
  void _togglePdf() {
    if (_book?.pdf == null) return toast(context, context.l.noPdf);
    if (!_pdf) {
      setState(() {
        _syncPdfToText();
        _pdf = true;
      });
      return;
    }
    // Back to the text, at the page the PDF reached.
    final oldScroll = _scroll;
    final oldPages = _pages;
    setState(() {
      _pdf = false;
      _anchor = _page;
      _scroll = ScrollController();
      _pages = PageController(initialPage: _page - 1);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      oldScroll.dispose();
      oldPages.dispose();
    });
  }

  /// The PDF was scrolled: the text page follows.
  void _onPdfPage(int n) {
    _pdfPage = n;
    final volume = _pdfVolume;
    final book = _book;
    if (volume == null || book == null) return;
    final internal = book.internalFor(volume, n - _reading.pdfOffsetOf(widget.bookId));
    if (internal == null) return;
    if (_splitKind == 'pdf') {
      // Beside the text: the text pane jumps to the page shown.
      _pdfDriving = true;
      if (internal != _page) _jump(internal);
      _pdfDriving = false;
      return;
    }
    _setPage(internal);
  }

  Future<void> _setPdfOffset(int value) async {
    await _reading.setPdfOffset(widget.bookId, value);
    if (mounted) setState(_syncPdfToText);
  }

  Widget _pdfView(ReaderColors c) {
    final reading = context.read<ReadingController>();
    final settings = context.read<SettingsController>();
    final viaServer = kIsWeb && settings.mode == ConnectionMode.server;
    final direct = _book!.pdf!.url(_pdfVolume);
    final url = pdfViewUrl(direct, web: kIsWeb, serverUrl: viaServer ? settings.serverUrl : null, site: kIsWeb ? Uri.base.origin : null);
    final token = settings.accessToken.trim();
    return PdfPane(
      key: ValueKey(url),
      url: url,
      directUrl: direct,
      headers: viaServer && token.isNotEmpty ? {'authorization': 'Bearer $token'} : null,
      page: _pdfPage,
      onPage: _onPdfPage,
      offset: reading.pdfOffsetOf(widget.bookId),
      onOffset: _setPdfOffset,
      onShowText: _splitKind == 'pdf' && !_pdf ? () => setState(() => _splitKind = null) : _togglePdf,
      background: c.bg,
      bar: c.bar,
      text: c.text,
      muted: c.muted,
      digits: (n) => readerDigits(n, reading.digits),
    );
  }

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
      case 'offline':
        final downloads = context.read<DownloadController>();
        if (downloads.progressOf(widget.bookId) != null) {
          downloads.cancel(widget.bookId);
        } else if (downloads.isSaved(widget.bookId)) {
          await downloads.remove(widget.bookId);
        } else {
          await saveBookOffline(context, widget.bookId, _title);
        }
      case 'settings':
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReadingSettingsPage()));
      default:
        if (p == null && mounted) toast(context, l.loading);
    }
  }

  Future<void> _highlight(int page, List<({String part, String text, int start})> marks, int color, List<Highlight> replace) async {
    if (marks.isEmpty) return;
    final reading = context.read<ReadingController>();
    final now = DateTime.now();
    await reading.replaceHighlights(remove: replace, add: [
      for (final m in marks) Highlight(bookId: widget.bookId, bookTitle: _title, page: page, text: m.text, color: color, savedAt: now, part: m.part, start: m.start),
    ]);
    await reading.setHighlightColor(color);
  }

  Future<void> _comment(int page, ({String part, String text, int start})? mark, Highlight? existing) async {
    if (mark == null && existing == null) return;
    final note = await askComment(context, initial: existing?.note ?? '');
    if (note == null || !mounted) return;
    final reading = context.read<ReadingController>();
    await reading.replaceHighlights(remove: [?existing], add: [
      if (note.isNotEmpty)
        Highlight(
          bookId: widget.bookId,
          bookTitle: _title,
          page: page,
          text: existing?.text ?? mark!.text,
          color: existing?.color ?? reading.highlightColor,
          note: note,
          savedAt: DateTime.now(),
          part: existing != null ? existing.part : mark!.part,
          start: existing != null ? existing.start : mark!.start,
        ),
    ]);
    if (mounted && note.isNotEmpty) toast(context, context.l.commentSaved);
  }

  void _report(int page, String text) {
    final p = _loaded[page];
    showReportSheet(context, text: text, location: '${p == null ? _title : _citation(p)} · ${widget.bookId}/$page');
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
      final panel = ValueListenableBuilder<int>(
        valueListenable: _bars,
        builder: (context, _, _) => _BookPanel(
          bookId: widget.bookId,
          title: _title,
          book: _book,
          current: _page,
          digits: reading.digits,
          onJump: (page, {mark, reveal}) {
            if (!wide) Navigator.of(context).maybePop();
            _jump(page, mark: mark, reveal: reveal);
          },
        ),
      );
      final drawer = Drawer(width: box.maxWidth.clamp(0, 420) * 0.9, backgroundColor: context.aura.surface, child: SafeArea(child: panel));
      final reader = Column(children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: _immersive ? const SizedBox(width: double.infinity) : ValueListenableBuilder<int>(valueListenable: _bars, builder: (context, _, _) => _topBar(context, c, wide)),
        ),
        Expanded(child: Stack(children: [
          Positioned.fill(
            child: _pdf && _book?.pdf != null
                ? _pdfView(c)
                : reading.readingMode == 'pages'
                    ? _pagesView(c)
                    : _scrollView(c),
          ),
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
          child: _immersive ? const SizedBox(width: double.infinity) : ValueListenableBuilder<int>(valueListenable: _bars, builder: (context, _, _) => _bottomBar(context, c, wide)),
        ),
      ]);
      // Large screens: the text with the scanned page or a second text beside it.
      final split = _splitKind != null && !_pdf && !_immersive && box.maxWidth >= _splitWidth && !widget.embedded;
      final Widget body = !split
          ? reader
          : Directionality(
              textDirection: TextDirection.rtl,
              child: Row(children: [
                Expanded(child: Directionality(textDirection: Directionality.of(context), child: reader)),
                Container(width: 1, color: context.aura.border),
                Expanded(
                  child: Directionality(
                    textDirection: Directionality.of(context),
                    child: _splitKind == 'pdf' && _book?.pdf != null
                        ? _pdfView(c)
                        : ReaderScreen(
                            key: ValueKey('split:${_splitText?.bookId}:${_splitText?.page}'),
                            bookId: _splitText?.bookId ?? widget.bookId,
                            page: _splitText?.page ?? _page,
                            title: _splitText?.title,
                            embedded: true,
                            onClose: () => setState(() => _splitKind = null),
                          ),
                  ),
                ),
              ]),
            );
      return Focus(
        autofocus: !widget.embedded,
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
                        width: split ? 300 : 350,
                        decoration: BoxDecoration(color: context.aura.surface, border: BorderDirectional(end: BorderSide(color: context.aura.border))),
                        child: Directionality(textDirection: Directionality.of(context), child: panel),
                      ),
                      Expanded(child: Directionality(textDirection: Directionality.of(context), child: body)),
                    ]),
                  )
                : body,
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
        if (widget.embedded)
          RoundIconButton(icon: Icons.close_rounded, tooltip: l.splitClose, filled: false, color: c.text, onTap: widget.onClose)
        else
          RoundIconButton(
            icon: Directionality.of(context) == TextDirection.rtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            filled: false,
            color: c.text,
            onTap: () => Navigator.of(context).maybePop(),
          ),
        const SizedBox(width: 4),
        Expanded(
          // The title opens the book's page (contents, details).
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => openBook(context, widget.bookId),
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
            _offlineItem(context),
            menuItem('settings', Icons.settings_outlined, l.moreReadingSettings),
          ],
        ),
      ]),
    );
  }

  PopupMenuItem<String> _offlineItem(BuildContext context) {
    final l = context.l;
    final downloads = context.read<DownloadController>();
    final progress = downloads.progressOf(widget.bookId);
    if (progress != null) return menuItem('offline', Icons.stop_circle_outlined, '${l.savingOffline((progress * 100).round())} · ${l.stopDownload}');
    if (downloads.isSaved(widget.bookId)) return menuItem('offline', Icons.delete_outline_rounded, l.removeDownload);
    return menuItem('offline', Icons.download_for_offline_outlined, l.saveOffline);
  }

  /// Which half of the phone bottom bar is shown: 0 the page slider, 1 the tools.
  static int _barPage = 0;
  late final PageController _barPager = PageController(initialPage: _barPage);

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
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: active ? context.aura.accent.withValues(alpha: 0.14) : Colors.transparent, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 21, color: active ? context.aura.accent : c.text),
            ),
          ),
        );
    final tools = [
      tool(Icons.toc_rounded, l.tableOfContents, () => _openPanel(wide), active: wide && _panel),
      tool(Icons.manage_search_rounded, l.searchInBook, _openSearch),
      tool(Icons.tune_rounded, l.readerTools, _openTools),
      tool(Icons.fullscreen_rounded, l.fullScreen, _toggleImmersive),
      if (_book?.pdf != null) tool(_pdf ? Icons.picture_as_pdf_rounded : Icons.picture_as_pdf_outlined, _pdf ? l.showText : l.showPdf, _togglePdf, active: _pdf),
      if (_canSplit) tool(Icons.vertical_split_outlined, l.splitView, _openSplit, active: _splitKind != null),
    ];
    final slider = count != null && count > 1
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
              onChanged: (v) {
                _page = v.round();
                _barsChanged();
              },
              onChangeEnd: (v) => _jump(v.round()),
            ),
          )
        // The slider waits for the book's page count.
        : _book == null
            ? const Center(child: AuraProgress(width: 90, height: 3))
            : const SizedBox();
    final label = Pressable(
      onTap: _openGoTo,
      child: Container(
        constraints: const BoxConstraints(minWidth: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(pageLabel(context, _book, _page, passage: _loaded[_page], digits: reading.digits),
              style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text)),
          if (count != null)
            Text('${readerDigits(((_page / count) * 100).round(), reading.digits)}٪', style: TextStyle(fontFamily: uiFont, fontSize: 10.5, color: c.muted)),
        ]),
      ),
    );
    // Chevrons turn with the text direction: in this right-to-left bar "left"
    // is drawn pointing right, toward the earlier pages.
    final prev = tool(Icons.chevron_left_rounded, l.previousPage, () => _page > 1 ? _jump(_page - 1) : null);
    final next = tool(Icons.chevron_right_rounded, l.nextPage, () => _exists(_page + 1) ? _jump(_page + 1) : null);
    final bottom = MediaQuery.paddingOf(context).bottom;

    if (wide) {
      return Container(
        color: c.bar,
        padding: EdgeInsets.fromLTRB(6, 2, 6, bottom + 4),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Row(children: [...tools, Expanded(child: slider), prev, label, next]),
        ),
      );
    }
    // Phones: two rows that slide sideways, so the page slider keeps its
    // full width however many tools the book has.
    return Container(
      color: c.bar,
      padding: EdgeInsets.fromLTRB(4, 0, 4, bottom + 2),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
            height: 48,
            child: ScrollConfiguration(
              // A mouse or trackpad can slide it too (small desktop windows).
              behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              child: PageView(
                controller: _barPager,
                onPageChanged: (i) {
                  _barPage = i;
                  _barsChanged();
                },
                children: [
                  Row(children: [prev, Expanded(child: slider), next, label]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [...tools, label]),
                ],
              ),
            ),
          ),
          // Which row is shown; tap to switch.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _barPager.animateToPage(_barPage == 0 ? 1 : 0, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic),
            child: Padding(
              padding: const EdgeInsets.only(top: 1, bottom: 3),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 2; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: _barPage == i ? 16 : 6,
                    height: 4,
                    decoration: BoxDecoration(color: _barPage == i ? context.aura.accent : c.muted.withValues(alpha: 0.35), borderRadius: BorderRadius.circular(2)),
                  ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _block(int page, ReaderColors c, {required bool continuous}) => _PageBlock(
        key: _pageKeys.putIfAbsent(page, GlobalKey.new),
        page: page,
        future: _passage(page),
        initial: _loaded[page],
        estimate: _avgHeight,
        colors: c,
        continuous: continuous,
        mark: _markPage == page ? _mark : null,
        reveal: _revealPage == page ? _reveal : null,
        book: _book,
        onRetry: () => setState(() => _cache.remove(page)),
        onAction: (a) => _pageAction(a, page),
        onHighlight: (m, c, replace) => _highlight(page, m, c, replace),
        onCopyQuote: (t) => _copyQuote(page, t),
        onComment: (m, h) => _comment(page, m, h),
        onReport: (t) => _report(page, t),
        matnContext: () => _matnContext(page),
      );

  /// Matn blocks printed on the pages before [page] (nearest first): the
  /// commentary on a page often explains matn printed a few pages back.
  List<String> _matnContext(int page) {
    final out = <String>[];
    for (var q = page - 1; q >= 1 && q >= page - 12 && out.length < 3; q--) {
      final text = _loaded[q]?.text;
      if (text == null) continue;
      final b = matnBlock(text);
      if (b != null) out.add(text.substring(0, b.blockEnd));
    }
    return out;
  }

  /// A book whose pages print their matn on top (the ــ layout) gets its
  /// matn set apart at once, unless the reader already chose for it.
  bool _layersTried = false;
  void _maybeDetectLayers() {
    if (_layersTried || _loaded.length < 3) return;
    _layersTried = true;
    if (_reading.hasLayers(widget.bookId)) return;
    final samples = _layerSamples();
    final braces = bracesAreVerses(samples);
    final rules = detectMatnRules(samples, quranMarkers: braces ? const ['{}'] : const []);
    if (!rules.block) return;
    _reading.setLayers(
      widget.bookId,
      BookLayers(enabled: true, block: true, matn: rules.always, verified: rules.verified, bracesAreVerses: braces, source: 'auto'),
    );
  }

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
            scrollCacheExtent: const ScrollCacheExtent.pixels(2600),
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
      child: Row(children: [Icon(icon, size: 20), const SizedBox(width: 12), Flexible(child: Text(label, style: TextStyle(fontFamily: uiFont)))]),
    );

/// One book page: chapter, text with highlights and search matches,
/// footnotes and a footer with the page number and a menu.
class _PageBlock extends StatelessWidget {
  const _PageBlock({
    super.key,
    required this.page,
    required this.future,
    this.initial,
    this.estimate = 640,
    required this.colors,
    required this.continuous,
    required this.mark,
    required this.book,
    required this.onRetry,
    required this.onAction,
    required this.onHighlight,
    required this.onCopyQuote,
    required this.onComment,
    required this.onReport,
    this.matnContext,
    this.reveal,
  });
  final int page;

  /// Text on this page to scroll to once it is shown.
  final String? reveal;
  final Future<PagePassage> future;

  /// Matn blocks of the pages before this one (most recent first), to tell
  /// quoted matn from other quotes.
  final List<String> Function()? matnContext;

  /// The page when already loaded: built at once, without a loading frame
  /// (which made the view jump when pages came back into view).
  final PagePassage? initial;
  final double estimate;
  final ReaderColors colors;
  final bool continuous;
  final String? mark;
  final BookDetails? book;
  final VoidCallback onRetry;
  final ValueChanged<String> onAction;
  /// New marks for the selection in a colour, replacing the marks under it.
  final void Function(List<({String part, String text, int start})> marks, int color, List<Highlight> replace) onHighlight;
  final ValueChanged<String> onCopyQuote;

  /// Comment on the selection, or edit the comment already on it.
  final void Function(({String part, String text, int start})? mark, Highlight? existing) onComment;
  final ValueChanged<String> onReport;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    final reading = context.watch<ReadingController>();
    return FutureBuilder<PagePassage>(
      future: future,
      initialData: initial,
      builder: (context, snap) {
        if (!snap.hasData) {
          if (snap.hasError) return SizedBox(height: 320, child: ErrorPanel(code: mapError(snap.error!).code, onRetry: onRetry));
          return SizedBox(height: continuous ? estimate : MediaQuery.sizeOf(context).height * 0.6, child: const Center(child: AuraProgress()));
        }
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
        final showNotes = notes.isNotEmpty && reading.showFootnotes;
        final spaces = {'title': ?title, 'body': body, if (showNotes) 'notes': notes};
        // Each mark at one place (the matn and its commentary repeat words).
        final placed = placeHighlights(spaces, reading.highlightsOf(p.bookId, page));
        final bookmarked = reading.isBookmarked(p.bookId, page);
        final selection = _Selection(spaces);
        final style = bookTextStyle(context, reading, color: colors.text);
        final align = reading.justify ? TextAlign.justify : TextAlign.start;
        return Container(
          decoration: continuous ? BoxDecoration(border: Border(bottom: BorderSide(color: colors.muted.withValues(alpha: 0.22)))) : null,
          padding: EdgeInsets.fromLTRB(22, continuous ? 16 : 20, 22, 8),
          child: ReadingWidth(
            maxWidth: 760,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // One selection area for the title, text and footnotes: it keeps
              // Arabic (right-to-left) selection in reading order.
              SelectionArea(
                onSelectionChanged: (c) => selection.text = c?.plainText ?? '',
                contextMenuBuilder: (context, state) => _menu(context, state, selection, placed),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: selection.listen(
                        Text.rich(
                          _marked(context, title, mark, _localMarks(placed, 'title', 0, title.length),
                              bookTextStyle(context, reading, size: 17, weight: FontWeight.w700, color: a.accent).copyWith(height: 1.7)),
                          textDirection: TextDirection.rtl,
                        ),
                        'title',
                        0,
                      ),
                    ),
                  ..._bodyParts(context, p, body, placed, selection, style, align),
                  if (showNotes) ...[
                    const SizedBox(height: 14),
                    Align(alignment: AlignmentDirectional.centerStart, child: SizedBox(width: 90, child: Divider(color: colors.muted.withValues(alpha: 0.5)))),
                    const SizedBox(height: 4),
                    selection.listen(
                      Text.rich(
                        _marked(context, notes, mark, _localMarks(placed, 'notes', 0, notes.length),
                            bookTextStyle(context, reading, size: 15.5, color: colors.muted).copyWith(height: reading.lineHeight * 0.88)),
                        textDirection: TextDirection.rtl,
                        textAlign: align,
                      ),
                      'notes',
                      0,
                    ),
                  ],
                ]),
              ),
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
                    tooltip: l.moreActions,
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

  /// The page text: the matn printed on top (before the ــ line), a short
  /// rule, then the commentary.
  List<Widget> _bodyParts(BuildContext context, PagePassage p, String body, List<PlacedHighlight> marks, _Selection selection, TextStyle style, TextAlign align) {
    final reading = context.read<ReadingController>();
    final layers = reading.layersOf(p.bookId);
    List<(String, String)>? ai;
    if (layers.enabled && layers.aiPages) {
      ai = PageMatnAi.cached(p.bookId, page);
      if (ai == null) {
        final backend = context.read<SettingsController>().backend;
        return [
          FutureBuilder<List<(String, String)>?>(
            future: PageMatnAi.fetch(backend, p.bookId, page, p.bookTitle, p.text),
            builder: (context, snap) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _parts(context, p, body, marks, selection, style, align, layers, snap.data),
            ),
          ),
        ];
      }
    }
    return _parts(context, p, body, marks, selection, style, align, layers, ai);
  }

  List<Widget> _parts(BuildContext context, PagePassage p, String body, List<PlacedHighlight> marks, _Selection selection, TextStyle style, TextAlign align, BookLayers layers,
      List<(String, String)>? ai) {
    final block = matnBlock(body);
    final earlier = matnContext?.call() ?? const <String>[];
    // The AI's stretches are found on the whole page, in reading order, and
    // then split between the matn on top and the commentary.
    final aiRanges = ai == null ? null : aiMatnRanges(body, ai, context: earlier);
    if (block == null) {
      return [
        selection.listen(
            RevealText(_marked(context, body, mark, _localMarks(marks, 'body', 0, body.length), style, narrators: p.narrators, earlier: earlier, aiRanges: aiRanges),
                reveal: reveal, textDirection: TextDirection.rtl, textAlign: align),
            'body',
            0),
      ];
    }
    final top = body.substring(0, block.blockEnd);
    final sharh = body.substring(block.sharhStart);
    final topAi = aiRanges == null ? null : [for (final (s, e) in aiRanges) if (s < block.blockEnd) (s, e)];
    final sharhAi = aiRanges == null ? null : [for (final (s, e) in aiRanges) if (s >= block.sharhStart) (s - block.sharhStart, e - block.sharhStart)];
    final revealTop = reveal != null && arabicMatches(top, reveal).isNotEmpty;
    return [
      selection.listen(
          RevealText(_marked(context, top, mark, _localMarks(marks, 'body', 0, block.blockEnd), style, narrators: p.narrators, top: true, aiRanges: topAi),
              reveal: revealTop ? reveal : null, textDirection: TextDirection.rtl, textAlign: align),
          'body',
          0),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(child: Container(width: 72, height: 1.5, decoration: BoxDecoration(color: colors.muted.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(2)))),
      ),
      selection.listen(
          RevealText(_marked(context, sharh, mark, _localMarks(marks, 'body', block.sharhStart, body.length), style, narrators: p.narrators, earlier: [top, ...earlier], aiRanges: sharhAi),
              reveal: revealTop ? null : reveal, textDirection: TextDirection.rtl, textAlign: align),
          'body',
          block.sharhStart),
    ];
  }

  void _showComment(BuildContext context, Highlight h) {
    final reading = context.read<ReadingController>();
    showCommentSheet(context, h, onEdit: () => onComment(null, h), onDelete: () => reading.removeHighlight(h));
  }

  /// The selection menu (icons only): highlight colours, copy, copy with
  /// the source, comment, report an error, and removing marks under it.
  Widget _menu(BuildContext context, SelectableRegionState state, _Selection selection, List<PlacedHighlight> placed) {
    final text = selection.text.trim();
    if (text.isEmpty) return AdaptiveTextSelectionToolbar.buttonItems(anchors: state.contextMenuAnchors, buttonItems: state.contextMenuButtonItems);
    final reading = context.read<ReadingController>();
    final spans = selection.spans();
    // Only the marks the selection actually touches, at their own place.
    final under = spans.isEmpty
        ? [for (final p in placed) if (SearchHistory.fold(p.highlight.text) == SearchHistory.fold(text)) p.highlight]
        : highlightsUnder(placed, spans);
    void done(VoidCallback fn) {
      state.hideToolbar();
      fn();
    }

    return SelectionToolbar(
      anchors: state.contextMenuAnchors,
      marked: under,
      onColor: (c) => done(() => onHighlight(selection.anchors(spans), c, [for (final h in under) if (h.note == null) h])),
      onCopy: () => done(() => copyText(context, text)),
      onCopyCite: () => done(() => onCopyQuote(text)),
      onComment: () => done(() => onComment(selection.anchors(spans).firstOrNull, under.where((h) => h.note != null).firstOrNull)),
      onReport: () => done(() => onReport(text)),
      onRemove: () => done(() => reading.replaceHighlights(remove: [for (final h in under) if (h.note == null) h])),
      onDeleteComment: () => done(() => reading.replaceHighlights(remove: [for (final h in under) if (h.note != null) h])),
    );
  }

  TextSpan _marked(BuildContext context, String text, String? query, List<(int, int, Highlight)> highlights, TextStyle style,
      {List<({String id, String name})> narrators = const [], bool top = false, List<String> earlier = const [], List<(int, int)>? aiRanges}) {
    final dark = context.aura.dark;
    final reading = context.read<ReadingController>();
    // Narrator names (linked by Turath) open their record when tapped.
    final taps = <(int, int, GestureRecognizer)>[];
    var from = 0;
    for (final n in narrators) {
      final name = reading.hideDiacritics ? stripDiacritics(n.name) : n.name;
      if (name.trim().isEmpty) continue;
      final at = text.indexOf(name, from);
      if (at < 0) continue;
      taps.add((at, at + name.length, TapGestureRecognizer()..onTap = () => showNarrator(context, n.id, n.name)));
      from = at + name.length;
    }
    for (final (s, e, h) in highlights) {
      if (h.note != null) taps.add((s, e, TapGestureRecognizer()..onTap = () => _showComment(context, h)));
    }
    final linkStyle = TextStyle(
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: context.aura.accent.withValues(alpha: dark ? 0.55 : 0.45),
    );
    final ranges = <(int, int, TextStyle)>[
      // Lowest first: verses and matn, then highlights, then search matches.
      ...textLayerRanges(reading, reading.layersOf(book?.id ?? ''), text, dark: dark, top: top, context: earlier, aiRanges: aiRanges),
      for (final (s, e, _) in taps) (s, e, linkStyle),
      for (final (s, e, h) in highlights)
          if (h.note == null)
            (s, e, TextStyle(backgroundColor: highlightColors[h.color.clamp(0, highlightColors.length - 1)].withValues(alpha: dark ? 0.38 : 0.45)))
          else
            // A comment: its own colour and a dashed underline; a tap shows it.
            (s, e, TextStyle(
              backgroundColor: commentColor.withValues(alpha: dark ? 0.3 : 0.26),
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dashed,
              decorationColor: commentColor,
              decorationThickness: 1.6,
            )),
      for (final (s, e) in arabicMatches(text, query))
        (s, e, TextStyle(color: dark ? const Color(0xFFFF8A80) : const Color(0xFFC62828), backgroundColor: AuraHues.rose.withValues(alpha: dark ? 0.12 : 0.08))),
    ];
    return layeredSpan(text, style, ranges, taps: taps);
  }
}

/// Verse and matn styles for a page text, from the reading settings and the
/// book's layers. [top] is the matn block printed above the ــ line;
/// [context] holds matn printed earlier (to verify quotes); [ai] the AI's
/// marking of this page (located), when the book is read in the precise mode.
List<(int, int, TextStyle)> textLayerRanges(ReadingController r, BookLayers layers, String text,
    {required bool dark, bool top = false, List<String> context = const [], List<(int, int)>? aiRanges}) {
  final out = <(int, int, TextStyle)>[];
  final verses = r.styleQuran ? quranRanges(text, extra: layers.bracesAreVerses ? const ['{}'] : const []) : const <(int, int)>[];
  if (layers.enabled) {
    final c = matnColors[r.matnColor.clamp(0, matnColors.length - 1)];
    final style = TextStyle(color: dark ? c.$2 : c.$1, fontWeight: r.matnBold ? FontWeight.w700 : null);
    final List<(int, int)> matn;
    if (top && (layers.block || (aiRanges != null && aiRanges.isNotEmpty))) {
      matn = [(0, text.length)];
    } else if (aiRanges != null) {
      matn = aiRanges;
    } else {
      final rules = layers.rules;
      matn = matnRanges(
        text,
        MatnRules(
          always: [for (final m in rules.always) if (!(m == '{}' && layers.bracesAreVerses)) m],
          verified: [for (final m in rules.verified) if (!(m == '{}' && layers.bracesAreVerses)) m],
        ),
        context: context,
        verses: verses,
      );
    }
    for (final (s, e) in matn) {
      out.add((s, e, style));
    }
  }
  if (verses.isNotEmpty) {
    // Verses are set last: a verse inside the matn keeps its own style.
    final c = quranColors[r.quranColor.clamp(0, quranColors.length - 1)];
    final style = TextStyle(color: dark ? c.$2 : c.$1, fontFamily: r.quranFont == 'quran' ? 'AmiriQuran' : null);
    for (final (s, e) in verses) {
      out.add((s, e, style));
    }
  }
  return out;
}

/// A text span where each range adds its style on top of [base]; ranges may
/// overlap and later ones win.
///
/// [taps] make their ranges tappable (they should not overlap each other).
TextSpan layeredSpan(String text, TextStyle base, List<(int, int, TextStyle)> ranges, {List<(int, int, GestureRecognizer)> taps = const []}) {
  final valid = [for (final r in ranges) if (r.$1 < r.$2 && r.$1 >= 0 && r.$2 <= text.length) r];
  if (valid.isEmpty && taps.isEmpty) return TextSpan(text: text, style: base);
  final cuts = <int>{0, text.length, for (final r in valid) ...[r.$1, r.$2], for (final t in taps) ...[t.$1, t.$2]}.toList()..sort();
  final spans = <TextSpan>[];
  for (var i = 0; i + 1 < cuts.length; i++) {
    final a = cuts[i], b = cuts[i + 1];
    TextStyle? style;
    for (final (s, e, st) in valid) {
      if (s <= a && e >= b) style = style == null ? st : style.merge(st);
    }
    GestureRecognizer? tap;
    for (final (s, e, r) in taps) {
      if (s <= a && e >= b) tap = r;
    }
    spans.add(TextSpan(text: text.substring(a, b), style: style, recognizer: tap));
  }
  return TextSpan(style: base, children: spans);
}

/// The text currently selected on a page (for the selection menu).
class _Selection {
  _Selection(this.spaces);

  /// The page's text spaces as shown ('title', 'body', 'notes').
  final Map<String, String> spaces;
  String text = '';
  final _parts = <(SelectionListenerNotifier, String, int)>[];

  /// Wraps one shown part of [space] that starts at [base] in it, so the
  /// selection's exact place is known.
  Widget listen(Widget child, String space, int base) {
    final n = SelectionListenerNotifier();
    _parts.add((n, space, base));
    return SelectionListener(selectionNotifier: n, child: child);
  }

  /// The selected stretches, each within one space.
  List<SelectedSpan> spans() {
    final out = <SelectedSpan>[];
    for (final (n, space, base) in _parts) {
      if (!n.registered) continue;
      final d = n.selection;
      final r = d.range;
      if (d.status == SelectionStatus.none || r == null || r.startOffset == r.endOffset) continue;
      final text = spaces[space] ?? '';
      final a = (base + (r.startOffset < r.endOffset ? r.startOffset : r.endOffset)).clamp(0, text.length);
      final b = (base + (r.startOffset < r.endOffset ? r.endOffset : r.startOffset)).clamp(a, text.length);
      out.add((space: space, start: a, end: b, text: text.substring(a, b)));
    }
    return out;
  }

  /// New marks for the selection: one per stretch, trimmed and anchored.
  List<({String part, String text, int start})> anchors(List<SelectedSpan> spans) {
    final out = <({String part, String text, int start})>[];
    for (final sp in spans) {
      final a = anchorFor(spaces[sp.space] ?? '', sp.start, sp.end);
      if (a != null) out.add((part: sp.space, text: a.text, start: a.start));
    }
    if (out.isEmpty && text.trim().isNotEmpty) {
      // Fallback: the first exact place of the selected text.
      for (final space in highlightSpaces) {
        final t = spaces[space];
        if (t == null) continue;
        final m = exactMatches(t, text);
        if (m.isEmpty) continue;
        final a = anchorFor(t, m.first.$1, m.first.$2);
        if (a != null) out.add((part: space, text: a.text, start: a.start));
        break;
      }
    }
    return out;
  }
}

/// The placed highlights inside [from, to) of [space], shifted to start at [from].
List<(int, int, Highlight)> _localMarks(List<PlacedHighlight> placed, String space, int from, int to) => [
      for (final p in placed)
        if (p.space == space && p.start < to && p.end > from) ((p.start - from).clamp(0, to - from), (p.end - from).clamp(0, to - from), p.highlight),
    ];

/// The book side panel: contents, bookmarks, highlights and visited pages.
class _BookPanel extends StatefulWidget {
  const _BookPanel({required this.bookId, required this.title, required this.book, required this.current, required this.digits, required this.onJump});
  final String bookId;
  final String title;
  final BookDetails? book;
  final int current;
  final String digits;
  final void Function(int page, {String? mark, String? reveal}) onJump;
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
          labelStyle: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w700),
          unselectedLabelStyle: TextStyle(fontFamily: uiFont, fontSize: 13.5),
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
    if (book == null) return const Center(child: AuraProgress());
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
      onTap: e.page == null ? null : () => widget.onJump(e.page!, reveal: e.title),
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
          subtitle: Text(pageLabel(context, widget.book, b.page, digits: widget.digits), style: TextStyle(fontFamily: uiFont, fontSize: 12)),
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
          subtitle: Text(pageLabel(context, widget.book, p, digits: widget.digits), style: TextStyle(fontFamily: uiFont, fontSize: 12)),
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
    final color = h.note != null ? commentColor : highlightColors[h.color.clamp(0, highlightColors.length - 1)];
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
                      if (h.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Icon(Icons.mode_comment_outlined, size: 14, color: commentColor),
                            const SizedBox(width: 6),
                            Expanded(child: Text(h.note!, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 13, height: 1.6, color: a.text))),
                          ]),
                        ),
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

/// The reading tools people reach for while reading: text size and spacing,
/// reading mode, a few switches, the book's matn setting, and at the bottom
/// the printed PDF and saving for offline. Page colours and fonts live in
/// the reading settings. Smaller on phones.
class _ToolsSheet extends StatelessWidget {
  const _ToolsSheet({
    required this.book,
    required this.bookId,
    required this.title,
    required this.samples,
    required this.pdfShown,
    required this.onPdf,
    required this.current,
    required this.onGo,
  });
  final BookDetails? book;
  final int current;
  final ValueChanged<int> onGo;
  final String bookId;
  final String title;
  final List<String> samples;
  final bool pdfShown;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    final phone = MediaQuery.sizeOf(context).width < 600;
    final layers = r.layersOf(bookId);
    Widget chip(String label, IconData icon, bool value, ValueChanged<bool> onChanged) => FilterChip(
          avatar: Icon(icon, size: phone ? 15 : 17, color: value ? a.accent : a.muted),
          label: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: phone ? 12 : 13)),
          selected: value,
          showCheckmark: false,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: onChanged,
        );
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(phone ? 14 : 18, 0, phone ? 14 : 18, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: Text(l.readerTools, style: TextStyle(fontFamily: uiFont, fontSize: phone ? 15 : 16.5, fontWeight: FontWeight.w800, color: a.text))),
              IconButton(
                tooltip: l.moreReadingSettings,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.settings_outlined, size: 20, color: a.muted),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReaderDisplaySettingsPage()));
                },
              ),
            ]),
            _GoToRow(book: book, current: current, onGo: onGo, dense: phone),
            SizedBox(height: phone ? 8 : 10),
            ReaderTextControls(reading: r, dense: phone),
            SizedBox(height: phone ? 8 : 10),
            ModePicker(reading: r),
            SizedBox(height: phone ? 8 : 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              chip(l.justifyText, Icons.format_align_justify_rounded, r.justify, r.setJustify),
              chip(l.hideDiacritics, Icons.text_format_rounded, r.hideDiacritics, r.setHideDiacritics),
              chip(l.showFootnotes, Icons.notes_rounded, r.showFootnotes, r.setShowFootnotes),
              if (!kIsWeb) chip(l.keepScreenOn, Icons.light_mode_outlined, r.keepAwake, r.setKeepAwake),
            ]),
            SizedBox(height: phone ? 6 : 10),
            // The book's matn and commentary, in its own sheet.
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: Icon(Icons.format_quote_rounded, size: 20, color: layers.enabled ? a.accent : a.muted),
              title: Row(children: [
                Flexible(child: Text(l.matnSection, style: TextStyle(fontFamily: uiFont, fontSize: phone ? 13.5 : 14.5, color: a.text))),
                const BetaBadge(),
              ]),
              subtitle: Text(layers.enabled ? l.matnSeparate : l.noMatnRules,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
              trailing: Icon(Icons.chevron_left_rounded, color: a.muted),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => SafeArea(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                      child: LayersPanel(bookId: bookId, title: title, samples: samples),
                    ),
                  ),
                ),
              ),
            ),
            const Divider(height: 14),
            // Two small actions: the printed PDF and saving for offline.
            Row(children: [
              if (book?.pdf != null) ...[
                SoftButton(
                  dense: true,
                  icon: pdfShown ? Icons.notes_rounded : Icons.picture_as_pdf_outlined,
                  color: AuraHues.rose,
                  label: pdfShown ? l.textView : l.pdfView,
                  onTap: () {
                    Navigator.of(context).pop();
                    onPdf();
                  },
                ),
                const SizedBox(width: 8),
              ],
              Expanded(child: SaveOfflineButton(bookId: bookId, title: title, dense: true)),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// Matn and commentary for one book: switch, markers, and detection from
/// the pages (counting delimiters) or by the model.
class LayersPanel extends StatefulWidget {
  const LayersPanel({super.key, required this.bookId, required this.title, required this.samples});
  final String bookId;
  final String title;
  final List<String> samples;
  @override
  State<LayersPanel> createState() => _LayersPanelState();
}

class _LayersPanelState extends State<LayersPanel> {
  bool _busy = false;
  String? _note;

  static String glyph(String m) {
    final (open, close) = layerMarkers[m]!;
    return '$open … $close';
  }

  List<String> get _samples => [for (final p in widget.samples.take(4)) p.length > 5000 ? p.substring(0, 5000) : p];

  Future<void> _detect() async {
    final r = context.read<ReadingController>();
    final braces = bracesAreVerses(widget.samples);
    final rules = detectMatnRules(widget.samples, quranMarkers: braces ? const ['{}'] : const []);
    final l = context.l;
    final old = r.layersOf(widget.bookId);
    await r.setLayers(
      widget.bookId,
      BookLayers(enabled: !rules.isEmpty, block: rules.block, matn: rules.always, verified: rules.verified, bracesAreVerses: braces, source: 'auto', aiPages: old.aiPages),
    );
    setState(() => _note = rules.isEmpty ? l.detectedNone : null);
  }

  /// The AI marks the matn on sample pages; the rules that reproduce its
  /// marking best are kept for the whole book.
  Future<void> _detectAi() async {
    final r = context.read<ReadingController>();
    final backend = context.read<SettingsController>().backend;
    final l = context.l;
    setState(() => _busy = true);
    try {
      final samples = _samples;
      final g = await backend.detectLayers(widget.title, samples);
      final truth = [for (var i = 0; i < samples.length; i++) aiTruth(samples[i], i < g.pages.length ? g.pages[i] : const [])];
      final old = r.layersOf(widget.bookId);
      final braces = g.quran.contains('{}');
      if (truth.every((t) => t.isEmpty)) {
        await r.setLayers(widget.bookId, BookLayers(enabled: false, bracesAreVerses: braces, source: 'ai', note: g.note));
        if (mounted) setState(() => _note = g.note.isEmpty ? l.detectedNone : g.note);
        return;
      }
      final (rules, agreement) = learnMatnRules(samples, truth);
      await r.setLayers(
        widget.bookId,
        BookLayers(
          enabled: true,
          block: rules.block,
          matn: rules.always,
          verified: rules.verified,
          bracesAreVerses: braces,
          source: 'ai',
          agreement: agreement,
          note: g.note,
          aiPages: old.aiPages,
        ),
      );
      if (mounted) setState(() => _note = null);
    } catch (e) {
      if (mounted) setState(() => _note = errorText(l, mapError(e).code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.watch<ReadingController>();
    final l = context.l;
    final a = context.aura;
    final layers = r.layersOf(widget.bookId);
    final hasAi = context.read<SettingsController>().isConfigured;
    void update(BookLayers v) => r.setLayers(widget.bookId, v.copyWith(source: 'manual'));
    Widget rule(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 16, color: a.accent),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.text, height: 1.45))),
          ]),
        );
    final rules = [
      if (layers.block) rule(Icons.vertical_align_top_rounded, l.matnBlockShort),
      for (final m in layers.matn) rule(Icons.check_rounded, '${glyph(m)}   ${l.markerAlwaysShort}'),
      for (final m in layers.verified) rule(Icons.fact_check_outlined, '${glyph(m)}   ${l.markerVerifiedShort}'),
      if (layers.aiPages) rule(Icons.auto_awesome_rounded, l.aiPagesLabel),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Text(l.matnSection, style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w800, color: a.text)),
        const BetaBadge(),
      ]),
      SwitchListTile.adaptive(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        secondary: Icon(Icons.format_quote_rounded, size: 20, color: a.muted),
        title: Text(l.matnSeparate, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, color: a.text)),
        value: layers.enabled,
        onChanged: (v) => update(layers.copyWith(enabled: v, matn: v && layers.matn.isEmpty && layers.verified.isEmpty && !layers.block ? const ['()'] : layers.matn)),
      ),
      if (layers.enabled)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(color: a.accent.withValues(alpha: a.dark ? 0.12 : 0.06), borderRadius: BorderRadius.circular(14)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.matnRulesTitle, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.muted)),
            if (rules.isEmpty) rule(Icons.info_outline_rounded, l.noMatnRules) else ...rules,
            if (layers.source == 'ai' && layers.agreement != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('${l.layersSourceAi} · ${l.layersAgreement((layers.agreement! * 100).round())}', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
              )
            else if (layers.source == 'auto')
              Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.layersAutoNote, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted))),
            if (layers.note.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 2), child: Text(layers.note, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted, height: 1.4))),
          ]),
        ),
      Row(children: [
        Expanded(child: SoftButton(icon: Icons.manage_search_rounded, label: l.detectAuto, onTap: widget.samples.isEmpty || _busy ? null : _detect)),
        const SizedBox(width: 8),
        Expanded(
          child: SoftButton(
            icon: Icons.auto_awesome_rounded,
            color: AuraHues.violet,
            label: _busy ? l.detecting : l.detectAi,
            onTap: widget.samples.isEmpty || _busy || !hasAi ? null : _detectAi,
          ),
        ),
      ]),
      if (_note != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_note!, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted, height: 1.5)),
        ),
      if (layers.enabled) ...[
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          secondary: const Icon(Icons.auto_awesome_rounded, size: 20, color: AuraHues.violet),
          title: Text(l.aiPagesLabel, style: TextStyle(fontFamily: uiFont, fontSize: 14, color: a.text)),
          subtitle: Text(l.aiPagesSub, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted, height: 1.4)),
          value: layers.aiPages,
          onChanged: hasAi ? (v) => r.setLayers(widget.bookId, layers.copyWith(aiPages: v)) : null,
        ),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 4),
            childrenPadding: const EdgeInsets.only(bottom: 4),
            title: Text(l.fineTune, style: TextStyle(fontFamily: uiFont, fontSize: 14, color: a.text)),
            leading: Icon(Icons.tune_rounded, size: 20, color: a.muted),
            children: [
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(l.matnBlockRule, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, color: a.text)),
                value: layers.block,
                onChanged: (v) => update(layers.copyWith(block: v)),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 4, bottom: 6),
                child: Text(l.markersHint, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted, height: 1.45)),
              ),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final m in matnMarkerIds)
                  _MarkerChip(
                    label: glyph(m),
                    state: layers.matn.contains(m) ? 1 : (layers.verified.contains(m) ? 2 : 0),
                    onTap: () {
                      final now = layers.matn.contains(m) ? 1 : (layers.verified.contains(m) ? 2 : 0);
                      final next = (now + 1) % 3;
                      update(layers.copyWith(
                        matn: [for (final x in layers.matn) if (x != m) x, if (next == 1) m],
                        verified: [for (final x in layers.verified) if (x != m) x, if (next == 2) m],
                      ));
                    },
                  ),
              ]),
              SwitchListTile.adaptive(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text('${l.bracesVerses}  { }', style: TextStyle(fontFamily: uiFont, fontSize: 13.5, color: a.text)),
                value: layers.bracesAreVerses,
                onChanged: (v) => update(layers.copyWith(bracesAreVerses: v)),
              ),
            ],
          ),
        ),
      ],
    ]);
  }
}

/// A delimiter chip with three states: off, always matn, matn when quoted
/// from the matn.
class _MarkerChip extends StatelessWidget {
  const _MarkerChip({required this.label, required this.state, required this.onTap});
  final String label;
  final int state;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final on = state != 0;
    final color = state == 2 ? AuraHues.teal : a.accent;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: on ? color.withValues(alpha: a.dark ? 0.22 : 0.12) : a.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (on) ...[Icon(state == 1 ? Icons.check_rounded : Icons.fact_check_outlined, size: 16, color: color), const SizedBox(width: 6)],
          Text(label, textDirection: TextDirection.rtl, style: TextStyle(fontFamily: arabicFont, fontSize: 15, color: on ? color : a.text)),
        ]),
      ),
    );
  }
}

/// Text size and line spacing steppers.
class ReaderTextControls extends StatelessWidget {
  const ReaderTextControls({super.key, required this.reading, this.dense = false});
  final ReadingController reading;

  /// Smaller, for the phone's reading tools.
  final bool dense;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final size = reading.fontScale.clamp(0.75, 1.8);
    final line = reading.lineHeight.clamp(1.6, 2.9);
    return Column(children: [
      ReaderSlider(
        label: l.textSize,
        value: size,
        min: 0.75,
        max: 1.8,
        divisions: 21,
        shown: '${(size * 100).round()}%',
        lo: Icons.text_decrease_rounded,
        hi: Icons.text_increase_rounded,
        dense: dense,
        accent: a.accent,
        onChanged: (v) => reading.setFontScale((v * 20).round() / 20),
      ),
      SizedBox(height: dense ? 6 : 8),
      ReaderSlider(
        label: l.lineSpacing,
        value: line,
        min: 1.6,
        max: 2.9,
        divisions: 13,
        shown: line.toStringAsFixed(1),
        lo: Icons.density_small_rounded,
        hi: Icons.density_large_rounded,
        dense: dense,
        accent: a.accent,
        onChanged: (v) => reading.setLineHeight((v * 10).round() / 10),
      ),
    ]);
  }
}

/// A labelled slider in a soft card: the value in a pill, small and large
/// icons at the ends of a thick rounded track.
class ReaderSlider extends StatelessWidget {
  const ReaderSlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.shown,
    required this.lo,
    required this.hi,
    required this.onChanged,
    required this.accent,
    this.dense = false,
  });
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String shown;
  final IconData lo;
  final IconData hi;
  final ValueChanged<double> onChanged;
  final Color accent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      padding: EdgeInsets.fromLTRB(12, dense ? 8 : 10, 12, dense ? 2 : 4),
      decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: dense ? 12.5 : 13.5, fontWeight: FontWeight.w600, color: a.text))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(color: accent.withValues(alpha: a.dark ? 0.22 : 0.12), borderRadius: BorderRadius.circular(20)),
            child: Text(shown, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w800, fontSize: 12, color: accent)),
          ),
        ]),
        Row(children: [
          Icon(lo, size: 16, color: a.muted),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                activeTrackColor: accent,
                inactiveTrackColor: accent.withValues(alpha: 0.16),
                thumbColor: accent,
                overlayColor: accent.withValues(alpha: 0.12),
                activeTickMarkColor: Colors.white.withValues(alpha: 0.55),
                inactiveTickMarkColor: accent.withValues(alpha: 0.35),
                tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 1.2),
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9, elevation: 2, pressedElevation: 4),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                trackShape: const RoundedRectSliderTrackShape(),
                showValueIndicator: ShowValueIndicator.never,
              ),
              child: Slider(value: value, min: min, max: max, divisions: divisions, semanticFormatterCallback: (_) => shown, onChanged: onChanged),
            ),
          ),
          Icon(hi, size: 20, color: a.muted),
        ]),
      ]),
    );
  }
}

/// Jump to a volume and page from the reading tools: the printed page when
/// the book has a page map, otherwise Turath's page number.
class _GoToRow extends StatefulWidget {
  const _GoToRow({required this.book, required this.current, required this.onGo, this.dense = false});
  final BookDetails? book;
  final int current;
  final ValueChanged<int> onGo;
  final bool dense;
  @override
  State<_GoToRow> createState() => _GoToRowState();
}

class _GoToRowState extends State<_GoToRow> {
  late final bool _printed = widget.book?.pageMap.isNotEmpty ?? false;
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
    if (page == null) return;
    Navigator.of(context).pop();
    widget.onGo(page);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final volumes = widget.book?.volumes ?? const <String>[];
    final style = TextStyle(fontFamily: uiFont, fontSize: widget.dense ? 13 : 14, color: a.text);
    final bounds = _printed ? widget.book?.volumeBounds[_volume] : null;
    final last = bounds == null ? null : widget.book?.locate(bounds.$2).printed;
    final hint = _printed ? (last == null ? l.printedPage : '${l.printedPage} · 1–$last') : l.turathPage;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(10, 4, 4, 4),
      decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(16)),
      child: Row(children: [
        Icon(Icons.move_down_rounded, size: 19, color: a.accent),
        const SizedBox(width: 8),
        if (_printed && volumes.length > 1) ...[
          // The volume, as a compact menu.
          PopupMenuButton<String>(
            tooltip: l.volume,
            initialValue: _volume,
            onSelected: (v) => setState(() => _volume = v),
            itemBuilder: (_) => [for (final v in volumes) PopupMenuItem(value: v, height: 38, child: Text('${l.volume} $v', style: style))],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: a.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('${l.volume} $_volume', style: style.copyWith(fontWeight: FontWeight.w700)),
                Icon(Icons.expand_more_rounded, size: 18, color: a.muted),
              ]),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textInputAction: TextInputAction.go,
            style: style,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: style.copyWith(color: a.muted, fontSize: 12.5),
              filled: true,
              fillColor: a.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: a.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: a.border)),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 6),
        IconButton.filled(
          tooltip: l.go,
          visualDensity: VisualDensity.compact,
          onPressed: _submit,
          icon: Icon(Directionality.of(context) == TextDirection.rtl ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 18),
        ),
      ]),
    );
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

/// Book face chips, each written in its own font.
class FontPicker extends StatelessWidget {
  const FontPicker({super.key, required this.reading});
  final ReadingController reading;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final (id, family, name) in readerFonts(context.l))
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 6),
            child: ChoiceChip(
              selected: reading.fontFamily == id,
              showCheckmark: false,
              onSelected: (_) => reading.setFontFamily(id),
              label: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('بسم الله', style: TextStyle(fontFamily: family, fontSize: 16, height: 1.5, color: reading.fontFamily == id ? a.accent : a.text)),
                Text(name, style: TextStyle(fontFamily: uiFont, fontSize: 10.5, color: a.muted)),
              ]),
            ),
          ),
      ]),
    );
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
        ButtonSegment(value: 'scroll', icon: const Icon(Icons.view_day_outlined, size: 18), label: Text(l.modeScroll, style: TextStyle(fontFamily: uiFont))),
        ButtonSegment(value: 'pages', icon: const Icon(Icons.auto_stories_outlined, size: 18), label: Text(l.modePages, style: TextStyle(fontFamily: uiFont))),
      ],
      selected: {reading.readingMode},
      onSelectionChanged: (s) => reading.setReadingMode(s.first),
    );
  }
}

/// Search inside one book; returns (page, query) for the chosen hit.
/// A book search kept while the reader is open.
class BookSearchMemory {
  String query = '';
  final items = <PagePassage>[];
  int total = 0;
  int page = 0;
  double scroll = 0;

  /// Like Turath's: some words, all words or the words in order; other
  /// forms of the words; footnotes too.
  TextSearchOptions options = TextSearchOptions.standard;
}

class _BookSearchSheet extends StatefulWidget {
  const _BookSearchSheet({required this.bookId, required this.backend, required this.memory});
  final String bookId;
  final ManabiBackend backend;
  final BookSearchMemory memory;
  @override
  State<_BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<_BookSearchSheet> {
  late final _field = TextEditingController(text: widget.memory.query);
  final _focus = FocusNode();
  late final _items = widget.memory.items;
  late String _q = widget.memory.query;
  late int _total = widget.memory.total;
  late int _page = widget.memory.page;
  bool _loading = false;
  String? _error;
  late TextSearchOptions _options = widget.memory.options;

  void _setOptions(TextSearchOptions o) {
    setState(() => _options = widget.memory.options = o);
    if (_field.text.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    widget.memory
      ..query = _q
      ..total = _total
      ..page = _page;
    _field.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _search({bool more = false}) async {
    final q = more ? _q : _field.text.trim();
    if (q.isEmpty || _loading) return;
    if (!more) SearchHistory.add(q, bookId: widget.bookId);
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
      final r = await widget.backend.search(q, page: _page + 1, scope: SearchScope.single(bookId: widget.bookId), options: _options);
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
            child: Column(children: [
              AuraSearchField(controller: _field, focusNode: _focus, hint: l.searchInBookHint, rtl: true, autofocus: _items.isEmpty, onSubmitted: (_) => _search()),
              Directionality(
                textDirection: TextDirection.rtl,
                child: SearchSuggestions(controller: _field, focus: _focus, bookId: widget.bookId, onPick: (_) => _search()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (v, label) in [(1, l.precisionSome), (2, l.precisionAll), (3, l.precisionOrder)])
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: ChoiceChip(
                        label: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 12.5)),
                        selected: _options.precision == v,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) => _setOptions(_options.copyWith(precision: v)),
                      ),
                    ),
                  Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: a.border),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: FilterChip(
                      label: Text(l.extendedSearch, style: TextStyle(fontFamily: uiFont, fontSize: 12.5)),
                      selected: _options.stem,
                      visualDensity: VisualDensity.compact,
                      onSelected: (v) => _setOptions(_options.copyWith(stem: v)),
                    ),
                  ),
                  FilterChip(
                    label: Text(l.searchNotes, style: TextStyle(fontFamily: uiFont, fontSize: 12.5)),
                    selected: _options.notes,
                    visualDensity: VisualDensity.compact,
                    onSelected: (v) => _setOptions(_options.copyWith(notes: v)),
                  ),
                ]),
              ),
            ]),
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
                    ? Center(child: _loading ? const AuraProgress() : (_q.isEmpty ? const SizedBox() : Text(l.noMatchesInBook, style: TextStyle(fontFamily: uiFont, color: a.muted))))
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
                                      ? const AuraProgress()
                                      : SoftButton(onTap: () => _search(more: true), label: l.loadMore, icon: Icons.expand_more_rounded),
                            );
                          }
                          final p = _items[i];
                          final where = [if (p.volume != null) '${l.volumeShort} ${p.volume}', if (p.printedPage != null) '${l.page} ${p.printedPage}'].join(' · ');
                          return SearchHitCard(
                            passage: p,
                            query: [_q],
                            onOpen: p.internalPage == null ? null : () => Navigator.of(context).pop((p.internalPage!, _q)),
                            header: Row(children: [
                              Icon(Icons.description_outlined, size: 15, color: a.accent),
                              const SizedBox(width: 6),
                              Text(where.isEmpty ? '${l.turathPage} ${p.internalPage}' : where,
                                  style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w700, color: a.accent)),
                              if (p.headings.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(child: Text(p.headings.last, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 12.5, color: a.muted))),
                              ],
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
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
      title: Text(l.goToPage, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700)),
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
