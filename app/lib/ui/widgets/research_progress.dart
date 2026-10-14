import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/models/answer.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/chat_controller.dart';
import '../theme.dart';
import 'answer_markdown.dart';
import 'common.dart';

/// Compact token count: 950, 1.2k, 18k, 1.3M.
String formatTokens(int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}k';
  if (n < 1000000) return '${(n / 1000).round()}k';
  return '${(n / 1000000).toStringAsFixed(1)}M';
}

/// One line of the research log in the interface language.
String activityText(AppLocalizations l, AskActivityEvent e) {
  final d = e.data;
  int n(String k) => (d[k] as num?)?.toInt() ?? 0;
  List<String> list(String k) => [for (final v in d[k] as List? ?? const []) '$v'];
  return switch (e.kind) {
    'plan' => l.actPlan(list('queries').length),
    'search' => l.actSearch('${d['query'] ?? ''}', d['book'] == null ? '' : l.actIn('${d['book']}'), n('hits')),
    'found' => l.actFound(n('count'), n('total')),
    'rank' => l.actRank(n('pool')),
    'ranked' => l.actRanked(n('selected'), switch (d['coverage']) {
      'full' => l.coverageFull,
      'none' => l.coverageNone,
      _ => l.coveragePartial,
    }),
    'followup' => l.actFollowup([...list('queries'), ...list('books')].join('، ')),
    'chapter' => l.actChapter('${d['book'] ?? ''}', '${d['chapter'] ?? ''}', '${n('pages')}'),
    'expand' => l.actExpand('${d['book'] ?? ''}', '${d['chapter'] ?? d['book'] ?? ''}', '${n('pages')}'),
    'web' => l.actWeb(list('books').join('، ')),
    'read' => l.actRead(n('pages'), list('books').length),
    'compose' => l.actCompose(n('sources')),
    'verify' => l.actVerify,
    'resumed' => l.actResumed,
    'retry' => l.actRetry(n('attempt')),
    _ => e.kind,
  };
}

/// The research log as shown: a run of searches is one step, the bare
/// "ranking" notes are left out (their results are a step of their own).
List<({String kind, String text, int ms})> researchSteps(AppLocalizations l, List<AskActivityEvent> events) {
  final out = <({String kind, String text, int ms})>[];
  for (var i = 0; i < events.length; i++) {
    final e = events[i];
    final emptyFollowup = e.kind == 'followup' && (e.data['queries'] as List? ?? const []).isEmpty && (e.data['books'] as List? ?? const []).isEmpty;
    if (e.kind == 'rank' || emptyFollowup) continue;
    if (e.kind == 'search') {
      final queries = <String>{};
      var j = i;
      for (; j < events.length && events[j].kind == 'search'; j++) {
        queries.add('${events[j].data['query'] ?? ''}'.trim());
      }
      final shown = queries.where((q) => q.isNotEmpty).take(4).join('، ');
      out.add((
        kind: 'search',
        text: j - i == 1 ? activityText(l, e) : l.actSearches('${j - i}', queries.length > 4 ? '$shown …' : shown),
        ms: events[j - 1].elapsedMs,
      ));
      i = j - 1;
      continue;
    }
    out.add((kind: e.kind, text: activityText(l, e), ms: e.elapsedMs));
  }
  return out;
}

/// Removes citation markers from an unfinished answer.
String cleanDraft(String text) => text
    .replaceAll(RegExp(r'\[\[\s*Q\d+\s*\]\]'), '')
    .replaceAll(RegExp(r'\[\s*S\d+(?:\s*[,،;]\s*S?\d+)*\s*\]', caseSensitive: false), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// The assistant's mark: the brand gradient with a spark. While [busy] the
/// ring turns slowly.
class AssistantMark extends StatefulWidget {
  const AssistantMark({super.key, this.busy = false, this.size = 26});
  final bool busy;
  final double size;
  @override
  State<AssistantMark> createState() => _AssistantMarkState();
}

class _AssistantMarkState extends State<AssistantMark> with SingleTickerProviderStateMixin {
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.busy) _turn.repeat();
  }

  @override
  void didUpdateWidget(AssistantMark old) {
    super.didUpdateWidget(old);
    if (widget.busy && !_turn.isAnimating) _turn.repeat();
    if (!widget.busy && _turn.isAnimating) _turn.animateTo(1, duration: const Duration(milliseconds: 500), curve: Curves.easeOut).then((_) => _turn.value = 0);
  }

  @override
  void dispose() {
    _turn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final s = widget.size;
    return AnimatedBuilder(
      animation: _turn,
      builder: (context, _) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: SweepGradient(transform: GradientRotation(_turn.value * 6.2832), colors: [AuraHues.violet, AuraHues.amber, AuraHues.violet]),
        ),
        padding: EdgeInsets.all(s * 0.085),
        child: Container(
          decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle),
          child: Icon(Icons.auto_awesome_rounded, size: s * 0.52, color: a.accent),
        ),
      ),
    );
  }
}

