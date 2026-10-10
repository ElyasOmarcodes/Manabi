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

class AnswerCard extends StatefulWidget {
  const AnswerCard({super.key, required this.turn, this.onRetry});
  final ChatTurn turn;
  final VoidCallback? onRetry;
  @override
  State<AnswerCard> createState() => _AnswerCardState();
}

class _AnswerCardState extends State<AnswerCard> {
  final Map<int, GlobalKey> _keys = {};
  int? _flash;

  void _jumpTo(int n) {
    final key = _keys[n];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 480), curve: Curves.easeOutCubic, alignment: 0.15);
    setState(() => _flash = n);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.turn.result!;
    final l = context.l;
    final a = context.aura;
    final rtl = isRtlLanguage(r.language);
    final chats = context.read<ChatController>();
    for (final s in r.sources) {
      _keys.putIfAbsent(s.n, GlobalKey.new);
    }
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const ManabiMark(size: 34),
          const SizedBox(width: 10),
          StatusPill(status: r.status),
          const Spacer(),
          if (r.sources.isNotEmpty)
            Text(l.sourceCount(r.sources.length), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        AuraCard(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnswerMarkdown(markdown: r.answer, onCite: _jumpTo),
            if (r.detail.isNotEmpty && !r.isDocumented) Text(r.detail, style: TextStyle(fontFamily: uiFont, color: a.muted, height: 1.7)),
            if (r.opinions.isNotEmpty) ...[
              SectionLabel(l.opinions),
              for (final (i, o) in r.opinions.indexed) _OpinionTile(opinion: o, color: AuraHues.at(i + 1), onCite: _jumpTo),
            ],
            if (r.notes.isNotEmpty) ...[
              SectionLabel(l.notes),
              Text(r.notes, style: TextStyle(fontFamily: uiFont, color: a.muted, height: 1.7)),
            ],
            const SizedBox(height: 8),
            Divider(color: a.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                _Action(icon: Icons.copy_rounded, tooltip: l.copy, onTap: () => copyText(context, answerAsText(widget.turn, l))),
                _Action(icon: Icons.ios_share_rounded, tooltip: l.share, onTap: () => shareTurnText(context, widget.turn)),
                _Action(
                  icon: widget.turn.favorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                  tooltip: widget.turn.favorite ? l.unsave : l.save,
                  color: widget.turn.favorite ? AuraHues.pink : null,
                  onTap: () {
                    chats.toggleFavorite(widget.turn);
                    toast(context, widget.turn.favorite ? l.saved : l.unsave);
                  },
                ),
                _Action(
                  icon: Icons.picture_as_pdf_outlined,
                  tooltip: l.export,
                  onTap: () => showExportSheet(context, title: widget.turn.question, turns: [widget.turn], uiLanguage: context.read<SettingsController>().uiLanguage),
                ),
                if (widget.onRetry != null) _Action(icon: Icons.refresh_rounded, tooltip: l.retry, onTap: widget.onRetry!),
                const Spacer(),
                if (r.elapsedMs != null)
                  Text('${(r.elapsedMs! / 1000).toStringAsFixed(1)}s', style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint)),
              ]),
            ),
          ]),
        ),
        if (r.sources.isNotEmpty) ...[
          SectionLabel(l.sources),
          for (final s in r.sources)
            Padding(
              key: _keys[s.n],
              padding: const EdgeInsets.only(bottom: 12),
              child: SourceCard(source: s, highlight: _flash == s.n),
            ),
        ],
        if (r.related.isNotEmpty) ...[
          SectionLabel(l.relatedSources),
          AuraCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(children: [for (final s in r.related.take(5)) _RelatedTile(source: s)]),
          ),
        ],
        if (r.queries.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Icon(Icons.manage_search_rounded, size: 16, color: a.faint),
              for (final q in r.queries) QueryChip(q),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline_rounded, size: 15, color: a.faint),
            const SizedBox(width: 6),
            Expanded(child: Text(l.disclaimer, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint, height: 1.6))),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsetsDirectional.only(end: 4),
        child: AuraIconButton(icon: icon, tooltip: tooltip, onTap: onTap, size: 38, filled: false, color: color ?? context.aura.muted),
      );
}

class QueryChip extends StatelessWidget {
  const QueryChip(this.q, {super.key});
  final String q;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 1),
        decoration: BoxDecoration(gradient: context.aura.soft, borderRadius: BorderRadius.circular(20)),
        child: Text(q, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 13.5, color: context.aura.accent).copyWith(height: 1.7)),
      );
}

