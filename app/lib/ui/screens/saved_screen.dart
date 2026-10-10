import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/chat.dart';
import '../../state/chat_controller.dart';
import '../home_shell.dart';
import '../theme.dart';
import '../widgets/answer_card.dart';
import '../widgets/common.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<ChatController>().favorites;
    final l = context.l;
    return AuraPage(
      titleText: l.navFavorites,
      body: favorites.isEmpty
              ? EmptyState(icon: Icons.bookmark_add_outlined, text: l.noFavorites, color: AuraHues.pink)
              : ListView.builder(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 24),
                  itemCount: favorites.length,
                  itemBuilder: (context, i) {
                    final (chat, turn) = favorites[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: ReadingWidth(child: Reveal(delay: (i % 8) * 50, child: _SavedTile(chat: chat, turn: turn, color: AuraHues.rose))),
                    );
                  },
                ),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.chat, required this.turn, required this.color});
  final Chat chat;
  final ChatTurn turn;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final r = turn.result;
    final a = context.aura;
    return AuraCard(
      padding: EdgeInsets.zero,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SavedDetail(chat: chat, turn: turn))),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(width: 5, decoration: BoxDecoration(gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.4)!], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(turn.question, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 15.5, fontWeight: FontWeight.w800, color: a.text, height: 1.5)),
                if (r != null) ...[
                  const SizedBox(height: 6),
                  Text(r.summary.isNotEmpty ? r.summary : r.answer.replaceAll(RegExp(r'\[\d+\]|\*|#'), ''),
                      maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, color: a.muted, height: 1.7)),
                  const SizedBox(height: 12),
                  Row(children: [
                    StatusPill(status: r.status),
                    const Spacer(),
                    Icon(Icons.library_books_outlined, size: 15, color: a.faint),
                    const SizedBox(width: 4),
                    Text(context.l.sourceCount(r.sources.length), style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
                  ]),
                ],
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _SavedDetail extends StatelessWidget {
  const _SavedDetail({required this.chat, required this.turn});
  final Chat chat;
  final ChatTurn turn;
  @override
  Widget build(BuildContext context) {
    context.watch<ChatController>();
    final a = context.aura;
    return AuraPage(
      titleText: chat.title,
      actions: [
        AuraIconButton(
          tooltip: context.l.chats,
          icon: Icons.forum_outlined,
          onTap: () {
            Navigator.of(context).pop();
            openChat(context, chat.id);
          },
        ),
      ],
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 40), children: [
        ReadingWidth(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(gradient: a.brand, borderRadius: BorderRadius.circular(24)),
              child: Text(turn.question, style: const TextStyle(fontFamily: uiFont, color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.6)),
            ),
            const SizedBox(height: 16),
            if (turn.result != null) AnswerCard(turn: turn),
          ]),
        ),
      ]),
    );
  }
}
