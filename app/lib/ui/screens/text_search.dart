import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/backend/backend.dart' show mapError;
import '../../core/catalog/catalog_service.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../core/turath/arabic_match.dart';
import '../../state/downloads.dart';
import '../../state/search_history.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import '../widgets/answer_card.dart' show QueryChip;
import '../widgets/common.dart';
import '../widgets/search_suggestions.dart';
import '../widgets/scope_picker.dart';
import '../widgets/search_hit.dart';
import 'reader_screen.dart' show openReader;

/// How the text search runs and shows its results; kept between visits.
class TextSearchPrefs {
  TextSearchPrefs({
    this.options = TextSearchOptions.standard,
    this.savedOnly = false,
    this.expandAll = false,
    this.hideDiacritics = false,
    this.orMode = false,
    List<SearchPreset>? presets,
  }) : presets = presets ?? [];
  TextSearchOptions options;
  bool savedOnly;
  bool expandAll;
  bool hideDiacritics;

  /// Several phrases: «and» (every phrase on the page) or «or» (any).
  bool orMode;
  final List<SearchPreset> presets;

  static Future<TextSearchPrefs> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final j = jsonDecode(prefs.getString('textSearch') ?? '{}') as Map<String, dynamic>;
      return TextSearchPrefs(
        options: TextSearchOptions.fromJson(j['options'] as Map<String, dynamic>?),
        savedOnly: j['savedOnly'] == true,
        expandAll: j['expandAll'] == true,
        hideDiacritics: j['hideDiacritics'] == true,
        orMode: j['or'] == true,
        presets: [for (final p in j['presets'] as List? ?? const []) if (p is Map) SearchPreset.fromJson(p.cast<String, dynamic>())],
      );
    } catch (_) {
      return TextSearchPrefs();
    }
  }

  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'textSearch',
        jsonEncode({
          'options': options.toJson(),
          'savedOnly': savedOnly,
          'expandAll': expandAll,
          'hideDiacritics': hideDiacritics,
          'or': orMode,
          'presets': [for (final p in presets) p.toJson()],
        }),
      );
    } catch (_) {}
  }
}

/// A named set of filters and options ("الخيارات المثبتة" on Turath).
class SearchPreset {
  const SearchPreset({required this.name, this.scope = SearchScope.all, this.options = TextSearchOptions.standard});
  final String name;
  final SearchScope scope;
  final TextSearchOptions options;
  Map<String, dynamic> toJson() => {'name': name, 'scope': scope.toJson(), 'options': options.toJson()};
  factory SearchPreset.fromJson(Map<String, dynamic> j) => SearchPreset(
        name: '${j['name'] ?? ''}',
        scope: SearchScope.fromJson(j['scope'] as Map<String, dynamic>?),
        options: TextSearchOptions.fromJson(j['options'] as Map<String, dynamic>?),
      );
}

/// Does [text] contain [phrase] at the given precision (1 some words, 2 all
/// words, 3 the words in order)? Diacritics and letter forms are ignored.
bool phraseIn(String text, String phrase, int precision) {
  final words = phrase.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return true;
  if (precision >= 3 || words.length == 1) return arabicPattern(phrase)?.hasMatch(text) ?? false;
  final hits = words.where((w) => arabicPattern(w)?.hasMatch(text) ?? false).length;
  return precision == 1 ? hits > 0 : hits == words.length;
}

/// Full-text search over Turath, with the options and filters of Turath's
/// own search: precision, extended search, footnotes, tables of contents,
/// several phrases with «and»/«or», saved filters, and offline search in
/// the books kept on the device.
class FullTextPage extends StatefulWidget {
  const FullTextPage({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  State<FullTextPage> createState() => _FullTextPageState();
}

/// The last full-text search, shown again when the page is reopened.
class _LastSearch {
  static String query = '';
  static List<String> phrases = const [];
  static List<PagePassage> items = const [];
  static int total = 0;
  static int page = 0;
  static bool more = false;
  static CatalogCategory? category;
  static CatalogAuthor? author;
  static CatalogBook? book;
}

class _FullTextPageState extends State<FullTextPage> {
  late final _search = TextEditingController(text: widget.initialQuery);
  final _searchFocus = FocusNode();
  final _extra = <TextEditingController>[];
  TextSearchPrefs _prefs = TextSearchPrefs();
  CatalogCategory? _category;
  CatalogAuthor? _author;
  CatalogBook? _book;

  final _items = <PagePassage>[];
  List<String> _phrases = const [];
  int _total = 0;
  int _page = 0;
  bool _loading = false;
  bool _more = false;
  String? _error;

  SearchScope get _scope => SearchScope(
        bookId: _book?.id,
        bookTitle: _book?.title,
        authorId: _author?.id,
        authorName: _author?.name,
        categoryId: _category?.id,
        categoryTitle: _category?.title,
      );

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isEmpty && _LastSearch.items.isNotEmpty) {
      _search.text = _LastSearch.query;
      _phrases = _LastSearch.phrases;
      _items.addAll(_LastSearch.items);
      _total = _LastSearch.total;
      _page = _LastSearch.page;
      _more = _LastSearch.more;
      _category = _LastSearch.category;
      _author = _LastSearch.author;
      _book = _LastSearch.book;
    }
    TextSearchPrefs.load().then((p) {
      if (!mounted) return;
      setState(() => _prefs = p);
      if (widget.initialQuery.trim().isNotEmpty) _run();
    });
  }

