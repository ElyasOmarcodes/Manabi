import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/catalog/catalog_service.dart';
import '../../core/models/chat.dart';
import '../../core/models/library.dart';
import '../../core/models/scope.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/chat_controller.dart';
import '../../state/nav_controller.dart';
import '../../state/settings_controller.dart';
import '../export/export_actions.dart';
import '../home_shell.dart';
import '../theme.dart';
import '../widgets/answer_card.dart';
import '../widgets/common.dart';
import '../widgets/scope_picker.dart';

/// Chat page in a clean, distraction-free chatbot style.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scroll = ScrollController();
  int _lastTurnCount = 0;
  String? _lastChatId;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 450), curve: Curves.easeOutCubic);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chats = context.watch<ChatController>();
    final settings = context.watch<SettingsController>();
    final chat = chats.current;
    final wide = MediaQuery.sizeOf(context).width >= wideBreakpoint;
    if (chat?.id != _lastChatId || (chat?.turns.length ?? 0) > _lastTurnCount) _scrollToEnd();
    _lastChatId = chat?.id;
    _lastTurnCount = chat?.turns.length ?? 0;
    final pending = chat?.turns.where((t) => t.state == MessageState.pending).lastOrNull;
    final empty = chat == null || chat.turns.isEmpty;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        _TopBar(chat: chat, wide: wide),
        Expanded(
          child: empty
              ? _Welcome(configured: settings.isConfigured)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                  itemCount: chat.turns.length,
                  itemBuilder: (context, i) => ReadingWidth(maxWidth: 760, child: _TurnView(turn: chat.turns[i], progress: chats.progress[chat.turns[i].id])),
                ),
        ),
        _Composer(pending: pending),
        SizedBox(height: wide ? 12 : MediaQuery.paddingOf(context).bottom + 4),
      ]),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.chat, required this.wide});
  final Chat? chat;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
      child: Row(children: [
        if (!wide) AuraIconButton(icon: Icons.menu_rounded, tooltip: l.chats, filled: false, onTap: () => Scaffold.of(context).openDrawer()) else const SizedBox(width: 12),
        Expanded(
          child: Text(chat?.title ?? l.appName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: wide ? TextAlign.start : TextAlign.center,
              style: TextStyle(fontFamily: uiFont, fontSize: 16, fontWeight: FontWeight.w700, color: a.text)),
        ),
        if (chat != null && chat!.turns.isNotEmpty)
          AuraIconButton(
            tooltip: l.exportChat,
            icon: Icons.ios_share_rounded,
            filled: false,
            onTap: () => showExportSheet(context, title: chat!.title, turns: chat!.turns, uiLanguage: context.read<SettingsController>().uiLanguage),
          ),
        AuraIconButton(tooltip: l.newChat, icon: Icons.edit_square, filled: false, onTap: () => context.read<ChatController>().newChat()),
      ]),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome({required this.configured});
  final bool configured;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    final nav = context.read<NavController>();
    final suggestions = [l.suggestion1, l.suggestion2, l.suggestion3, l.suggestion4];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
        child: ReadingWidth(
          maxWidth: 680,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Reveal(child: ManabiMark(size: 52)),
            const SizedBox(height: 18),
            Reveal(
              delay: 60,
              child: GradientText(l.welcomeTitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: uiFont, fontSize: 28, fontWeight: FontWeight.w800, height: 1.35)),
            ),
            Reveal(
              delay: 100,
              child: Text(l.welcomeQuestion, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 20, fontWeight: FontWeight.w600, color: a.muted, height: 1.5)),
            ),
            const SizedBox(height: 26),
            if (!configured)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Pressable(
                  onTap: () => nav.go(Section.settings),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(16)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.link_rounded, size: 18, color: a.accent),
                      const SizedBox(width: 8),
                      Flexible(child: Text(l.notConfiguredTitle, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, color: a.accent))),
                      const SizedBox(width: 6),
                      Icon(Directionality.of(context) == TextDirection.rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded, size: 18, color: a.accent),
                    ]),
                  ),
                ),
              ),
            LayoutBuilder(builder: (context, c) {
              final two = c.maxWidth > 520;
              return Wrap(spacing: 10, runSpacing: 10, children: [
                for (final (i, text) in suggestions.indexed)
                  SizedBox(
                    width: two ? (c.maxWidth - 10) / 2 : c.maxWidth,
                    child: Reveal(
                      delay: 140 + i * 50,
                      child: Pressable(
                        onTap: () => nav.prefill(text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(border: Border.all(color: a.border), borderRadius: BorderRadius.circular(18)),
                          child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.55, color: a.text)),
                        ),
                      ),
                    ),
                  ),
              ]);
            }),
          ]),
        ),
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn, required this.progress});
  final ChatTurn turn;
  final AskProgress? progress;

  @override
  Widget build(BuildContext context) {
    final chats = context.read<ChatController>();
    final settings = context.read<SettingsController>();
    void retry() => chats.retry(turn, fallbackLanguage: settings.uiLanguage, maxSources: settings.maxSources);
    return Padding(
      padding: const EdgeInsets.only(bottom: 30),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _UserBubble(turn: turn),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
          layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
          child: switch (turn.state) {
            MessageState.pending => StageTimeline(key: const ValueKey('p'), progress: progress ?? AskProgress()),
            MessageState.done when turn.result != null => AnswerCard(key: ValueKey('a${turn.id}'), turn: turn, onRetry: retry),
            _ => _ErrorLine(key: const ValueKey('e'), code: turn.errorCode, onRetry: retry),
          },
        ),
      ]),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.turn});
  final ChatTurn turn;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final scope = turn.scope;
    final label = [?scope.bookTitle, ?scope.authorName, ?scope.categoryTitle].join(' · ');
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(22)),
            child: SelectableText(turn.question, style: TextStyle(fontFamily: uiFont, color: a.text, fontSize: 15.5, height: 1.65)),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.filter_list_rounded, size: 14, color: a.faint),
                const SizedBox(width: 4),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.faint))),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine({super.key, required this.code, required this.onRetry});
  final String? code;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(top: 2), child: Icon(Icons.error_outline_rounded, size: 20, color: a.danger)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(errorText(l, code), style: TextStyle(fontFamily: uiFont, color: a.text, height: 1.6)),
          const SizedBox(height: 6),
          if (isSetupError(code))
            SoftButton(dense: true, label: l.openSettings, icon: Icons.tune_rounded, onTap: () => context.read<NavController>().go(Section.settings))
          else
            SoftButton(dense: true, label: l.retry, icon: Icons.refresh_rounded, onTap: onRetry),
        ]),
      ),
    ]);
  }
}

