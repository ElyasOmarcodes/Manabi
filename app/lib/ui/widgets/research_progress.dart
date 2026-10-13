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
    'ranked' => l.actRanked(n('selected'), switch (d['coverage']) { 'full' => l.coverageFull, 'none' => l.coverageNone, _ => l.coveragePartial }),
    'followup' => l.actFollowup([...list('queries'), ...list('books')].join('، ')),
    'chapter' => l.actChapter('${d['book'] ?? ''}', '${d['chapter'] ?? ''}', '${n('pages')}'),
    'read' => l.actRead(n('pages'), list('books').length),
    'compose' => l.actCompose(n('sources')),
    'verify' => l.actVerify,
    'resumed' => l.actResumed,
    'retry' => l.actRetry(n('attempt')),
    _ => e.kind,
  };
}

IconData _icon(String kind) => switch (kind) {
      'plan' => Icons.route_rounded,
      'search' => Icons.manage_search_rounded,
      'found' => Icons.library_books_outlined,
      'rank' || 'ranked' => Icons.fact_check_outlined,
      'followup' => Icons.travel_explore_rounded,
      'read' => Icons.chrome_reader_mode_outlined,
      'chapter' => Icons.menu_book_rounded,
      'compose' => Icons.edit_note_rounded,
      'verify' => Icons.verified_outlined,
      'retry' => Icons.wifi_tethering_error_rounded,
      'resumed' => Icons.replay_rounded,
      _ => Icons.circle_outlined,
    };

/// Removes citation markers from an unfinished answer.
String cleanDraft(String text) => text
    .replaceAll(RegExp(r'\[\[\s*Q\d+\s*\]\]'), '')
    .replaceAll(RegExp(r'\[\s*S\d+(?:\s*[,،;]\s*S?\d+)*\s*\]', caseSensitive: false), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

/// Live research progress: the current step with a running timer, a step
/// bar, an expandable log of everything done so far, and the answer draft
/// while it is being written.
class ResearchProgress extends StatefulWidget {
  const ResearchProgress({super.key, required this.progress, this.rtlDraft = false});
  final AskProgress progress;
  final bool rtlDraft;
  @override
  State<ResearchProgress> createState() => _ResearchProgressState();
}

class _ResearchProgressState extends State<ResearchProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  late final Timer _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  bool _open = false;

  @override
  void dispose() {
    _tick.cancel();
    _shine.dispose();
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
    final a = context.aura;
    final p = widget.progress;
    final seconds = DateTime.now().difference(p.startedAt).inSeconds;
    final last = p.activity.lastOrNull;
    final headline = p.retryIn != null && last?.kind == 'retry'
        ? l.reconnectingIn(p.retryIn!)
        : last == null || last.kind == 'verify'
            ? _stageText(l, p.stage)
            : activityText(l, last);
    final draft = p.draft == null ? '' : cleanDraft(p.draft!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              _Orb(animation: _shine),
              const SizedBox(width: 10),
              Expanded(
                child: AnimatedBuilder(
                  animation: _shine,
                  builder: (context, child) => ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => LinearGradient(
                      colors: [a.muted, a.text, a.muted],
                      stops: [(_shine.value - 0.25).clamp(0, 1), _shine.value, (_shine.value + 0.25).clamp(0, 1)],
                    ).createShader(Offset.zero & r.size),
                    child: child,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                    child: Text(headline,
                        key: ValueKey(headline),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: uiFont, fontSize: 14.5, fontWeight: FontWeight.w600, height: 1.45)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${seconds}s', style: TextStyle(fontFamily: uiFont, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()], color: a.faint)),
              Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 20, color: a.faint),
            ]),
            const SizedBox(height: 8),
            _StepBar(stage: p.stage, animation: _shine),
          ]),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: !_open
            ? const SizedBox(width: double.infinity)
            : Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  if (p.activity.isEmpty)
                    Text(_stageText(l, p.stage), style: TextStyle(fontFamily: uiFont, fontSize: 13, color: a.muted))
                  else
                    for (final e in p.activity)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Padding(padding: const EdgeInsets.only(top: 2), child: Icon(_icon(e.kind), size: 15, color: e.kind == 'retry' ? a.danger : a.accent)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(activityText(l, e), style: TextStyle(fontFamily: uiFont, fontSize: 12.5, height: 1.5, color: a.text))),
                          const SizedBox(width: 8),
                          Text('${(e.elapsedMs / 1000).toStringAsFixed(1)}s', style: TextStyle(fontFamily: uiFont, fontSize: 11, color: a.faint)),
                        ]),
                      ),
                  if (!p.usage.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '${l.tokenUsage}: ${l.tokensInput} ${formatTokens(p.usage.input)} · ${l.tokensOutput} ${formatTokens(p.usage.output)}'
                        '${p.usage.thoughts > 0 ? ' · ${l.tokensThinking} ${formatTokens(p.usage.thoughts)}' : ''}',
                        style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted),
                      ),
                    ),
                ]),
              ),
      ),
      if (draft.isNotEmpty) ...[
        const SizedBox(height: 10),
        Directionality(
          textDirection: widget.rtlDraft ? TextDirection.rtl : TextDirection.ltr,
          child: Opacity(opacity: 0.88, child: AnswerMarkdown(markdown: '$draft ▍', onCite: (_) {})),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(children: [
            Icon(Icons.hourglass_top_rounded, size: 13, color: a.faint),
            const SizedBox(width: 4),
            Flexible(child: Text(l.writingDraft, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.faint))),
          ]),
        ),
      ],
    ]);
  }
}

