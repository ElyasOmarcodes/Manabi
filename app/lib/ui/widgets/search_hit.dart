import 'package:flutter/material.dart';

import '../../core/models/library.dart';
import '../../core/turath/arabic_match.dart';
import '../../state/reading_controller.dart' show stripDiacritics;
import '../theme.dart';
import 'common.dart';

/// One search result: a short excerpt, with a button that opens the whole
/// page right there (and closes it again). Tapping the card opens the page.
class SearchHitCard extends StatefulWidget {
  const SearchHitCard({
    super.key,
    required this.passage,
    required this.query,
    required this.header,
    this.onOpen,
    this.expanded = false,
    this.hideDiacritics = false,
    this.trailing = const [],
    this.footer,
  });
  final PagePassage passage;

  /// Words to mark (the search, or several phrases joined by spaces).
  final List<String> query;
  final Widget header;
  final VoidCallback? onOpen;

  /// Start with the whole page shown ("show each result in full").
  final bool expanded;
  final bool hideDiacritics;
  final List<Widget> trailing;
  final Widget? footer;

  @override
  State<SearchHitCard> createState() => _SearchHitCardState();
}

class _SearchHitCardState extends State<SearchHitCard> {
  late bool _open = widget.expanded;

  @override
  void didUpdateWidget(SearchHitCard old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded) _open = widget.expanded;
  }

  String _clean(String t) => widget.hideDiacritics ? stripDiacritics(t) : t;

  TextSpan _marked(BuildContext context, String text, TextStyle style) {
    final ranges = <(int, int)>[for (final q in widget.query) ...arabicMatches(text, q)]..sort((a, b) => a.$1.compareTo(b.$1));
    if (ranges.isEmpty) return TextSpan(text: text, style: style);
    final spans = <TextSpan>[];
    var at = 0;
    for (final (s, e) in ranges) {
      if (s < at) continue;
      spans
        ..add(TextSpan(text: text.substring(at, s)))
        ..add(TextSpan(
          text: text.substring(s, e),
          style: TextStyle(color: context.aura.accent, fontWeight: FontWeight.w700, backgroundColor: context.aura.accent.withValues(alpha: 0.08)),
        ));
      at = e;
    }
    spans.add(TextSpan(text: text.substring(at)));
    return TextSpan(style: style, children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final p = widget.passage;
    final excerpt = _clean(p.snippet ?? p.text);
    final whole = _clean(p.text);
    final style = arabicStyle(context, size: 15.5).copyWith(height: 1.9);
    return Material(
      color: a.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: widget.onOpen,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), border: Border.all(color: _open ? a.accent.withValues(alpha: 0.4) : a.border)),
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: widget.header),
                ...widget.trailing,
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: _open ? l.showLess : l.showWholePage,
                  icon: AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more_rounded, size: 22, color: _open ? a.accent : a.muted),
                  ),
                  onPressed: () => setState(() => _open = !_open),
                ),
              ]),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: _open
                      ? SelectionArea(child: Text.rich(_marked(context, whole, style)))
                      : Text.rich(_marked(context, excerpt, style), maxLines: 4, overflow: TextOverflow.ellipsis),
                ),
              ),
              ?widget.footer,
            ]),
          ),
        ),
      ),
    );
  }
}
