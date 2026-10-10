import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/chat_controller.dart';
import '../state/nav_controller.dart';
import 'screens/chat_screen.dart';
import 'screens/history_screen.dart';
import 'screens/library_screen.dart';
import 'screens/saved_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/chat_list.dart';
import 'widgets/common.dart';

const wideBreakpoint = 980.0;

typedef _Dest = ({
  Section section,
  IconData icon,
  IconData active,
  String label,
  Color color,
});

List<_Dest> _destinations(BuildContext context) {
  final l = context.l;
  return [
    (
      section: Section.chat,
      icon: Icons.chat_bubble_outline_rounded,
      active: Icons.chat_bubble_rounded,
      label: l.navChat,
      color: AuraHues.violet,
    ),
    (
      section: Section.library,
      icon: Icons.auto_stories_outlined,
      active: Icons.auto_stories_rounded,
      label: l.navLibrary,
      color: AuraHues.blue,
    ),
    (
      section: Section.saved,
      icon: Icons.bookmark_outline_rounded,
      active: Icons.bookmark_rounded,
      label: l.navFavorites,
      color: AuraHues.pink,
    ),
    (
      section: Section.history,
      icon: Icons.history_rounded,
      active: Icons.history_rounded,
      label: l.navHistory,
      color: AuraHues.amber,
    ),
    (
      section: Section.settings,
      icon: Icons.tune_rounded,
      active: Icons.tune_rounded,
      label: l.navSettings,
      color: AuraHues.mint,
    ),
  ];
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final body = _SectionBody(section: nav.section);
    if (wide) {
      return Scaffold(
        body: AuroraBackground(
          child: SafeArea(
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(14, 14, 0, 14),
                  child: SizedBox(width: 300, child: _Sidebar()),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      );
    }
    return Scaffold(
      extendBody: true,
      drawer: Drawer(
        width: 320,
        backgroundColor: context.aura.bg,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadiusDirectional.horizontal(
            end: Radius.circular(32),
          ),
        ),
        child: const SafeArea(child: ChatList(inDrawer: true)),
      ),
      body: AuroraBackground(child: body),
      bottomNavigationBar: const _Dock(),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final Section section;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 320),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    transitionBuilder: (child, a) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: Tween(begin: 0.985, end: 1.0).animate(a),
        child: child,
      ),
    ),
    child: KeyedSubtree(
      key: ValueKey(section),
      child: switch (section) {
        Section.chat => const ChatScreen(),
        Section.library => const LibraryScreen(),
        Section.saved => const SavedScreen(),
        Section.history => const HistoryScreen(),
        Section.settings => const SettingsScreen(),
      },
    ),
  );
}

/// Floating glass dock with a sliding gradient pill.
class _Dock extends StatelessWidget {
  const _Dock();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final dests = _destinations(context);
    final a = context.aura;
    final index = dests.indexWhere((d) => d.section == nav.section);
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Glass(
        radius: 30,
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 58,
          child: LayoutBuilder(
            builder: (context, c) {
              final selectedW = c.maxWidth * 0.34;
              final otherW = (c.maxWidth - selectedW) / (dests.length - 1);
              return Row(
                children: [
                  for (var i = 0; i < dests.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutBack,
                      width: i == index ? selectedW : otherW,
                      child: Semantics(
                        button: true,
                        selected: i == index,
                        label: dests[i].label,
                        excludeSemantics: true,
                        child: Pressable(
                          onTap: () => nav.go(dests[i].section),
                          scale: 0.9,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              gradient: i == index ? a.brand : null,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: i == index
                                  ? [
                                      BoxShadow(
                                        color: AuraHues.violet.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 16,
                                        offset: const Offset(0, 6),
                                        spreadRadius: -6,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  i == index ? dests[i].active : dests[i].icon,
                                  size: 22,
                                  color: i == index ? Colors.white : a.muted,
                                ),
                                if (i == index) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      dests[i].label,
                                      maxLines: 1,
                                      overflow: TextOverflow.fade,
                                      softWrap: false,
                                      style: const TextStyle(
                                        fontFamily: uiFont,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final a = context.aura;
    final dests = _destinations(context).skip(1);
    return Glass(
      padding: EdgeInsets.zero,
      radius: 30,
      child: Column(
        children: [
          const Expanded(child: ChatList()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(color: a.border),
          ),
          const SizedBox(height: 6),
          for (final d in dests)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              child: Material(
                color: nav.section == d.section
                    ? d.color.withValues(alpha: a.dark ? 0.18 : 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => nav.go(d.section),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconTile(
                          icon: nav.section == d.section ? d.active : d.icon,
                          color: d.color,
                          size: 34,
                          gradient: nav.section == d.section,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          d.label,
                          style: TextStyle(
                            fontFamily: uiFont,
                            fontWeight: FontWeight.w600,
                            color: a.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Opens a chat from anywhere (history, saved) and switches to the chat tab.
void openChat(BuildContext context, String chatId) {
  context.read<ChatController>().open(chatId);
  context.read<NavController>().go(Section.chat);
}
