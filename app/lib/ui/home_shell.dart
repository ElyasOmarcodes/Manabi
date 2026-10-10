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

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final body = _SectionBody(section: nav.section);
    if (wide) {
      return Scaffold(
        body: AmbientBackground(
          child: Row(children: [
            const SizedBox(width: 312, child: _Sidebar()),
            VerticalDivider(width: 1, color: context.cs.outlineVariant.withValues(alpha: 0.6)),
            Expanded(child: body),
          ]),
        ),
      );
    }
    final l = context.l;
    return Scaffold(
      drawer: const Drawer(width: 312, child: SafeArea(child: ChatList(inDrawer: true))),
      body: AmbientBackground(child: body),
      bottomNavigationBar: NavigationBar(
        selectedIndex: nav.section.index,
        onDestinationSelected: (i) => nav.go(Section.values[i]),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(icon: const Icon(Icons.chat_bubble_outline_rounded), selectedIcon: const Icon(Icons.chat_bubble_rounded), label: l.navChat),
          NavigationDestination(icon: const Icon(Icons.local_library_outlined), selectedIcon: const Icon(Icons.local_library_rounded), label: l.navLibrary),
          NavigationDestination(icon: const Icon(Icons.bookmark_outline_rounded), selectedIcon: const Icon(Icons.bookmark_rounded), label: l.navFavorites),
          NavigationDestination(icon: const Icon(Icons.history_rounded), label: l.navHistory),
          NavigationDestination(icon: const Icon(Icons.tune_rounded), label: l.navSettings),
        ],
      ),
    );
  }
}

class _SectionBody extends StatelessWidget {
  const _SectionBody({required this.section});
  final Section section;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: SlideTransition(position: Tween(begin: const Offset(0, 0.015), end: Offset.zero).animate(a), child: child),
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

class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final l = context.l;
    Widget item(Section s, IconData icon, String label) {
      final selected = nav.section == s;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: ListTile(
          dense: true,
          selected: selected,
          selectedTileColor: context.cs.primary.withValues(alpha: 0.10),
          leading: Icon(icon, size: 21),
          title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          onTap: () => nav.go(s),
        ),
      );
    }

    return Material(
      color: context.cs.surfaceContainerLow.withValues(alpha: 0.75),
      child: SafeArea(
        child: Column(children: [
          const Expanded(child: ChatList()),
          const Divider(),
          const SizedBox(height: 6),
          item(Section.library, Icons.local_library_outlined, l.navLibrary),
          item(Section.saved, Icons.bookmark_outline_rounded, l.navFavorites),
          item(Section.history, Icons.history_rounded, l.navHistory),
          item(Section.settings, Icons.tune_rounded, l.navSettings),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}

/// Opens a chat from anywhere (history, saved) and switches to the chat tab.
void openChat(BuildContext context, String chatId) {
  context.read<ChatController>().open(chatId);
  context.read<NavController>().go(Section.chat);
}