class _OpinionTile extends StatelessWidget {
  const _OpinionTile({required this.opinion, required this.color, required this.onCite});
  final Opinion opinion;
  final Color color;
  final ValueChanged<int> onCite;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: a.dark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(18),
        border: BorderDirectional(start: BorderSide(color: color, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(opinion.holder, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w800, color: color))),
          for (final n in opinion.sources) CiteChip(n: n, onTap: onCite),
        ]),
        const SizedBox(height: 4),
        Text(opinion.view, style: TextStyle(fontFamily: uiFont, color: a.text, height: 1.7)),
      ]),
    );
  }
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
    final hue = AuraHues.at(s.n - 1);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.all(highlight ? 2 : 0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: highlight ? a.brand : null),
      child: AuraCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(alignment: Alignment.center, children: [
              BookCover(title: s.bookTitle, seed: s.n + 2, width: 44, height: 56),
              PositionedDirectional(
                top: 0,
                start: 0,
                child: Container(
                  width: 20,
                  height: 20,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: a.surface, shape: BoxShape.circle, border: Border.all(color: hue, width: 1.5)),
                  child: Text('${s.n}', style: TextStyle(fontFamily: uiFont, fontSize: 10.5, fontWeight: FontWeight.w800, color: hue, height: 1.2)),
                ),
              ),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.bookTitle, style: arabicStyle(context, size: 17, scale: scale, weight: FontWeight.w700).copyWith(height: 1.55)),
                  if (s.authorName != null) Text(s.authorName!, style: arabicStyle(context, size: 14.5, scale: scale, color: a.muted).copyWith(height: 1.5)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            if (s.volume != null) _Meta(icon: Icons.layers_outlined, text: '${l.volume} ${s.volume}', color: AuraHues.blue),
            if (s.printedPage != null) _Meta(icon: Icons.description_outlined, text: '${l.page} ${s.printedPage}', color: AuraHues.violet),
            if (s.internalPage != null) _Meta(icon: Icons.tag_rounded, text: '${l.turathPage} ${s.internalPage}', color: AuraHues.cyan),
            if (s.headings.isNotEmpty) _Meta(icon: Icons.segment_rounded, text: s.headings.last, color: AuraHues.amber, arabic: true),
          ]),
          for (final q in s.quotes) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              decoration: BoxDecoration(gradient: a.soft, borderRadius: BorderRadius.circular(20)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  GradientText('❝', style: const TextStyle(fontSize: 26, height: 1)),
                  const Spacer(),
                  Icon(q.exact ? Icons.verified_rounded : Icons.fact_check_rounded, size: 15, color: a.success),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(q.exact ? l.quoteVerified : l.quoteClose,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.success, fontWeight: FontWeight.w600)),
                  ),
                ]),
                SelectableText(q.text, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 18.5, scale: scale)),
                if (q.relevance != null && q.relevance!.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(q.relevance!, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted, height: 1.6))),
              ]),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (s.internalPage != null)
              SoftButton(
                dense: true,
                icon: Icons.chrome_reader_mode_outlined,
                label: l.viewSource,
                onTap: () => openReader(context, s.bookId, s.internalPage!, title: s.bookTitle, highlight: s.quotes.isEmpty ? null : s.quotes.first.text),
              ),
            SoftButton(dense: true, icon: Icons.open_in_new_rounded, label: l.openLink, color: AuraHues.blue, onTap: () => openUrl(s.url)),
            if (s.shamelaUrl != null) SoftButton(dense: true, label: l.openShamela, color: AuraHues.mint, onTap: () => openUrl(s.shamelaUrl!)),
            SoftButton(dense: true, icon: Icons.copy_rounded, label: l.copy, color: a.muted, onTap: () => copyText(context, sourceAsText(s, l))),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, required this.color, this.arabic = false});
  final IconData icon;
  final String text;
  final Color color;
  final bool arabic;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color.withValues(alpha: context.aura.dark ? 0.16 : 0.09), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arabic
                    ? arabicStyle(context, size: 12.5, color: color).copyWith(height: 1.5)
                    : TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ),
        ]),
      );
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.source});
  final AnswerSource source;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: source.internalPage == null ? () => openUrl(source.url) : () => openReader(context, source.bookId, source.internalPage!, title: source.bookTitle),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            BookCover(title: source.bookTitle, seed: source.n, width: 32, height: 42),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(source.bookTitle, textDirection: TextDirection.rtl, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 15, weight: FontWeight.w700).copyWith(height: 1.5)),
                Text(source.citation ?? '', textDirection: TextDirection.rtl, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: context.aura.muted)),
              ]),
            ),
          ]),
        ),
      );
}

/// Live progress while an answer is prepared: breathing orb + step rail.
class StageTimeline extends StatelessWidget {
  const StageTimeline({super.key, required this.progress, this.onCancel});
  final AskProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final steps = [
      (AskStage.planning, l.stagePlanning, Icons.psychology_alt_rounded),
      (AskStage.searching, l.stageSearching, Icons.travel_explore_rounded),
      (AskStage.composing, l.stageComposing, Icons.edit_note_rounded),
      (AskStage.verifying, l.stageVerifying, Icons.fact_check_rounded),
    ];
    final current = progress.stage.index;
    return AuraCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const AuraOrb(size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(steps[current].$2, key: ValueKey(current), style: TextStyle(fontFamily: uiFont, fontSize: 16, fontWeight: FontWeight.w700, color: a.text)),
            ),
          ),
          const TypingDots(size: 7),
        ]),
        const SizedBox(height: 16),
        for (final (i, (stage, label, icon)) in steps.indexed)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 30,
                child: Column(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: stage.index <= current ? a.brand : null,
                      color: stage.index <= current ? null : a.surfaceAlt,
                    ),
                    child: Icon(stage.index < current ? Icons.check_rounded : icon, size: 15, color: stage.index <= current ? Colors.white : a.faint),
                  ),
                  if (i < steps.length - 1)
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(color: stage.index < current ? AuraHues.blue.withValues(alpha: 0.6) : a.border, borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label,
                        style: TextStyle(
                            fontFamily: uiFont,
                            fontSize: 13.5,
                            fontWeight: stage.index == current ? FontWeight.w700 : FontWeight.w500,
                            color: stage.index <= current ? a.text : a.faint)),
                    if (stage == AskStage.searching && progress.queries.isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 6), child: Wrap(spacing: 6, runSpacing: 6, children: [for (final q in progress.queries) QueryChip(q)])),
                    if (stage == AskStage.searching && progress.sourcesFound != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l.foundSources(progress.sourcesFound!), style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
                      ),
                  ]),
                ),
              ),
            ]),
          ),
        if (onCancel != null)
          Align(alignment: AlignmentDirectional.centerEnd, child: SoftButton(dense: true, icon: Icons.stop_rounded, label: l.stop, color: a.danger, onTap: onCancel)),
        const SizedBox(height: 6),
      ]),
    );
  }
}