  @override
  void dispose() {
    if (_items.isNotEmpty) {
      _LastSearch.query = _search.text;
      _LastSearch.phrases = _phrases;
      _LastSearch.items = List.of(_items);
      _LastSearch.total = _total;
      _LastSearch.page = _page;
      _LastSearch.more = _more;
      _LastSearch.category = _category;
      _LastSearch.author = _author;
      _LastSearch.book = _book;
    }
    _search.dispose();
    _searchFocus.dispose();
    for (final c in _extra) {
      c.dispose();
    }
    super.dispose();
  }

  List<String> get _allPhrases => [_search.text.trim(), for (final c in _extra) c.text.trim()].where((p) => p.isNotEmpty).toList();

  Future<void> _run({bool more = false}) async {
    final phrases = more ? _phrases : _allPhrases;
    if (phrases.isEmpty || _loading) return;
    final settings = context.read<SettingsController>();
    final downloads = context.read<DownloadController>();
    if (!more) {
      for (final p in phrases) {
        SearchHistory.add(p, bookId: _book?.id);
      }
    }
    setState(() {
      _loading = true;
      _error = null;
      _phrases = phrases;
      if (!more) {
        _items.clear();
        _page = 0;
        _total = 0;
      }
    });
    final o = _prefs.options;
    try {
      if (_prefs.savedOnly) {
        // Offline: the saved pages, filtered here.
        final scope = _scope;
        final found = await downloads.searchSaved((t) {
          final hits = phrases.where((p) => phraseIn(t, p, o.precision));
          return _prefs.orMode ? hits.isNotEmpty : hits.length == phrases.length;
        }, bookIds: scope.bookId == null ? null : {scope.bookId!});
        final filtered = [
          for (final p in found)
            if ((scope.authorId == null || p.authorId == scope.authorId) && (scope.categoryId == null || p.categoryId == scope.categoryId)) p,
        ];
        setState(() {
          _items.addAll(filtered);
          _total = filtered.length;
          _more = false;
        });
        return;
      }
      final backend = settings.backend;
      final page = _page + 1;
      if (phrases.length == 1 || !_prefs.orMode) {
        // One phrase, or «and»: search the first phrase, keep the pages that
        // also have every other phrase.
        final r = await backend.search(phrases.first, page: page, scope: _scope, options: o);
        final rest = phrases.skip(1).toList();
        final keep = [for (final p in r.items) if (rest.every((x) => phraseIn(p.text, x, o.precision))) p];
        setState(() {
          _items.addAll(keep);
          _total = rest.isEmpty ? r.totalMatches : _items.length;
          _page = r.page;
          _more = r.items.isNotEmpty && _page * 10 < r.totalMatches;
        });
      } else {
        // «or»: each phrase's results, merged in turn.
        final pages = await Future.wait([for (final p in phrases) backend.search(p, page: page, scope: _scope, options: o)]);
        final seen = {for (final p in _items) '${p.bookId}:${p.internalPage}'};
        final merged = <PagePassage>[];
        final longest = pages.fold(0, (m, r) => r.items.length > m ? r.items.length : m);
        for (var i = 0; i < longest; i++) {
          for (final r in pages) {
            if (i < r.items.length && seen.add('${r.items[i].bookId}:${r.items[i].internalPage}')) merged.add(r.items[i]);
          }
        }
        setState(() {
          _items.addAll(merged);
          _total = pages.fold(0, (s, r) => s + r.totalMatches);
          _page = page;
          _more = pages.any((r) => r.items.isNotEmpty && page * 10 < r.totalMatches);
        });
      }
    } catch (e) {
      setState(() => _error = mapError(e).code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _setPrefs(void Function() change) {
    setState(change);
    _prefs.save();
  }

  Future<void> _openOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => _OptionsSheet(
          prefs: _prefs,
          extra: _extra,
          onChanged: (change) {
            _setPrefs(change);
            setSheet(() {});
          },
        ),
      ),
    );
    if (_allPhrases.isNotEmpty) _run();
  }