/// Text with a soft light passing over it in the reading direction, the way
/// assistants show that they are working on something.
class ShimmerText extends StatefulWidget {
  const ShimmerText(this.text, {super.key, required this.style, this.active = true, this.maxLines = 2});
  final String text;
  final TextStyle style;
  final bool active;
  final int maxLines;
  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final text = Text(
      widget.text,
      maxLines: widget.maxLines,
      overflow: TextOverflow.ellipsis,
      style: widget.style.copyWith(color: a.muted),
    );
    if (!widget.active) return text;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _c,
      child: text,
      builder: (context, child) {
        // The light crosses in the first two thirds of the cycle, then rests.
        final t = Curves.easeInOutSine.transform((_c.value / 0.68).clamp(0.0, 1.0));
        final pos = -0.35 + t * 1.7;
        final c = rtl ? 1 - pos : pos;
        const w = 0.22;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (r) => LinearGradient(
            colors: [a.muted, a.muted, a.text, a.muted, a.muted],
            stops: [0, (c - w).clamp(0.0, 1.0), c.clamp(0.0, 1.0), (c + w).clamp(0.0, 1.0), 1],
          ).createShader(Offset.zero & r.size),
          child: child,
        );
      },
    );
  }
}

/// A chevron that points to where the line leads (the end of the line in
/// the reading direction) and turns down when its panel is open.
class FoldChevron extends StatelessWidget {
  const FoldChevron({super.key, required this.open, this.size = 18, this.color});
  final bool open;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedRotation(
      turns: open ? 0 : (rtl ? 0.25 : -0.25),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      child: Icon(Icons.keyboard_arrow_down_rounded, size: size, color: color ?? context.aura.faint),
    );
  }
}

/// The steps of the research, one under the other on a thin thread; the
/// latest one glows while the research runs.
class ResearchTimeline extends StatelessWidget {
  const ResearchTimeline({super.key, required this.events, this.usage = const TokenUsage(), this.live = false});
  final List<AskActivityEvent> events;
  final TokenUsage usage;
  final bool live;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final steps = researchSteps(l, events);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 4, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, s) in steps.indexed)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 14,
                    child: Column(
                      children: [
                        Container(width: 1.2, height: 7, color: i == 0 ? Colors.transparent : a.border),
                        _Dot(color: s.kind == 'retry' ? a.danger : (live && i == steps.length - 1 ? a.accent : a.faint), glow: live && i == steps.length - 1),
                        Expanded(child: Container(width: 1.2, color: i == steps.length - 1 ? Colors.transparent : a.border)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text(
                        s.text,
                        style: TextStyle(fontFamily: uiFont, fontSize: 12.8, height: 1.55, color: live && i == steps.length - 1 ? a.text : a.muted),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${(s.ms / 1000).toStringAsFixed(1)}s',
                      style: TextStyle(fontFamily: uiFont, fontSize: 10.5, color: a.faint, fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                ],
              ),
            ),
          if (!usage.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 24, top: 6),
              child: Text(
                '${l.tokenUsage}: ${l.tokensInput} ${formatTokens(usage.input)} · ${l.tokensOutput} ${formatTokens(usage.output)}'
                '${usage.thoughts > 0 ? ' · ${l.tokensThinking} ${formatTokens(usage.thoughts)}' : ''}',
                style: TextStyle(fontFamily: uiFont, fontSize: 11, color: a.faint),
              ),
            ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, this.glow = false});
  final Color color;
  final bool glow;
  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: glow ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6, spreadRadius: 1)] : const [],
    ),
  );
}

/// Opens and closes a panel under a line, softly.
class _Fold extends StatelessWidget {
  const _Fold({required this.open, required this.child});
  final bool open;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
    alignment: AlignmentDirectional.topStart,
    child: AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: open ? KeyedSubtree(key: const ValueKey(1), child: child) : const SizedBox(key: ValueKey(0), width: double.infinity),
    ),
  );
}