/// A small brand orb that breathes while the research runs.
class _Orb extends StatelessWidget {
  const _Orb({required this.animation});
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = animation.value;
        return Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(transform: GradientRotation(t * 6.283), colors: [AuraHues.violet, AuraHues.amber, AuraHues.violet]),
          ),
          padding: const EdgeInsets.all(2.2),
          child: Container(
            decoration: BoxDecoration(color: a.bg, shape: BoxShape.circle),
            child: Icon(Icons.auto_awesome_rounded, size: 13, color: a.accent),
          ),
        );
      },
    );
  }
}

/// One slim track for the five stages: the fill glides to the current stage
/// (halfway into it) in the reading direction, and a soft glowing head with a
/// light sweeping toward it shows that work goes on.
class _StepBar extends StatelessWidget {
  const _StepBar({required this.stage, required this.animation});
  final AskStage stage;
  final Animation<double> animation;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final dir = Directionality.of(context);
    final target = (stage.index + 0.5) / AskStage.values.length;
    return SizedBox(
      height: 10,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: target),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, f, _) => LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final fill = w * f;
            return Stack(
              clipBehavior: Clip.none,
              alignment: AlignmentDirectional.centerStart,
              children: [
                Container(
                  height: 3,
                  decoration: BoxDecoration(color: a.border.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(3)),
                ),
                PositionedDirectional(
                  start: 0,
                  width: fill,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final t = animation.value;
                      return Container(
                        height: 3,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          gradient: LinearGradient(
                            begin: AlignmentDirectional.centerStart.resolve(dir),
                            end: AlignmentDirectional.centerEnd.resolve(dir),
                            colors: [a.accent.withValues(alpha: 0.55), a.accent, Colors.white.withValues(alpha: 0.9), a.accent],
                            stops: [0, (t - 0.12).clamp(0.0, 1.0), t, (t + 0.12).clamp(0.0, 1.0)],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                PositionedDirectional(
                  start: fill - 5,
                  child: AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) {
                      final pulse = 0.5 + 0.5 * (1 - (animation.value * 2 - 1).abs());
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: a.accent,
                          boxShadow: [
                            BoxShadow(
                              color: a.accent.withValues(alpha: 0.25 + 0.35 * pulse),
                              blurRadius: 6 + 6 * pulse,
                              spreadRadius: 1 + pulse,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
