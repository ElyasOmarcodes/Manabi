import 'package:flutter/material.dart';

import '../../state/search_history.dart';
import '../theme.dart';
import 'common.dart';

/// Earlier searches under a search field while it has focus: the book's own
/// first, then the rest. A tap searches again, the arrow only fills the
/// field, and × forgets the phrase.
class SearchSuggestions extends StatefulWidget {
  const SearchSuggestions({super.key, required this.controller, required this.focus, required this.onPick, this.bookId, this.padding = EdgeInsets.zero});
  final TextEditingController controller;
  final FocusNode focus;
  final ValueChanged<String> onPick;
  final String? bookId;
  final EdgeInsetsGeometry padding;

  @override
  State<SearchSuggestions> createState() => _SearchSuggestionsState();
}

class _SearchSuggestionsState extends State<SearchSuggestions> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    widget.focus.addListener(_changed);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focus.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    final items = widget.focus.hasFocus ? SearchHistory.suggest(widget.controller.text, bookId: widget.bookId) : const <({String text, bool inBook})>[];
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: items.isEmpty
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: widget.padding,
              child: Container(
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: a.border)),
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  for (final s in items)
                    InkWell(
                      onTap: () {
                        widget.controller.text = s.text;
                        widget.focus.unfocus();
                        widget.onPick(s.text);
                      },
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 2, 2),
                        child: Row(children: [
                          Icon(s.inBook ? Icons.menu_book_outlined : Icons.history_rounded, size: 18, color: s.inBook ? a.accent : a.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(s.text, maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15).copyWith(height: 1.5)),
                          ),
                          IconButton(
                            tooltip: l.fillIn,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.north_west_rounded, size: 16, color: a.faint),
                            onPressed: () {
                              widget.controller.value = TextEditingValue(text: s.text, selection: TextSelection.collapsed(offset: s.text.length));
                              widget.focus.requestFocus();
                            },
                          ),
                          IconButton(
                            tooltip: l.forget,
                            visualDensity: VisualDensity.compact,
                            icon: Icon(Icons.close_rounded, size: 16, color: a.faint),
                            onPressed: () => setState(() => SearchHistory.remove(s.text, bookId: widget.bookId)),
                          ),
                        ]),
                      ),
                    ),
                ]),
              ),
            ),
    );
  }
}
