import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/answer.dart';
import '../../core/models/chat.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/chat_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../export/export_actions.dart';
import '../export/exporter.dart';
import '../theme.dart';
import 'common.dart';
import 'research_progress.dart' show formatTokens;

/// Gemini Flash models read up to about a million tokens per request.
const contextLimit = 1048576;

TokenUsage chatUsage(Chat chat) => chat.turns.fold(const TokenUsage(), (sum, t) => sum + (t.result?.usage ?? const TokenUsage()));

/// Long-press menu of a question or an answer: actions plus the tokens the
/// answer used and the chat's running total.
Future<void> showMessageSheet(BuildContext context, {required Chat chat, required ChatTurn turn, required bool question}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MessageSheet(chat: chat, turn: turn, question: question),
    );

/// Totals for a whole chat (opened from the chat title).
Future<void> showChatDetails(BuildContext context, Chat chat) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(context.l.chatDetails, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: context.aura.text)),
            const SizedBox(height: 4),
            Text(chat.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 13, color: context.aura.muted)),
            const SizedBox(height: 12),
            _ChatTotals(chat: chat),
          ]),
        ),
      ),
    );

class _MessageSheet extends StatelessWidget {
  const _MessageSheet({required this.chat, required this.turn, required this.question});
  final Chat chat;
  final ChatTurn turn;
  final bool question;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final chats = context.read<ChatController>();
    final settings = context.read<SettingsController>();
    final r = turn.result;
    void close() => Navigator.of(context).pop();
    Widget action(IconData icon, String label, VoidCallback onTap) => ListTile(
          dense: true,
          leading: Icon(icon, size: 21, color: a.text),
          title: Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 14.5, color: a.text)),
          onTap: () {
            close();
            onTap();
          },
        );
    final preview = question ? turn.question : (r?.answer ?? '');
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.92,
      builder: (context, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(14)),
          child: Text(preview.trim(), maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, height: 1.6, color: a.text)),
        ),
        const SizedBox(height: 6),
        if (question) ...[
          action(Icons.copy_rounded, l.copyQuestion, () => copyText(context, turn.question)),
          action(Icons.edit_note_rounded, l.askAgain, () => context.read<NavController>().prefill(turn.question)),
        ] else if (r != null) ...[
          action(Icons.copy_rounded, l.copy, () => copyText(context, answerAsText(turn, l))),
          action(Icons.ios_share_rounded, l.share, () => shareTurnText(context, turn)),
          action(turn.favorite ? Icons.bookmark_remove_outlined : Icons.bookmark_add_outlined, turn.favorite ? l.unsave : l.save, () => chats.toggleFavorite(turn)),
          action(Icons.picture_as_pdf_outlined, l.export, () => showExportSheet(context, title: turn.question, turns: [turn], uiLanguage: settings.uiLanguage)),
        ],
        action(Icons.refresh_rounded, l.retry, () => chats.retry(turn, fallbackLanguage: settings.uiLanguage, depth: settings.researchDepth)),
        const Divider(height: 24),
        _Heading(question ? l.thisQuestion : l.thisAnswer),
        if (r == null || r.usage.isEmpty)
          Text(l.noUsageYet, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, color: a.muted))
        else
          _UsageGrid(usage: r.usage, extra: [
            if (r.elapsedMs != null) (l.answerTime, '${(r.elapsedMs! / 1000).toStringAsFixed(1)}s'),
            if (r.model != null) ('Model', r.model!),
          ]),
        const SizedBox(height: 16),
        _Heading(l.thisChat),
        _ChatTotals(chat: chat),
      ]),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w700, color: context.aura.muted)),
      );
}

class _ChatTotals extends StatelessWidget {
  const _ChatTotals({required this.chat});
  final Chat chat;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final total = chatUsage(chat);
    final share = (total.peak / contextLimit).clamp(0.0, 1.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _UsageGrid(usage: total, extra: [(l.questionsCount, '${chat.turns.length}')]),
      const SizedBox(height: 12),
      Text(l.contextWindow, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.text)),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: share == 0 ? 0 : share.clamp(0.01, 1.0), minHeight: 6, backgroundColor: a.border, color: a.accent),
      ),
      const SizedBox(height: 4),
      Text(l.contextWindowInfo(formatTokens(total.peak), formatTokens(contextLimit)), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
    ]);
  }
}

/// Input / output / thinking / total / calls tiles.
class _UsageGrid extends StatelessWidget {
  const _UsageGrid({required this.usage, this.extra = const []});
  final TokenUsage usage;
  final List<(String, String)> extra;
  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l;
    final a = context.aura;
    final cells = [
      (l.tokensInput, formatTokens(usage.input)),
      (l.tokensOutput, formatTokens(usage.output)),
      if (usage.thoughts > 0) (l.tokensThinking, formatTokens(usage.thoughts)),
      (l.tokensTotal, formatTokens(usage.total)),
      (l.modelCalls, '${usage.calls}'),
      ...extra,
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (label, value) in cells)
        Container(
          constraints: const BoxConstraints(minWidth: 96),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: a.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: a.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w800, color: a.accent)),
            Text(label, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
          ]),
        ),
    ]);
  }
}
