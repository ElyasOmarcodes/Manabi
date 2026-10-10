import 'dart:math' as math;

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

/// Assistant reply in a clean chatbot style: plain text on the page, inline
/// verified Arabic quotes, a quiet action row and a references sheet.
class AnswerCard extends StatelessWidget {
  const AnswerCard({super.key, required this.turn, this.onRetry});
  final ChatTurn turn;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final r = turn.result!;
    final l = context.l;
    final a = context.aura;
    final rtl = isRtlLanguage(r.language);
    final scale = context.watch<SettingsController>().arabicScale;
    final chats = context.read<ChatController>();
    void openRefs([int? focus]) => showReferences(context, r, focus: focus);

    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (r.status != AnswerStatus.answered)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Align(alignment: AlignmentDirectional.centerStart, child: StatusPill(status: r.status))),
        AnswerMarkdown(markdown: r.answer, onCite: openRefs, quoteScale: scale),
        if (r.detail.isNotEmpty && !r.isDocumented) Text(r.detail, style: TextStyle(fontFamily: uiFont, color: a.muted, height: 1.75)),
        if (r.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(r.notes, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, color: a.muted, height: 1.7)),
          ),
        if (r.related.isNotEmpty && r.sources.isEmpty) ...[
          const SizedBox(height: 6),
          Text(l.relatedSources, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: a.muted)),
          for (final s in r.related.take(5)) _RelatedTile(source: s),
        ],
        const SizedBox(height: 10),
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 2, runSpacing: 4, children: [
          if (r.sources.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: Pressable(
                onTap: openRefs,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.menu_book_rounded, size: 16, color: a.accent),
                    const SizedBox(width: 6),
                    Text('${l.sources} (${r.sources.length})', style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: a.text)),
                    const SizedBox(width: 6),
                    _CoverStack(sources: r.sources),
                  ]),
                ),
              ),
            ),
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
        ]),
      ]),
    );
  }
}

/// Small overlapping book-cover dots next to the references button.
class _CoverStack extends StatelessWidget {
  const _CoverStack({required this.sources});
  final List<AnswerSource> sources;
  @override
  Widget build(BuildContext context) {
    final n = math.min(3, sources.length);
    return SizedBox(
      width: 14.0 + (n - 1) * 9,
      height: 16,
      child: Stack(children: [
        for (var i = 0; i < n; i++)
          PositionedDirectional(
            start: i * 9.0,
            child: Container(
              width: 14,
              height: 16,
              decoration: BoxDecoration(
                gradient: context.aura.brand,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: context.aura.surfaceAlt, width: 1.5),
              ),
            ),
          ),
      ]),
    );
  }
}

