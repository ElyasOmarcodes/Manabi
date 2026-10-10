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
    final a = context.aura;
    final q = _query.trim().toLowerCase();
    final list = chats.sortedChats.where((c) => q.isEmpty || c.title.toLowerCase().contains(q) || c.turns.any((t) => t.question.toLowerCase().contains(q))).toList();
    final pinned = list.where((c) => c.pinned).toList();
    final recent = list.where((c) => !c.pinned).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 14),
        child: Row(children: [
          const ManabiMark(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              GradientText(l.appName, style: const TextStyle(fontFamily: uiFont, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2)),
              Text('Manabi · منابع', style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.muted)),
            ]),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GradientButton(
          label: l.newChat,
          icon: Icons.add_rounded,
          expand: true,
          height: 48,
          onTap: () {
            chats.newChat();
            nav.go(Section.chat);
            _close();
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        child: AuraSearchField(hint: l.searchChats, onChanged: (v) => setState(() => _query = v)),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.forum_outlined, size: 34, color: a.faint),
                    const SizedBox(height: 10),
                    Text(l.noChats, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, color: a.muted, height: 1.6)),
                  ]),
                ),
              )
            : ListView(padding: const EdgeInsets.fromLTRB(10, 4, 10, 10), children: [
                if (pinned.isNotEmpty) _header(context, l.pinned),
                for (final c in pinned) _tile(context, c, chats, nav),
                if (recent.isNotEmpty) _header(context, l.recent),
                for (final c in recent) _tile(context, c, chats, nav),
              ]),
      ),
    ]);
  }

  Widget _header(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
        child: Text(text.toUpperCase(), style: TextStyle(fontFamily: uiFont, fontSize: 11.5, letterSpacing: 0.6, fontWeight: FontWeight.w700, color: context.aura.faint)),
      );

  Widget _tile(BuildContext context, Chat c, ChatController chats, NavController nav) {
    final l = context.l;
    final a = context.aura;
    final selected = chats.currentId == c.id;
    final date = DateFormat.MMMd(Localizations.localeOf(context).toLanguageTag()).format(c.updatedAt);
    final hue = AuraHues.at(c.id.hashCode);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? a.accent.withValues(alpha: a.dark ? 0.18 : 0.09) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            chats.open(c.id);
            nav.go(Section.chat);
            _close();
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10, 8, 2, 8),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.pinned ? AuraHues.amber : hue, boxShadow: [BoxShadow(color: hue.withValues(alpha: 0.5), blurRadius: 8)]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: a.text, fontSize: 14)),
                  Text('$date · ${c.turns.length}', style: TextStyle(fontFamily: uiFont, color: a.faint, fontSize: 11.5)),
                ]),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 20, color: a.faint),
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
                      final ok = await confirmDialog(context, l.deleteChatConfirm);
                      if (ok) chats.delete(c);
                  }
                },
                itemBuilder: (_) => [
                  _menu('rename', Icons.edit_outlined, l.rename, a.text),
                  _menu('pin', c.pinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, c.pinned ? l.unpin : l.pin, a.text),
                  _menu('export', Icons.ios_share_rounded, l.exportChat, a.text),
                  _menu('delete', Icons.delete_outline_rounded, l.delete, a.danger),
                ],
              ),
            ]),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menu(String v, IconData icon, String text, Color color) => PopupMenuItem(
        value: v,
        child: Row(children: [Icon(icon, size: 19, color: color), const SizedBox(width: 10), Text(text, style: TextStyle(color: color))]),
      );

  Future<String?> _rename(BuildContext context, String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l.rename),
        content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(ctx, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l.cancel)),
          GradientButton(label: ctx.l.ok, height: 42, onTap: () => Navigator.pop(ctx, controller.text)),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: IconTile(icon: Icons.delete_outline_rounded, color: AuraHues.rose, size: 52, gradient: true),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.6)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SoftButton(label: ctx.l.cancel, color: ctx.aura.muted, onTap: () => Navigator.pop(ctx, false)),
          GradientButton(label: ctx.l.delete, height: 44, gradient: const LinearGradient(colors: [AuraHues.rose, AuraHues.pink]), onTap: () => Navigator.pop(ctx, true)),
        ],
      ),
    ) ??
    false;