  Future<void> _openPresets() async {
    final l = context.l;
    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PresetsSheet(prefs: _prefs, onDelete: (p) => _setPrefs(() => _prefs.presets.remove(p))),
    );
    if (!mounted) return;
    if (choice is SearchPreset) {
      final catalog = context.read<CatalogService>();
      setState(() {
        _book = choice.scope.bookId == null ? null : catalog.book(choice.scope.bookId) ?? CatalogBook(choice.scope.bookId!, choice.scope.bookTitle ?? '', '', '');
        _author = choice.scope.authorId == null ? null : catalog.author(choice.scope.authorId) ?? CatalogAuthor(choice.scope.authorId!, choice.scope.authorName ?? '', 0);
        _category = choice.scope.categoryId == null ? null : catalog.category(choice.scope.categoryId) ?? CatalogCategory(choice.scope.categoryId!, choice.scope.categoryTitle ?? '', 0);
      });
      _setPrefs(() => _prefs.options = choice.options);
      _run();
    } else if (choice == 'save') {
      final name = await _askName(l.pinnedName);
      if (name != null && name.trim().isNotEmpty) {
        _setPrefs(() => _prefs.presets.add(SearchPreset(name: name.trim(), scope: _scope, options: _prefs.options)));
      }
    }
  }

  Future<String?> _askName(String label) {
    final c = TextEditingController(text: [?_book?.title, ?_author?.name, ?_category?.title].join(' · '));
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l.savePinned, style: TextStyle(fontFamily: uiFont)),
        content: TextField(controller: c, autofocus: true, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(ctx.l.save)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final o = _prefs.options;
    final activeOptions = !o.isStandard || _prefs.savedOnly || _extra.isNotEmpty;
    final downloads = context.watch<DownloadController>();
    return AuraPage(
      titleText: l.fullTextSearch,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: ReadingWidth(
            maxWidth: 940,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Directionality(
                textDirection: TextDirection.rtl,
                child: Container(
                  decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(18)),
                  padding: const EdgeInsetsDirectional.only(start: 14, end: 4),
                  child: Row(children: [
                    Icon(Icons.search_rounded, size: 20, color: a.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        focusNode: _searchFocus,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _run(),
                        style: arabicStyle(context, size: 16),
                        decoration: InputDecoration(border: InputBorder.none, isDense: true, hintText: l.searchInText, filled: false),
                      ),
                    ),
                    IconButton(
                      tooltip: l.pinnedFilters,
                      icon: Icon(Icons.bookmarks_outlined, size: 20, color: a.muted),
                      onPressed: _openPresets,
                    ),
                    IconButton(
                      tooltip: l.searchOptions,
                      icon: Badge(isLabelVisible: activeOptions, smallSize: 7, child: Icon(Icons.tune_rounded, size: 21, color: activeOptions ? a.accent : a.muted)),
                      onPressed: _openOptions,
                    ),
                  ]),
                ),
              ),
              Directionality(
                textDirection: TextDirection.rtl,
                child: SearchSuggestions(controller: _search, focus: _searchFocus, bookId: _book?.id, onPick: (_) => _run()),
              ),
              FilterChipsRow(
                category: _category,
                author: _author,
                book: _book,
                onCategory: (c) => setState(() => _category = c),
                onAuthor: (x) => setState(() => _author = x),
                onBook: (b) => setState(() => _book = b),
                onChanged: _run,
              ),
              if (_prefs.savedOnly || o.toc || _extra.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(spacing: 6, runSpacing: 6, children: [
                    if (_prefs.savedOnly) _Flag(icon: Icons.download_done_rounded, text: l.savedBooksCount(downloads.books.length)),
                    if (o.toc) _Flag(icon: Icons.toc_rounded, text: l.searchToc),
                    if (_extra.isNotEmpty) _Flag(icon: Icons.join_inner_rounded, text: '${_allPhrases.length} · ${_prefs.orMode ? l.logicOr : l.logicAnd}'),
                  ]),
                ),
            ]),
          ),
        ),
        Expanded(child: ReadingWidth(maxWidth: 940, child: _results(context))),
      ]),
    );
  }

  Widget _results(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    if (_error != null && _items.isEmpty) return ErrorPanel(code: _error, onRetry: _run);
    if (_items.isEmpty) {
      if (_loading) return const Center(child: AuraProgress());
      return EmptyState(icon: Icons.manage_search_rounded, text: _phrases.isEmpty ? l.fullTextSub : l.noResults, color: AuraHues.green);
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
      itemCount: _items.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(6, 0, 6, 8),
            child: Text(l.matches(_total), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.muted)),
          );
        }
        if (i == _items.length + 1) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: !_more
                  ? const SizedBox()
                  : _loading
                      ? const AuraProgress()
                      : SoftButton(onTap: () => _run(more: true), label: l.loadMore, icon: Icons.expand_more_rounded),
            ),
          );
        }
        final p = _items[i - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SearchHitCard(
            passage: p,
            query: _phrases,
            expanded: _prefs.expandAll,
            hideDiacritics: _prefs.hideDiacritics,
            onOpen: p.internalPage == null ? () => openUrl(p.url) : () => openReader(context, p.bookId, p.internalPage!, title: p.bookTitle, highlight: _phrases.first),
            header: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('$i', style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w800, color: a.faint)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.bookTitle, style: arabicStyle(context, size: 15.5, weight: FontWeight.w700, color: a.accent).copyWith(height: 1.5)),
                  Text(p.citation ?? [?p.authorName, if (p.printedPage != null) '${l.page} ${p.printedPage}'].join(' · '),
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
                ]),
              ),
            ]),
            trailing: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: l.copy,
                icon: Icon(Icons.copy_rounded, size: 18, color: a.muted),
                onPressed: () => copyText(context, '${p.snippet ?? p.text}\n\n— ${p.citation ?? p.bookTitle}\n${p.url}'),
              ),
            ],
            footer: p.headings.isEmpty
                ? null
                : Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: AlignmentDirectional.centerStart, child: QueryChip(p.headings.last))),
          ),
        );
      },
    );
  }
}

