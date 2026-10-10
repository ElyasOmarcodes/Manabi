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
    Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic, alignment: 0.15);
    setState(() => _flash = n);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _flash = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.turn.result!;
    final l = context.l;
    final rtl = isRtlLanguage(r.language);
    final chats = context.read<ChatController>();
    for (final s in r.sources) {
      _keys.putIfAbsent(s.n, GlobalKey.new);
    }
    return Directionality(
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      child: SoftCard(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            StatusPill(status: r.status),
            const Spacer(),
            if (r.sources.isNotEmpty)
              Text(l.sourceCount(r.sources.length), style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 14),
          AnswerMarkdown(markdown: r.answer, onCite: _jumpTo),
          if (r.detail.isNotEmpty && !r.isDocumented) ...[
            const SizedBox(height: 4),
            Text(r.detail, style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
          ],
          if (r.opinions.isNotEmpty) ...[
            SectionTitle(l.opinions),
            for (final o in r.opinions) _OpinionTile(opinion: o, onCite: _jumpTo),
          ],
          if (r.notes.isNotEmpty) ...[
            SectionTitle(l.notes),
            Text(r.notes, style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
          ],
          if (r.sources.isNotEmpty) ...[
            SectionTitle(l.sources),
            for (final s in r.sources)
              Padding(
                key: _keys[s.n],
                padding: const EdgeInsets.only(bottom: 10),
                child: SourceCard(source: s, highlight: _flash == s.n),
              ),
          ],
          if (r.related.isNotEmpty) ...[
            SectionTitle(l.relatedSources),
            for (final s in r.related.take(5)) _RelatedTile(source: s),
          ],
          if (r.queries.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${l.searchedFor}:', style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
              for (final q in r.queries) _QueryChip(q),
            ]),
          ],
          const SizedBox(height: 10),
          Text(l.disclaimer, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant, height: 1.6)),
          const Divider(height: 22),
          Row(children: [
            _Action(icon: Icons.copy_rounded, tooltip: l.copy, onTap: () => copyText(context, answerAsText(widget.turn, l))),
            _Action(icon: Icons.ios_share_rounded, tooltip: l.share, onTap: () => shareTurnText(context, widget.turn)),
            _Action(
              icon: widget.turn.favorite ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
              tooltip: widget.turn.favorite ? l.unsave : l.save,
              color: widget.turn.favorite ? context.mc.gold : null,
              onTap: () {
                chats.toggleFavorite(widget.turn);
                toast(context, widget.turn.favorite ? l.saved : l.unsave);
              },
            ),
            _Action(
              icon: Icons.file_download_outlined,
              tooltip: l.export,
              onTap: () => showExportSheet(context, title: widget.turn.question, turns: [widget.turn], uiLanguage: context.read<SettingsController>().uiLanguage),
            ),
            if (widget.onRetry != null) _Action(icon: Icons.refresh_rounded, tooltip: l.retry, onTap: widget.onRetry!),
            const Spacer(),
            if (r.elapsedMs != null)
              Text('${(r.elapsedMs! / 1000).toStringAsFixed(1)}s', style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
          ]),
        ]),
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
    final (color, icon, text) = switch (status) {
      AnswerStatus.answered => (context.mc.success, Icons.verified_rounded, l.statusAnswered),
      AnswerStatus.partial => (context.mc.warning, Icons.rule_rounded, l.statusPartial),
      AnswerStatus.insufficient => (context.cs.onSurfaceVariant, Icons.search_off_rounded, l.statusInsufficient),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(30)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13)),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.tooltip, required this.onTap, this.color});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) =>
      IconButton(onPressed: onTap, tooltip: tooltip, icon: Icon(icon, size: 20, color: color ?? context.cs.onSurfaceVariant), visualDensity: VisualDensity.compact);
}

class _QueryChip extends StatelessWidget {
  const _QueryChip(this.q);
  final String q;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: context.cs.surfaceContainer, borderRadius: BorderRadius.circular(20)),
        child: Text(q, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 14).copyWith(height: 1.6, color: context.cs.onSurfaceVariant)),
      );
}

class _OpinionTile extends StatelessWidget {
  const _OpinionTile({required this.opinion, required this.onCite});
  final Opinion opinion;
  final ValueChanged<int> onCite;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.mc.glow, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(opinion.holder, style: const TextStyle(fontWeight: FontWeight.w700))),
            for (final n in opinion.sources) CiteChip(n: n, onTap: onCite),
          ]),
          const SizedBox(height: 4),
          Text(opinion.view, style: context.tt.bodyMedium),
        ]),
      );
}

