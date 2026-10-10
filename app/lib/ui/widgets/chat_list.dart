import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/chat.dart';
import '../../state/chat_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../export/export_actions.dart';
import '../home_shell.dart';
import '../theme.dart';
import 'brand_logo.dart';
import 'common.dart';

/// The app menu: new chat, search, quick links, chats by date, settings.
class Sidebar extends StatefulWidget {
  const Sidebar({super.key, this.inDrawer = false});
  final bool inDrawer;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  String _query = '';

  void _closeDrawer() {
    if (widget.inDrawer) Navigator.of(context).maybePop();
  }

  void _open(Section s) {
    _closeDrawer();
    openSection(context, s);
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatController>();
    final settings = context.watch<SettingsController>();
    final l = context.l;
    final a = context.aura;
    final q = _query.trim().toLowerCase();
    final list = chats.sortedChats.where((c) => q.isEmpty || c.title.toLowerCase().contains(q) || c.turns.any((t) => t.question.toLowerCase().contains(q))).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String bucket(Chat c) {
      if (c.pinned) return l.pinned;
      final d = DateTime(c.updatedAt.year, c.updatedAt.month, c.updatedAt.day);
      final days = today.difference(d).inDays;
      if (days <= 0) return l.today;
      if (days == 1) return l.yesterday;
      if (days < 7) return l.previous7Days;
      return l.earlier;
    }

    final groups = <String, List<Chat>>{};
    for (final c in list) {
      groups.putIfAbsent(bucket(c), () => []).add(c);
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 8),
        child: Row(children: [
          const Padding(padding: EdgeInsetsDirectional.only(start: 4), child: BrandLogo(height: 30, latin: false)),
          const Spacer(),
          RoundIconButton(
            icon: Icons.edit_square,
            tooltip: l.newChat,
            onTap: () {
              chats.newChat();
              _closeDrawer();
              Navigator.of(context).popUntil((r) => r.isFirst);
            },
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Container(
          decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(16)),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(fontFamily: uiFont, color: a.text, fontSize: 14.5),
            decoration: InputDecoration(
              isDense: true,
              hintText: l.searchChats,
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              prefixIcon: Icon(Icons.search_rounded, color: a.muted, size: 20),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Row(children: [
          Expanded(child: _QuickLink(icon: Icons.auto_stories_rounded, label: l.navLibrary, color: AuraHues.teal, onTap: () => _open(Section.library))),
          const SizedBox(width: 8),
          Expanded(child: _QuickLink(icon: Icons.bookmark_rounded, label: l.navFavorites, color: AuraHues.rose, onTap: () => _open(Section.saved))),
          const SizedBox(width: 8),
          Expanded(child: _QuickLink(icon: Icons.history_rounded, label: l.navHistory, color: AuraHues.amber, onTap: () => _open(Section.history))),
        ]),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(l.noChats, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, color: a.faint, height: 1.6)),
                ),
              )
            : ListView(padding: const EdgeInsets.fromLTRB(8, 4, 8, 8), children: [
                for (final e in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
                    child: Text(e.key, style: TextStyle(fontFamily: uiFont, fontSize: 12, fontWeight: FontWeight.w700, color: a.faint)),
                  ),
                  for (final c in e.value) _ChatRow(chat: c, selected: chats.currentId == c.id, onOpen: _closeDrawer),
                ],
              ]),
      ),
      Divider(color: a.border, height: 1),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _open(Section.settings),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.settings_rounded, size: 20, color: a.muted),
                  ),
                  const SizedBox(width: 12),
                  Text(l.navSettings, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, color: a.text)),
                ]),
              ),
            ),
          ),
          AuraIconButton(
            icon: a.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            tooltip: a.dark ? l.themeLight : l.themeDark,
            filled: false,
            color: a.muted,
            onTap: () => settings.setThemeMode(a.dark ? ThemeMode.light : ThemeMode.dark),
          ),
        ]),
      ),
    ]);
  }
}

class _QuickLink extends StatelessWidget {
  const _QuickLink({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: a.dark ? 0.12 : 0.07), a.surface),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: a.dark ? 0.3 : 0.22)),
        ),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.text)),
        ]),
      ),
    );
  }
}

class _ChatRow extends StatelessWidget {
  const _ChatRow({required this.chat, required this.selected, required this.onOpen});
  final Chat chat;
  final bool selected;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final chats = context.read<ChatController>();
    final l = context.l;
    final a = context.aura;
    final c = chat;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Material(
        color: selected ? a.surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            chats.open(c.id);
            onOpen();
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 2, 0, 2),
            child: Row(children: [
              if (c.pinned) ...[Icon(Icons.push_pin_rounded, size: 14, color: a.accent), const SizedBox(width: 6)],
              Expanded(
                child: Text(c.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: a.text)),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz_rounded, size: 19, color: a.faint),
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
                      if (await confirmDialog(context, l.deleteChatConfirm)) chats.delete(c);
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
          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: Text(ctx.l.ok)),
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: AuraHues.rose, size: 32),
        content: Text(message, textAlign: TextAlign.center, style: const TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.6)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l.delete, style: const TextStyle(color: AuraHues.rose, fontWeight: FontWeight.w700))),
        ],
      ),
    ) ??
    false;
