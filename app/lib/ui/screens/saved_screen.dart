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
    return SafeArea(
      bottom: false,
      child: Column(children: [
        _Header(icon: Icons.bookmark_rounded, title: l.navFavorites),
        Expanded(
          child: favorites.isEmpty
              ? EmptyState(icon: Icons.bookmark_outline_rounded, text: l.noFavorites)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: favorites.length,
                  itemBuilder: (context, i) {
                    final (chat, turn) = favorites[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ReadingWidth(child: _SavedTile(chat: chat, turn: turn)),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class _SavedTile extends StatelessWidget {
  const _SavedTile({required this.chat, required this.turn});
  final Chat chat;
  final ChatTurn turn;
  @override
  Widget build(BuildContext context) {
    final r = turn.result;
    return SoftCard(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _SavedDetail(chat: chat, turn: turn))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(turn.question, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (r != null) ...[
          const SizedBox(height: 6),
          Text(r.summary.isNotEmpty ? r.summary : r.answer.replaceAll(RegExp(r'\[\d+\]|\*'), ''), maxLines: 3, overflow: TextOverflow.ellipsis, style: context.tt.bodyMedium?.copyWith(color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(children: [
            StatusPill(status: r.status),
            const Spacer(),
            Text(context.l.sourceCount(r.sources.length), style: context.tt.labelSmall),
          ]),
        ],
      ]),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(chat.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.l.chats,
            icon: const Icon(Icons.forum_outlined),
            onPressed: () {
              Navigator.of(context).pop();
              openChat(context, chat.id);
            },
          ),
        ],
      ),
      body: AmbientBackground(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          ReadingWidth(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(turn.question, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              if (turn.result != null) AnswerCard(turn: turn),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
        child: ReadingWidth(
          child: Row(children: [
            Icon(icon, color: context.cs.primary),
            const SizedBox(width: 10),
            Flexible(child: Text(title, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
          ]),
        ),
      );
}

class ScreenHeader extends _Header {
  const ScreenHeader({super.key, required super.icon, required super.title});
}