/// One numbered source with metadata, verified Arabic quote and links.
class SourceCard extends StatelessWidget {
  const SourceCard({super.key, required this.source, this.highlight = false});
  final AnswerSource source;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final scale = context.watch<SettingsController>().arabicScale;
    final s = source;
    final location = [
      if (s.volume != null) '${l.volume} ${s.volume}',
      if (s.printedPage != null) '${l.page} ${s.printedPage}',
    ].join(' · ');
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: highlight ? context.mc.gold.withValues(alpha: 0.14) : context.cs.surfaceContainerLow,
        border: Border.all(color: highlight ? context.mc.gold : context.cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: context.mc.gold.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Text('${s.n}', style: TextStyle(color: context.mc.gold, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.bookTitle, style: arabicStyle(context, size: 17, scale: scale, weight: FontWeight.w700).copyWith(height: 1.6)),
                if (s.authorName != null) Text(s.authorName!, style: arabicStyle(context, size: 15, scale: scale).copyWith(height: 1.5, color: context.cs.onSurfaceVariant)),
              ]),
            ),
          ),
        ]),
        if (location.isNotEmpty || s.headings.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              if (location.isNotEmpty) _MetaChip(icon: Icons.bookmark_border_rounded, text: location),
              if (s.internalPage != null) _MetaChip(icon: Icons.tag_rounded, text: '${l.turathPage} ${s.internalPage}'),
              if (s.headings.isNotEmpty) _MetaChip(icon: Icons.segment_rounded, text: s.headings.last, arabic: true),
            ]),
          ),
        for (final q in s.quotes) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: context.mc.quoteBg,
              borderRadius: BorderRadius.circular(14),
              border: BorderDirectional(start: BorderSide(color: context.mc.gold, width: 3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SelectableText(q.text, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 18, scale: scale)),
              const SizedBox(height: 4),
              Row(children: [
                Icon(q.exact ? Icons.verified_rounded : Icons.fact_check_outlined, size: 14, color: context.mc.success),
                const SizedBox(width: 4),
                Expanded(child: Text(q.exact ? l.quoteVerified : l.quoteClose, style: context.tt.labelSmall?.copyWith(color: context.mc.success))),
              ]),
              if (q.relevance != null && q.relevance!.isNotEmpty)
                Padding(padding: const EdgeInsets.only(top: 4), child: Text(q.relevance!, style: context.tt.bodySmall?.copyWith(color: context.cs.onSurfaceVariant))),
            ]),
          ),
        ],
        const SizedBox(height: 4),
        Wrap(spacing: 0, children: [
          if (s.internalPage != null)
            TextButton.icon(
              onPressed: () => openReader(context, s.bookId, s.internalPage!, title: s.bookTitle, highlight: s.quotes.isEmpty ? null : s.quotes.first.text),
              icon: const Icon(Icons.chrome_reader_mode_outlined, size: 18),
              label: Text(l.viewSource),
            ),
          TextButton.icon(onPressed: () => openUrl(s.url), icon: const Icon(Icons.open_in_new_rounded, size: 18), label: Text(l.openLink)),
          if (s.shamelaUrl != null) TextButton(onPressed: () => openUrl(s.shamelaUrl!), child: Text(l.openShamela)),
          IconButton(
            tooltip: l.copy,
            visualDensity: VisualDensity.compact,
            onPressed: () => copyText(context, sourceAsText(s, l)),
            icon: Icon(Icons.copy_rounded, size: 18, color: context.cs.onSurfaceVariant),
          ),
        ]),
      ]),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text, this.arabic = false});
  final IconData icon;
  final String text;
  final bool arabic;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(color: context.cs.surfaceContainerLowest, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.cs.outlineVariant.withValues(alpha: 0.6))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: context.cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: arabic ? arabicStyle(context, size: 13).copyWith(height: 1.5, color: context.cs.onSurfaceVariant) : context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
          ),
        ]),
      );
}

class _RelatedTile extends StatelessWidget {
  const _RelatedTile({required this.source});
  final AnswerSource source;
  @override
  Widget build(BuildContext context) => ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.description_outlined, size: 20, color: context.cs.onSurfaceVariant),
        title: Text(source.bookTitle, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15).copyWith(height: 1.5)),
        subtitle: Text(source.citation ?? '', textDirection: TextDirection.rtl, maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: source.internalPage == null ? () => openUrl(source.url) : () => openReader(context, source.bookId, source.internalPage!, title: source.bookTitle),
      );
}

/// Animated multi-step progress while an answer is prepared.
class StageTimeline extends StatelessWidget {
  const StageTimeline({super.key, required this.progress, this.onCancel});
  final AskProgress progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final steps = [
      (AskStage.planning, l.stagePlanning, Icons.psychology_alt_outlined),
      (AskStage.searching, l.stageSearching, Icons.manage_search_rounded),
      (AskStage.composing, l.stageComposing, Icons.edit_note_rounded),
      (AskStage.verifying, l.stageVerifying, Icons.fact_check_outlined),
    ];
    final current = progress.stage.index;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final (stage, label, icon) in steps)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: stage.index <= current ? 1 : 0.38,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                SizedBox(
                  width: 26,
                  height: 26,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: stage.index < current
                        ? Icon(Icons.check_circle_rounded, key: const ValueKey('done'), color: context.mc.success, size: 22)
                        : stage.index == current
                            ? Padding(key: const ValueKey('run'), padding: const EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2.4, color: context.cs.primary))
                            : Icon(icon, key: const ValueKey('todo'), size: 20, color: context.cs.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: TextStyle(fontWeight: stage.index == current ? FontWeight.w600 : FontWeight.w400)),
                    if (stage == AskStage.searching && progress.queries.isNotEmpty && current >= AskStage.searching.index)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Wrap(spacing: 6, runSpacing: 6, children: [for (final q in progress.queries) _QueryChip(q)]),
                      ),
                    if (stage == AskStage.searching && progress.sourcesFound != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(l.foundSources(progress.sourcesFound!), style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
        if (onCancel != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(onPressed: onCancel, icon: const Icon(Icons.stop_circle_outlined, size: 18), label: Text(l.stop)),
          ),
      ]),
    );
  }
}