/// One rounded input box: text on top, options / scope / send underneath.
class _Composer extends StatefulWidget {
  const _Composer({required this.pending});
  final ChatTurn? pending;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || widget.pending != null) return;
    final settings = context.read<SettingsController>();
    final nav = context.read<NavController>();
    _controller.clear();
    await context.read<ChatController>().ask(text, language: settings.answerLanguage, fallbackLanguage: settings.uiLanguage, scope: nav.scope, maxSources: settings.maxSources);
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final settings = context.watch<SettingsController>();
    if (nav.draft != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final d = nav.takeDraft();
        if (d != null) {
          _controller.text = d;
          _focus.requestFocus();
        }
      });
    }
    final l = context.l;
    final a = context.aura;
    final busy = widget.pending != null;
    final canSend = _controller.text.trim().isNotEmpty && !busy;
    final scope = nav.scope;
    final scopeLabel = [?scope.bookTitle, ?scope.authorName, ?scope.categoryTitle].join(' · ');
    final langLabel = settings.answerLanguage == 'auto' ? null : languageLabels(l)[settings.answerLanguage];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
      child: ReadingWidth(
        maxWidth: 760,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          decoration: BoxDecoration(
            color: a.surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: _focus.hasFocus ? a.accent.withValues(alpha: 0.55) : a.border, width: _focus.hasFocus ? 1.4 : 1),
            boxShadow: [BoxShadow(color: a.shadow, blurRadius: 24, offset: const Offset(0, 8), spreadRadius: -10)],
          ),
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: CallbackShortcuts(
                bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  minLines: 1,
                  maxLines: 7,
                  maxLength: 2000,
                  textInputAction: TextInputAction.newline,
                  style: TextStyle(fontFamily: uiFont, fontSize: 15.5, height: 1.6, color: a.text),
                  decoration: InputDecoration(
                    hintText: l.askPlaceholder,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Row(children: [
              AuraIconButton(icon: Icons.add_rounded, tooltip: l.options, size: 38, onTap: () => _showOptions(context)),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    if (scopeLabel.isNotEmpty)
                      _Pill(icon: Icons.filter_list_rounded, label: scopeLabel, onTap: () => _showOptions(context), onClear: () => nav.setScope(SearchScope.all)),
                    if (langLabel != null)
                      _Pill(icon: Icons.translate_rounded, label: langLabel, onTap: () => _showOptions(context), onClear: () => settings.setAnswerLanguage('auto')),
                  ]),
                ),
              ),
              Tooltip(
                message: busy ? l.stop : l.send,
                child: Pressable(
                  onTap: busy ? () => context.read<ChatController>().cancel(widget.pending!) : (canSend ? _send : null),
                  scale: 0.88,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: busy ? a.text : (canSend ? a.accent : a.surfaceAlt),
                    ),
                    child: Icon(busy ? Icons.stop_rounded : Icons.arrow_upward_rounded, size: 20, color: busy ? a.bg : (canSend ? Colors.white : a.faint)),
                  ),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Future<void> _showOptions(BuildContext context) => showModalBottomSheet(context: context, builder: (_) => const _OptionsSheet());
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.onTap, required this.onClear});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback onClear;
  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(10, 6, 6, 6),
          decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 15, color: a.accent),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 190),
              child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: a.accent)),
            ),
            const SizedBox(width: 2),
            GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 16, color: a.accent)),
          ]),
        ),
      ),
    );
  }
}