class _Flag extends StatelessWidget {
  const _Flag({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: a.accent),
        const SizedBox(width: 5),
        Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.accent, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

/// Precision, extended search, footnotes, contents, offline, display, and
/// the «and»/«or» phrases.
class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet({required this.prefs, required this.extra, required this.onChanged});
  final TextSearchPrefs prefs;
  final List<TextEditingController> extra;
  final void Function(void Function() change) onChanged;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final o = prefs.options;
    Widget title(String t) => Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 4),
          child: Text(t, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w800, color: a.muted)),
        );
    Widget toggle(String label, String? sub, bool value, ValueChanged<bool> set, {bool enabled = true}) => SwitchListTile.adaptive(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          title: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, color: a.text)),
          subtitle: sub == null ? null : Text(sub, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
          value: value,
          onChanged: enabled ? (v) => onChanged(() => set(v)) : null,
        );
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: ListView(controller: scroll, padding: const EdgeInsets.only(bottom: 24), children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 4),
            child: Text(l.searchOptions, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: a.text)),
          ),
          title(l.precisionLabel),
          RadioGroup<int>(
            groupValue: o.precision,
            onChanged: (v) => onChanged(() => prefs.options = o.copyWith(precision: v)),
            child: Column(children: [
              for (final (v, label) in [(1, l.precisionSome), (2, l.precisionAll), (3, l.precisionOrder)])
                RadioListTile<int>(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  value: v,
                  title: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, color: a.text)),
                ),
            ]),
          ),
          const Divider(height: 18),
          toggle(l.extendedSearch, l.extendedSearchSub, o.stem, (v) => prefs.options = o.copyWith(stem: v), enabled: !prefs.savedOnly),
          toggle(l.searchNotes, l.searchNotesSub, o.notes, (v) => prefs.options = o.copyWith(notes: v), enabled: !prefs.savedOnly),
          toggle(l.searchToc, l.searchTocSub, o.toc, (v) => prefs.options = o.copyWith(toc: v), enabled: !prefs.savedOnly),
          toggle(l.searchSavedOnly, l.searchSavedOnlySub, prefs.savedOnly, (v) => prefs.savedOnly = v),
          const Divider(height: 18),
          toggle(l.showFullResults, null, prefs.expandAll, (v) => prefs.expandAll = v),
          toggle(l.hideDiacriticsResults, null, prefs.hideDiacritics, (v) => prefs.hideDiacritics = v),
          const Divider(height: 18),
          title(l.logicLabel),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(value: false, label: Text(l.logicAnd, style: TextStyle(fontFamily: uiFont))),
                  ButtonSegment(value: true, label: Text(l.logicOr, style: TextStyle(fontFamily: uiFont))),
                ],
                selected: {prefs.orMode},
                onSelectionChanged: (s) => onChanged(() => prefs.orMode = s.first),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 4),
                child: Text(l.logicHint, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted, height: 1.45)),
              ),
              for (var i = 0; i < extra.length; i++)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    Expanded(
                      child: TextField(
                        controller: extra[i],
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(isDense: true, labelText: l.phraseN(i + 2)),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      onPressed: () => onChanged(() => extra.removeAt(i).dispose()),
                    ),
                  ]),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => onChanged(() => extra.add(TextEditingController())),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(l.addPhrase, style: TextStyle(fontFamily: uiFont)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _PresetsSheet extends StatefulWidget {
  const _PresetsSheet({required this.prefs, required this.onDelete});
  final TextSearchPrefs prefs;
  final ValueChanged<SearchPreset> onDelete;
  @override
  State<_PresetsSheet> createState() => _PresetsSheetState();
}

class _PresetsSheetState extends State<_PresetsSheet> {
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final presets = widget.prefs.presets;
    return SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 0, 20, 6),
          child: Text(l.pinnedFilters, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: a.text)),
        ),
        if (presets.isEmpty)
          Padding(padding: const EdgeInsets.all(20), child: Text(l.noPinned, style: TextStyle(fontFamily: uiFont, color: a.muted))),
        for (final p in presets)
          ListTile(
            leading: Icon(Icons.bookmark_rounded, color: a.accent),
            title: Text(p.name, style: TextStyle(fontFamily: uiFont, color: a.text)),
            subtitle: Text([?p.scope.bookTitle, ?p.scope.authorName, ?p.scope.categoryTitle].join(' · '),
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
            onTap: () => Navigator.pop(context, p),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: a.muted),
              onPressed: () {
                widget.onDelete(p);
                setState(() {});
              },
            ),
          ),
        const Divider(height: 1),
        ListTile(
          leading: Icon(Icons.add_rounded, color: a.accent),
          title: Text(l.savePinned, style: TextStyle(fontFamily: uiFont, color: a.accent, fontWeight: FontWeight.w600)),
          onTap: () => Navigator.pop(context, 'save'),
        ),
        const SizedBox(height: 8),
      ]),
    );
  }
}

