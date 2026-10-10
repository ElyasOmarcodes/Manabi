import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/answer.dart';
import '../../core/models/chat.dart';
import '../../state/chat_controller.dart';
import '../home_shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'saved_screen.dart';

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
    final fmt = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm();
    return SafeArea(
      bottom: false,
      child: Column(children: [
        ScreenHeader(icon: Icons.history_rounded, title: l.history),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ReadingWidth(
            child: TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: InputDecoration(hintText: l.searchHistory, prefixIcon: const Icon(Icons.search_rounded)),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? EmptyState(icon: Icons.history_toggle_off_rounded, text: _q.isEmpty ? l.noHistory : l.noResults)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final (Chat chat, ChatTurn turn) = items[i];
                    final status = turn.result?.status;
                    return ReadingWidth(
                      child: ListTile(
                        leading: Icon(
                          turn.state == MessageState.failed
                              ? Icons.error_outline_rounded
                              : status == AnswerStatus.insufficient
                                  ? Icons.search_off_rounded
                                  : Icons.verified_outlined,
                          color: turn.state == MessageState.failed ? context.cs.error : status == AnswerStatus.insufficient ? context.cs.onSurfaceVariant : context.mc.success,
                        ),
                        title: Text(turn.question, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${fmt.format(turn.askedAt)} · ${chat.title}', maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: turn.favorite ? Icon(Icons.bookmark_rounded, color: context.mc.gold, size: 20) : null,
                        onTap: () => openChat(context, chat.id),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
