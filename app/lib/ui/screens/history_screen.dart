import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/answer.dart';
import '../../core/models/chat.dart';
import '../../state/chat_controller.dart';
import '../home_shell.dart';
import '../theme.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final items = context.watch<ChatController>().searchHistory(_q);
    final l = context.l;
    final a = context.aura;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final day = DateFormat.yMMMMd(locale);
    final time = DateFormat.Hm(locale);

    // Group by calendar day for a timeline look.
    final groups = <String, List<(Chat, ChatTurn)>>{};
    for (final it in items) {
      groups.putIfAbsent(day.format(it.$2.askedAt), () => []).add(it);
    }

    return AuraPage(
      title: Text(l.history, style: TextStyle(fontFamily: uiFont, fontSize: 20, fontWeight: FontWeight.w800, color: context.aura.text)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: ReadingWidth(child: AuraSearchField(hint: l.searchHistory, onChanged: (v) => setState(() => _q = v))),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(icon: Icons.history_toggle_off_rounded, text: _q.isEmpty ? l.noHistory : l.noResults, color: AuraHues.amber)
              : ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.paddingOf(context).bottom + 24), children: [
                  for (final e in groups.entries)
                    ReadingWidth(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        SectionLabel(e.key),
                        AuraCard(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(children: [
                            for (final (chat, turn) in e.value)
                              InkWell(
                                onTap: () => openChat(context, chat.id),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  child: Row(children: [
                                    _StatusDot(turn: turn),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(turn.question, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, color: a.text, height: 1.5)),
                                        Text('${time.format(turn.askedAt)} · ${chat.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint)),
                                      ]),
                                    ),
                                    if (turn.favorite) const Icon(Icons.bookmark_rounded, color: AuraHues.pink, size: 19),
                                  ]),
                                ),
                              ),
                          ]),
                        ),
                      ]),
                    ),
                ]),
        ),
      ]),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.turn});
  final ChatTurn turn;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final (icon, color) = turn.state == MessageState.failed
        ? (Icons.priority_high_rounded, a.danger)
        : turn.result?.status == AnswerStatus.insufficient
            ? (Icons.search_off_rounded, a.muted)
            : (Icons.check_rounded, a.success);
    return IconTile(icon: icon, color: color, size: 36);
  }
}
