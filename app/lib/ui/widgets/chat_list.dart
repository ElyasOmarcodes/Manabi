import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/chat.dart';
import '../../state/chat_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../export/export_actions.dart';
import '../theme.dart';
import 'common.dart';

class ChatList extends StatefulWidget {
  const ChatList({super.key, this.inDrawer = false});
  final bool inDrawer;

  @override
  State<ChatList> createState() => _ChatListState();
}

class _ChatListState extends State<ChatList> {
  String _query = '';

  void _close() {
    if (widget.inDrawer) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatController>();
    final nav = context.read<NavController>();
    final l = context.l;
    final q = _query.trim().toLowerCase();
    final list = chats.sortedChats.where((c) => q.isEmpty || c.title.toLowerCase().contains(q) || c.turns.any((t) => t.question.toLowerCase().contains(q))).toList();
    final pinned = list.where((c) => c.pinned).toList();
    final recent = list.where((c) => !c.pinned).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Row(children: [
          const ManabiLogo(size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.appName, style: context.tt.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text('Manabi · منابع', style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
        child: FilledButton.tonalIcon(
          onPressed: () {
            chats.newChat();
            nav.askWithin(nav.scope);
            _close();
          },
          icon: const Icon(Icons.add_rounded),
          label: Text(l.newChat),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            isDense: true,
            hintText: l.searchChats,
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.noChats, textAlign: TextAlign.center, style: TextStyle(color: context.cs.onSurfaceVariant)),
                ),
              )
            : ListView(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), children: [
                if (pinned.isNotEmpty) _header(context, l.pinned),
                for (final c in pinned) _tile(context, c, chats, nav),
                if (recent.isNotEmpty) _header(context, l.recent),
                for (final c in recent) _tile(context, c, chats, nav),
              ]),
      ),
    ]);
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
        child: Text(text, style: context.tt.labelMedium?.copyWith(color: context.cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
      );

  Widget _tile(BuildContext context, Chat c, ChatController chats, NavController nav) {
    final l = context.l;
    final selected = chats.currentId == c.id;
    final date = DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(c.updatedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: ListTile(
        dense: true,
        selected: selected,
        selectedTileColor: context.cs.primary.withValues(alpha: 0.10),
        contentPadding: const EdgeInsetsDirectional.only(start: 14, end: 4),
        title: Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Text('$date · ${c.turns.length}', style: TextStyle(color: context.cs.onSurfaceVariant, fontSize: 12)),
        leading: Icon(c.pinned ? Icons.push_pin_rounded : Icons.chat_bubble_outline_rounded, size: 18, color: c.pinned ? context.mc.gold : null),
        minLeadingWidth: 20,
        onTap: () {
          chats.open(c.id);
          nav.go(Section.chat);
          _close();
        },
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_horiz_rounded, size: 20),
          onSelected: (v) async {
            switch (v) {
              case 'rename':
                final name = await _rename(context, c.title);
                if (name != null) chats.rename(c, name);
              case 'pin':
                chats.togglePin(c);
              case 'export':
                if (context.mounted) await showExportSheet(context, title: c.title, turns: c.turns, uiLanguage: context.read<SettingsController>().uiLanguage);
              case 'delete':
                final ok = await _confirm(context, l.deleteChatConfirm);
                if (ok) chats.delete(c);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(value: 'rename', child: Text(l.rename)),
            PopupMenuItem(value: 'pin', child: Text(c.pinned ? l.unpin : l.pin)),
            PopupMenuItem(value: 'export', child: Text(l.exportChat)),
            PopupMenuItem(value: 'delete', child: Text(l.delete, style: TextStyle(color: context.cs.error))),
          ],
        ),
      ),
    );
  }

  Future<String?> _rename(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l.rename),
        content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(ctx.l.ok)),
        ],
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l.delete)),
        ],
      ),
    ) ??
    false;

Future<bool> confirmDialog(BuildContext context, String message) => _confirm(context, message);