/// Category, author and book filters for the text search.
class FilterChipsRow extends StatelessWidget {
  const FilterChipsRow({super.key, required this.category, required this.author, required this.book, required this.onCategory, required this.onAuthor, required this.onBook, required this.onChanged});
  final CatalogCategory? category;
  final CatalogAuthor? author;
  final CatalogBook? book;
  final ValueChanged<CatalogCategory?> onCategory;
  final ValueChanged<CatalogAuthor?> onAuthor;
  final ValueChanged<CatalogBook?> onBook;
  final VoidCallback onChanged;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    Widget chip(String label, IconData icon, bool active, Future<void> Function() pick, VoidCallback clear) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Pressable(
            onTap: () async {
              await pick();
              onChanged();
            },
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
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? a.accent : a.text)),
                ),
                const SizedBox(width: 2),
                if (active)
                  GestureDetector(
                    onTap: () {
                      clear();
                      onChanged();
                    },
                    child: Icon(Icons.close_rounded, size: 15, color: a.accent),
                  )
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
          chip(category?.title ?? l.anyCategory, Icons.category_outlined, category != null, () async {
            final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
            if (c != null) onCategory(c);
          }, () => onCategory(null)),
          chip(author?.name ?? l.anyAuthor, Icons.person_outline_rounded, author != null, () async {
            final x = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
            if (x != null) onAuthor(x);
          }, () => onAuthor(null)),
          chip(book?.title ?? l.anyBook, Icons.menu_book_outlined, book != null, () async {
            final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: author?.id, categoryId: category?.id);
            if (b != null) onBook(b);
          }, () => onBook(null)),
        ]),
      ),
    );
  }
}