/// "+" sheet: search scope and answer language.
class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet();
  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final settings = context.watch<SettingsController>();
    final catalog = context.read<CatalogService>();
    final l = context.l;
    final a = context.aura;
    final scope = nav.scope;
    final labels = languageLabels(l);
    Widget row(IconData icon, String title, String? value, VoidCallback onTap, {bool selected = false}) => ListTile(
          leading: Icon(icon, color: selected || value != null ? a.accent : a.muted),
          title: Text(title, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, color: a.text)),
          subtitle: value == null ? null : Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 14, color: a.accent).copyWith(height: 1.5)),
          trailing: selected ? Icon(Icons.check_rounded, color: a.accent) : null,
          onTap: onTap,
        );
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            child: Text(l.scopeTitle, style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: a.text)),
          ),
          row(Icons.all_inclusive_rounded, l.scopeAll, null, () => nav.setScope(SearchScope.all), selected: scope.isAll),
          row(Icons.category_outlined, l.scopeCategory, scope.categoryTitle, () async {
            final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
            if (c != null) nav.setScope(scope.withCategory(c.id, c.title));
          }),
          row(Icons.person_outline_rounded, l.scopeAuthor, scope.authorName, () async {
            final x = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
            if (x != null) nav.setScope(scope.withAuthor(x.id, x.name));
          }),
          row(Icons.menu_book_outlined, l.scopeBook, scope.bookTitle, () async {
            final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: scope.authorId, categoryId: scope.categoryId);
            if (b != null) nav.setScope(scope.withBook(b.id, b.title).withAuthor(b.authorId, catalog.author(b.authorId)?.name));
          }),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(l.answerLanguage, style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w700, color: a.text)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in labels.entries) AuraChip(label: e.value, selected: settings.answerLanguage == e.key, onTap: () => settings.setAnswerLanguage(e.key)),
            ]),
          ),
        ]),
      ),
    );
  }
}

Map<String, String> languageLabels(AppLocalizations l) => {
      'auto': l.langAuto,
      'ps': 'پښتو',
      'fa': 'دری / فارسی',
      'ar': 'العربية',
      'en': 'English',
    };
