import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/answer.dart';
import '../../core/models/chat.dart';
import '../../state/chat_controller.dart';
import '../../state/settings_controller.dart';
import '../export/export_actions.dart';
import '../export/exporter.dart';
import '../screens/reader_screen.dart';
import '../theme.dart';
import 'answer_markdown.dart';
import 'common.dart';
import 'research_progress.dart' show formatTokens;

/// Assistant reply in a clean chatbot style: plain text on the page, inline
/// verified Arabic quotes, a quiet action row and a references sheet.
class AnswerCard extends StatelessWidget {
  const AnswerCard({super.key, required this.turn, this.onRetry, this.onMore});
  final ChatTurn turn;
  final VoidCallback? onRetry;

  /// Opens the message menu (actions and token usage).
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final r = turn.result!;
    final l = context.l;
    final a = context.aura;
    final rtl = isRtlLanguage(r.language);
    final scale = context.watch<SettingsController>().arabicScale;
    final chats = context.read<ChatController>();
    void openRefs([int? focus]) => showReferences(context, r, focus: focus);
    final uiDirection = Directionality.of(context);

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Assistant header: mark, name, what the answer rests on.
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Directionality(
              textDirection: uiDirection,
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(gradient: a.brand, shape: BoxShape.circle),
                    child: const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.appName,
                    style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w700, color: a.text),
                  ),
                  if (r.sources.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '· ${l.sourceCount(r.sources.length)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (r.status != AnswerStatus.answered) StatusPill(status: r.status),
                ],
              ),
            ),
          ),
          AnswerMarkdown(markdown: r.answer, onCite: openRefs, quoteScale: scale),
          if (r.detail.isNotEmpty && !r.isDocumented)
            Text(
              r.detail,
              style: TextStyle(fontFamily: uiFont, color: a.muted, height: 1.75),
            ),
          if (r.notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                r.notes,
                style: TextStyle(fontFamily: uiFont, fontSize: 13.5, color: a.muted, height: 1.7),
              ),
            ),
          if (r.related.isNotEmpty && r.sources.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              l.relatedSources,
              style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: a.muted),
            ),
            for (final s in r.related.take(5)) _RelatedTile(source: s),
          ],
          if (r.sources.isNotEmpty) ...[
            const SizedBox(height: 6),
            // Cited books at a glance; each opens its reference.
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: r.sources.length + 1,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Pressable(
                      onTap: openRefs,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 17, color: a.accent),
                            const SizedBox(width: 6),
                            Text(
                              '${l.sources} (${r.sources.length})',
                              style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w700, color: a.accent),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  final src = r.sources[i - 1];
                  return Pressable(
                    onTap: () => openRefs(src.n),
                    child: Container(
                      width: 200,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: a.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: a.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(7)),
                            child: Text(
                              '${src.n}',
                              style: TextStyle(fontFamily: uiFont, fontSize: 11.5, fontWeight: FontWeight.w800, color: a.accent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    src.bookTitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: arabicStyle(context, size: 13, weight: FontWeight.w700).copyWith(height: 1.35),
                                  ),
                                  Text(
                                    [if (src.authorName != null) src.authorName!, if (src.printedPage != null) '${l.page} ${src.printedPage}'].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontFamily: uiFont, fontSize: 11, color: a.muted, height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 2,
            runSpacing: 4,
            children: [
              _Action(icon: Icons.copy_rounded, tooltip: l.copy, onTap: () => copyText(context, answerAsText(turn, l))),
              _Action(icon: Icons.ios_share_rounded, tooltip: l.share, onTap: () => shareTurnText(context, turn)),
              _Action(
                icon: turn.favorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                tooltip: turn.favorite ? l.unsave : l.save,
                color: turn.favorite ? a.accent : null,
                onTap: () {
                  chats.toggleFavorite(turn);
                  toast(context, turn.favorite ? l.saved : l.unsave);
                },
              ),
              _Action(
                icon: Icons.picture_as_pdf_outlined,
                tooltip: l.export,
                onTap: () => showExportSheet(context, title: turn.question, turns: [turn], uiLanguage: context.read<SettingsController>().uiLanguage),
              ),
              if (onRetry != null) _Action(icon: Icons.refresh_rounded, tooltip: l.retry, onTap: onRetry!),
              if (onMore != null) _Action(icon: Icons.more_horiz_rounded, tooltip: l.moreActions, onTap: onMore!),
              if (!r.usage.isEmpty)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 6),
                  child: Text(l.tokensCount(formatTokens(r.usage.total)), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.faint)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> showReferences(BuildContext context, AnswerResult r, {int? focus}) => showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FractionallySizedBox(
    heightFactor: 0.88,
    child: _ReferencesSheet(result: r, focus: focus),
  ),
);

class _ReferencesSheet extends StatefulWidget {
  const _ReferencesSheet({required this.result, this.focus});
  final AnswerResult result;
  final int? focus;
  @override
  State<_ReferencesSheet> createState() => _ReferencesSheetState();
}

class _ReferencesSheetState extends State<_ReferencesSheet> {
  final _keys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    if (widget.focus != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.focus]?.currentContext;
        if (ctx != null) Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), alignment: 0.05);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final r = widget.result;
    return Directionality(
      textDirection: Directionality.of(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
            child: Row(
              children: [
                Text(
                  '${l.sources} (${r.sources.length})',
                  style: TextStyle(fontFamily: uiFont, fontSize: 19, fontWeight: FontWeight.w800, color: a.text),
                ),
                const Spacer(),
                if (r.queries.isNotEmpty) Icon(Icons.manage_search_rounded, size: 18, color: a.faint),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              children: [
                for (final s in r.sources)
                  Padding(
                    key: _keys.putIfAbsent(s.n, GlobalKey.new),
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SourceCard(source: s, highlight: s.n == widget.focus),
                  ),
                if (r.opinions.isNotEmpty) ...[
                  SectionLabel(l.opinions),
                  for (final o in r.opinions)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${o.holder}: ',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            TextSpan(text: o.view),
                            TextSpan(
                              text: '  ${o.sources.map((n) => '[$n]').join()}',
                              style: TextStyle(color: a.accent, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        style: TextStyle(fontFamily: uiFont, color: a.text, height: 1.7),
                      ),
                    ),
                ],
                if (r.queries.isNotEmpty) ...[
                  SectionLabel(l.searchedFor),
                  Wrap(spacing: 6, runSpacing: 6, children: [for (final q in r.queries) QueryChip(q)]),
                ],
                const SizedBox(height: 16),
                Text(
                  l.disclaimer,
                  style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.status});
  final AnswerStatus status;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return switch (status) {
      AnswerStatus.answered => StatusBadge(label: l.statusAnswered, color: a.success, icon: Icons.verified_rounded),
      AnswerStatus.partial => StatusBadge(label: l.statusPartial, color: a.warning, icon: Icons.rule_rounded),
      AnswerStatus.insufficient => StatusBadge(label: l.statusInsufficient, color: a.muted, icon: Icons.search_off_rounded),
    };
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => AuraIconButton(icon: icon, tooltip: tooltip, onTap: onTap, size: 34, filled: false, color: color ?? context.aura.muted);
}

class QueryChip extends StatelessWidget {
  const QueryChip(this.q, {super.key});
  final String q;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
    decoration: BoxDecoration(color: context.aura.surfaceAlt, borderRadius: BorderRadius.circular(10)),
    child: Text(
      q,
      textDirection: TextDirection.rtl,
      style: arabicStyle(context, size: 13.5, color: context.aura.muted).copyWith(height: 1.7),
    ),
  );
}

/// One numbered source: metadata, verified Arabic quote and links.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.source, this.highlight = false});
  final AnswerSource source;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final scale = context.watch<SettingsController>().arabicScale;
    final s = source;
    final location = [
      if (s.volume != null) '${l.volume} ${s.volume}',
      if (s.printedPage != null) '${l.page} ${s.printedPage}',
      if (s.internalPage != null) '${l.turathPage} ${s.internalPage}',
    ].join('  ·  ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: a.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: highlight ? a.accent : a.border, width: highlight ? 1.5 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  '${s.n}',
                  style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w800, color: a.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.bookTitle,
                        style: arabicStyle(context, size: 16.5, scale: scale, weight: FontWeight.w700).copyWith(height: 1.55),
                      ),
                      if (s.authorName != null)
                        Text(
                          s.authorName!,
                          style: arabicStyle(context, size: 14, scale: scale, color: a.muted).copyWith(height: 1.5),
                        ),
                      if (location.isNotEmpty)
                        Text(
                          location,
                          style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          for (final q in s.quotes) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(14)),
              child: SelectableText(
                q.text,
                textDirection: TextDirection.rtl,
                style: arabicStyle(context, size: 17.5, scale: scale),
              ),
            ),
          ],
          if (s.quotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 14, color: a.success),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l.quoteVerified,
                      style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.success),
                    ),
                  ),
                ],
              ),
            )
          else if (s.excerpt.trim().isNotEmpty) ...[
            // Cited without a word-for-word quote: show the page passage it relies on.
            const SizedBox(height: 10),
            _Excerpt(text: s.excerpt.trim(), scale: scale),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 14, color: a.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l.pageExcerpt,
                      style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (s.internalPage != null)
                SoftButton(
                  dense: true,
                  icon: Icons.chrome_reader_mode_outlined,
                  label: l.viewSource,
                  onTap: () => openReader(context, s.bookId, s.internalPage!, title: s.bookTitle, highlight: s.quotes.isEmpty ? null : s.quotes.first.text),
                ),
              SoftButton(dense: true, icon: Icons.open_in_new_rounded, label: l.openLink, color: a.muted, onTap: () => openUrl(s.url)),
              if (s.shamelaUrl != null) SoftButton(dense: true, label: l.openShamela, color: a.muted, onTap: () => openUrl(s.shamelaUrl!)),
              SoftButton(dense: true, icon: Icons.copy_rounded, label: l.copy, color: a.muted, onTap: () => copyText(context, sourceAsText(s, l))),
            ],
          ),
        ],
      ),
    );
  }
}

/// A page passage that can be expanded (collapsed to a few lines).
class _Excerpt extends StatefulWidget {
  const _Excerpt({required this.text, required this.scale});
  final String text;
  final double scale;
  @override
  State<_Excerpt> createState() => _ExcerptState();
}

class _ExcerptState extends State<_Excerpt> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: Text(
            widget.text,
            textDirection: TextDirection.rtl,
            maxLines: _open ? null : 4,
            overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
            style: arabicStyle(context, size: 16, scale: widget.scale, color: a.text.withValues(alpha: 0.85)),
          ),
        ),
      ),
    );
  }
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.source});
  final AnswerSource source;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(12),
    onTap: source.internalPage == null ? () => openUrl(source.url) : () => openReader(context, source.bookId, source.internalPage!, title: source.bookTitle),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 18, color: context.aura.faint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              source.citation ?? source.bookTitle,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: arabicStyle(context, size: 14.5, color: context.aura.muted).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}

