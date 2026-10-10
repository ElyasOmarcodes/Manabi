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

const wideBreakpoint = 980.0;

/// ChatGPT-style structure: the chat is home; a side menu (drawer on phones,
/// a fixed sidebar on wide screens) holds the chat list and opens the
/// library, saved answers, history and settings as their own pages.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    final a = context.aura;
    if (wide) {
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 296, child: ColoredBox(color: a.surface, child: const SafeArea(child: Sidebar()))),
          VerticalDivider(width: 1, color: a.border),
          const Expanded(child: ChatScreen()),
        ]),
      );
    }
    return Scaffold(
      drawer: Drawer(
        width: 312,
        backgroundColor: a.surface,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadiusDirectional.horizontal(end: Radius.circular(28))),
        child: const SafeArea(child: Sidebar(inDrawer: true)),
      ),
      body: const ChatScreen(),
    );
  }
}

Widget sectionPage(Section section) => switch (section) {
      Section.library => const LibraryScreen(),
      Section.saved => const SavedScreen(),
      Section.history => const HistoryScreen(),
      Section.settings => const SettingsScreen(),
      Section.chat => const SizedBox.shrink(),
    };

/// Opens a menu destination as its own page.
void openSection(BuildContext context, Section section) {
  if (section == Section.chat) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    return;
  }
  final scaffold = Scaffold.maybeOf(context);
  if (scaffold?.isDrawerOpen ?? false) scaffold!.closeDrawer();
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => sectionPage(section)));
}

/// Opens a chat from anywhere (history, saved) and returns to the chat page.
void openChat(BuildContext context, String chatId) {
  context.read<ChatController>().open(chatId);
  context.read<NavController>().go(Section.chat);
  Navigator.of(context).popUntil((r) => r.isFirst);
}