/// Live research: one sentence on what is being done, with a light passing
/// over it and a chevron at its end; a tap shows every step done so far.
/// Then the answer as it is being written.
class ResearchProgress extends StatefulWidget {
  const ResearchProgress({super.key, required this.progress, this.rtlDraft = false});
  final AskProgress progress;
  final bool rtlDraft;
  @override
  State<ResearchProgress> createState() => _ResearchProgressState();
}

class _ResearchProgressState extends State<ResearchProgress> {
  // Redraws the reconnect countdown.
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) {
    if (widget.progress.retryIn != null) setState(() {});
  });
  bool _open = false;

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  String _stageText(AppLocalizations l, AskStage s) => switch (s) {
    AskStage.planning => l.stagePlanning,
    AskStage.searching => l.stageSearching,
    AskStage.reading => l.stageReading,
    AskStage.composing => l.stageComposing,
    AskStage.verifying => l.stageVerifying,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final p = widget.progress;
    final shown = p.activity.where((e) => e.kind != 'rank').lastOrNull;
    final headline = p.retryIn != null && shown?.kind == 'retry'
        ? l.reconnectingIn(p.retryIn!)
        : shown == null || shown.kind == 'verify' || shown.kind == 'compose'
        ? _stageText(l, p.stage)
        : activityText(l, shown);
    final draft = p.draft == null ? '' : cleanDraft(p.draft!);
    final style = TextStyle(fontFamily: uiFont, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: l.researchSteps,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: context.aura.border.withValues(alpha: 0.35),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const AssistantMark(busy: true),
                  const SizedBox(width: 10),
                  Flexible(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(0, 0.35), end: Offset.zero).animate(anim),
                          child: child,
                        ),
                      ),
                      layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                      child: ShimmerText(headline, key: ValueKey(headline), style: style),
                    ),
                  ),
                  const SizedBox(width: 2),
                  FoldChevron(open: _open),
                ],
              ),
            ),
          ),
        ),
        _Fold(
          open: _open,
          child: ResearchTimeline(events: p.activity, usage: p.usage, live: true),
        ),
        if (draft.isNotEmpty) ...[
          const SizedBox(height: 10),
          Directionality(
            textDirection: widget.rtlDraft ? TextDirection.rtl : TextDirection.ltr,
            child: AnimatedOpacity(
              opacity: 0.9,
              duration: const Duration(milliseconds: 200),
              child: AnswerMarkdown(markdown: '$draft ▍', onCite: (_) {}),
            ),
          ),
        ],
      ],
    );
  }
}

/// Above a finished answer: the mark, the name, how long the research took
/// (a chevron at its end), and on a tap every step it went through.
class ResearchSummary extends StatefulWidget {
  const ResearchSummary({super.key, required this.steps, required this.result, this.trailing});
  final List<AskActivityEvent> steps;
  final AnswerResult result;
  final Widget? trailing;
  @override
  State<ResearchSummary> createState() => _ResearchSummaryState();
}

class _ResearchSummaryState extends State<ResearchSummary> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final r = widget.result;
    final ms = r.elapsedMs ?? widget.steps.lastOrNull?.elapsedMs;
    final researched = r.sources.isNotEmpty || widget.steps.length > 2;
    final books = {for (final s in r.sources) s.bookTitle}.length;
    final detail = [if (ms != null && researched) l.researchedFor('${(ms / 1000).round()}'), if (books > 0) l.sourceCount(r.sources.length)].join(' · ');
    final canOpen = widget.steps.isNotEmpty;
    final line = Row(
      children: [
        const AssistantMark(),
        const SizedBox(width: 9),
        Text(
          l.appName,
          style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w700, color: a.text),
        ),
        if (detail.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted),
            ),
          ),
        ],
        if (canOpen) FoldChevron(open: _open, size: 17),
        const Spacer(),
        ?widget.trailing,
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!canOpen)
          line
        else
          Semantics(
            button: true,
            label: l.researchSteps,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: a.border.withValues(alpha: 0.35),
              onTap: () => setState(() => _open = !_open),
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: line),
            ),
          ),
        if (canOpen)
          _Fold(
            open: _open,
            child: ResearchTimeline(events: widget.steps, usage: r.usage),
          ),
      ],
    );
  }
}