Future<void> showReferences(BuildContext context, AnswerResult r, {int? focus}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FractionallySizedBox(heightFactor: 0.88, child: _ReferencesSheet(result: r, focus: focus)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
          child: Row(children: [
            Text('${l.sources} (${r.sources.length})', style: TextStyle(fontFamily: uiFont, fontSize: 19, fontWeight: FontWeight.w800, color: a.text)),
            const Spacer(),
            if (r.queries.isNotEmpty) Icon(Icons.manage_search_rounded, size: 18, color: a.faint),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 28), children: [
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
                    TextSpan(children: [
                      TextSpan(text: '${o.holder}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                      TextSpan(text: o.view),
                      TextSpan(text: '  ${o.sources.map((n) => '[$n]').join()}', style: TextStyle(color: a.accent, fontWeight: FontWeight.w700)),
                    ]),
                    style: TextStyle(fontFamily: uiFont, color: a.text, height: 1.7),
                  ),
                ),
            ],
            if (r.queries.isNotEmpty) ...[
              SectionLabel(l.searchedFor),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final q in r.queries) QueryChip(q)]),
            ],
            const SizedBox(height: 16),
            Text(l.disclaimer, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.6)),
          ]),
        ),
      ]),
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
        child: Text(q, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 13.5, color: context.aura.muted).copyWith(height: 1.7)),
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(8)),
            child: Text('${s.n}', style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w800, color: a.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.bookTitle, style: arabicStyle(context, size: 16.5, scale: scale, weight: FontWeight.w700).copyWith(height: 1.55)),
                if (s.authorName != null) Text(s.authorName!, style: arabicStyle(context, size: 14, scale: scale, color: a.muted).copyWith(height: 1.5)),
                if (location.isNotEmpty) Text(location, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint)),
              ]),
            ),
          ),
        ]),
        for (final q in s.quotes) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(14)),
            child: SelectableText(q.text, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 17.5, scale: scale)),
          ),
        ],
        if (s.quotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.verified_rounded, size: 14, color: a.success),
              const SizedBox(width: 4),
              Expanded(child: Text(l.quoteVerified, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.success))),
            ]),
          )
        else if (s.excerpt.trim().isNotEmpty) ...[
          // Cited without a word-for-word quote: show the page passage it relies on.
          const SizedBox(height: 10),
          _Excerpt(text: s.excerpt.trim(), scale: scale),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              Icon(Icons.description_outlined, size: 14, color: a.muted),
              const SizedBox(width: 4),
              Expanded(child: Text(l.pageExcerpt, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted))),
            ]),
          ),
        ],
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
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
        ]),
      ]),
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
          child: Row(children: [
            Icon(Icons.description_outlined, size: 18, color: context.aura.faint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(source.citation ?? source.bookTitle,
                  textDirection: TextDirection.rtl, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 14.5, color: context.aura.muted).copyWith(height: 1.5)),
            ),
          ]),
        ),
      );
}

/// Gemini-style progress: a rotating brand sparkle with the current step,
/// expandable to show the search details.
class StageTimeline extends StatefulWidget {
  const StageTimeline({super.key, required this.progress, this.onCancel});
  final AskProgress progress;
  final VoidCallback? onCancel;
  @override
  State<StageTimeline> createState() => _StageTimelineState();
}

class _StageTimelineState extends State<StageTimeline> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  bool _open = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final p = widget.progress;
    final label = switch (p.stage) {
      AskStage.planning => l.stagePlanning,
      AskStage.searching => l.stageSearching,
      AskStage.reading => l.stageReading,
      AskStage.composing => l.stageComposing,
      AskStage.verifying => l.stageVerifying,
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            RotationTransition(
              turns: _c,
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => a.brand.createShader(Offset.zero & r.size),
                child: const Icon(Icons.auto_awesome_rounded, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            AnimatedBuilder(
              animation: _c,
              builder: (context, child) => ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (r) => LinearGradient(
                  colors: [a.muted, a.text, a.muted],
                  stops: [(_c.value - 0.3).clamp(0, 1), _c.value, (_c.value + 0.3).clamp(0, 1)],
                ).createShader(Offset.zero & r.size),
                child: child,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(label, key: ValueKey(label), style: const TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 4),
            Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: a.faint),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 250),
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsetsDirectional.only(start: 32, top: 4, bottom: 4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  for (final stage in AskStage.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Icon(stage.index < p.stage.index ? Icons.check_rounded : Icons.circle, size: stage.index < p.stage.index ? 15 : 6, color: stage.index <= p.stage.index ? a.accent : a.faint),
                        const SizedBox(width: 8),
                        Text(
                          switch (stage) {
                            AskStage.planning => l.stagePlanning,
                            AskStage.searching => l.stageSearching,
                            AskStage.reading => l.stageReading,
                            AskStage.composing => l.stageComposing,
                            AskStage.verifying => l.stageVerifying,
                          },
                          style: TextStyle(fontFamily: uiFont, fontSize: 13, color: stage.index <= p.stage.index ? a.text : a.faint),
                        ),
                      ]),
                    ),
                  if (p.queries.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final q in p.queries) QueryChip(q)])),
                  if (p.sourcesFound != null)
                    Padding(padding: const EdgeInsets.only(top: 6), child: Text(l.foundSources(p.sourcesFound!), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted))),
                ]),
              ),
      ),
    ]);
  }
}
