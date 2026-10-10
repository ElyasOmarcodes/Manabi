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

    return SafeArea(
      bottom: false,
      child: Column(children: [
        _TopBar(chat: chat, wide: wide),
        Expanded(
          child: chat == null || chat.turns.isEmpty
              ? _Welcome(configured: settings.isConfigured)
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: chat.turns.length,
                  itemBuilder: (context, i) => ReadingWidth(child: _TurnView(turn: chat.turns[i], progress: chats.progress[chat.turns[i].id])),
                ),
        ),
        const _Composer(),
        if (wide) SizedBox(height: 6 + MediaQuery.paddingOf(context).bottom),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 2),
      child: Row(children: [
        if (!wide)
          IconButton(icon: const Icon(Icons.menu_rounded), tooltip: l.chats, onPressed: () => Scaffold.of(context).openDrawer())
        else
          const SizedBox(width: 12),
        if (!wide) ...[const ManabiLogo(size: 30), const SizedBox(width: 10)],
        Expanded(
          child: Text(chat?.title ?? l.newChat, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        ),
        if (chat != null && chat!.turns.isNotEmpty)
          IconButton(
            tooltip: l.exportChat,
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () => showExportSheet(context, title: chat!.title, turns: chat!.turns, uiLanguage: context.read<SettingsController>().uiLanguage),
          ),
        IconButton(
          tooltip: l.newChat,
          icon: const Icon(Icons.edit_square),
          onPressed: () => context.read<ChatController>().newChat(),
        ),
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
    final nav = context.read<NavController>();
    final suggestions = [
      (Icons.format_quote_rounded, l.suggestion1),
      (Icons.balance_rounded, l.suggestion2),
      (Icons.auto_awesome_outlined, l.suggestion3),
      (Icons.school_outlined, l.suggestion4),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: ReadingWidth(
        maxWidth: 760,
        child: Column(children: [
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.85, end: 1),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutBack,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: context.cs.primary.withValues(alpha: 0.18), blurRadius: 40, spreadRadius: 4)]),
              child: const ManabiLogo(size: 84),
            ),
          ),
          const SizedBox(height: 18),
          Text(l.welcomeTitle, style: context.tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text(l.welcomeBody, textAlign: TextAlign.center, style: context.tt.bodyLarge?.copyWith(color: context.cs.onSurfaceVariant)),
          const SizedBox(height: 22),
          if (!configured)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: SoftCard(
                color: context.mc.warning.withValues(alpha: 0.08),
                borderColor: context.mc.warning.withValues(alpha: 0.4),
                child: Row(children: [
                  Icon(Icons.link_off_rounded, color: context.mc.warning),
                  const SizedBox(width: 12),
                  Expanded(child: Text(l.notConfiguredTitle, style: const TextStyle(fontWeight: FontWeight.w600))),
                  FilledButton.tonal(onPressed: () => nav.go(Section.settings), child: Text(l.openSettings)),
                ]),
              ),
            ),
          LayoutBuilder(builder: (context, c) {
            final two = c.maxWidth > 560;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (icon, text) in suggestions)
                SizedBox(
                  width: two ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  child: SoftCard(
                    padding: const EdgeInsets.all(16),
                    onTap: () => nav.prefill(text),
                    child: Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: context.mc.glow, borderRadius: BorderRadius.circular(12)),
                        child: Icon(icon, size: 20, color: context.cs.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(text, style: context.tt.bodyMedium?.copyWith(height: 1.55))),
                    ]),
                  ),
                ),
            ]);
          }),
        ]),
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
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _UserBubble(turn: turn),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SizeTransition(sizeFactor: a, alignment: Alignment.topCenter, child: child),
          ),
          child: switch (turn.state) {
            MessageState.pending => StageTimeline(key: const ValueKey('p'), progress: progress ?? AskProgress(), onCancel: () => chats.cancel(turn)),
            MessageState.done when turn.result != null => AnswerCard(key: ValueKey('a${turn.id}'), turn: turn, onRetry: retry),
            _ => _ErrorCard(key: const ValueKey('e'), code: turn.errorCode, onRetry: retry),
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
    final scope = turn.scope;
    final label = [?scope.bookTitle, ?scope.authorName, ?scope.categoryTitle].join(' · ');
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: context.mc.userBubble,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(22),
                topEnd: Radius.circular(22),
                bottomStart: Radius.circular(22),
                bottomEnd: Radius.circular(6),
              ).resolve(Directionality.of(context)),
              boxShadow: [BoxShadow(color: context.mc.userBubble.withValues(alpha: 0.25), blurRadius: 18, offset: const Offset(0, 6))],
            ),
            child: SelectableText(turn.question, style: context.tt.bodyLarge?.copyWith(color: context.mc.onUserBubble, height: 1.6)),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.filter_alt_outlined, size: 14, color: context.cs.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(child: Text(label, style: context.tt.labelSmall?.copyWith(color: context.cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
              ]),
            ),
        ]),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({super.key, required this.code, required this.onRetry});
  final String? code;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return SoftCard(
      color: context.cs.errorContainer.withValues(alpha: 0.35),
      borderColor: context.cs.error.withValues(alpha: 0.25),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, color: context.cs.error),
        const SizedBox(width: 12),
        Expanded(child: Text(errorText(l, code))),
        if (isSetupError(code))
          TextButton(onPressed: () => context.read<NavController>().go(Section.settings), child: Text(l.openSettings))
        else
          TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded, size: 18), label: Text(l.retry)),
      ]),
    );
  }
}

/// Input area: scope chips, answer language and the message field.
class _Composer extends StatefulWidget {
  const _Composer();
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final draft = context.read<NavController>().takeDraft();
    if (draft != null) {
      _controller.text = draft;
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final settings = context.read<SettingsController>();
    final nav = context.read<NavController>();
    _controller.clear();
    await context.read<ChatController>().ask(
          text,
          language: settings.answerLanguage,
          fallbackLanguage: settings.uiLanguage,
          scope: nav.scope,
          maxSources: settings.maxSources,
        );
  }

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<NavController>();
    final settings = context.watch<SettingsController>();
    final draft = nav.draft;
    if (draft != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final d = nav.takeDraft();
        if (d != null) {
          _controller.text = d;
          _focus.requestFocus();
        }
      });
    }
    final l = context.l;
    final canSend = _controller.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      child: ReadingWidth(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              _ScopeChips(scope: nav.scope),
              const SizedBox(width: 6),
              _LanguageChip(value: settings.answerLanguage),
            ]),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.07), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Material(
              color: context.cs.surfaceContainerLowest,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: BorderSide(color: context.cs.outlineVariant.withValues(alpha: 0.8))),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 4, 6, 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                    child: CallbackShortcuts(
                      bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
                      child: TextField(
                        controller: _controller,
                        focusNode: _focus,
                        minLines: 1,
                        maxLines: 6,
                        maxLength: 2000,
                        textInputAction: TextInputAction.newline,
                        style: context.tt.bodyLarge?.copyWith(height: 1.55),
                        decoration: InputDecoration(
                          hintText: l.askPlaceholder,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          counterText: '',
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: canSend ? 1 : 0.9,
                      child: IconButton.filled(
                        tooltip: l.send,
                        onPressed: canSend ? _send : null,
                        style: IconButton.styleFrom(minimumSize: const Size(46, 46)),
                        icon: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ScopeChips extends StatelessWidget {
  const _ScopeChips({required this.scope});
  final SearchScope scope;

  @override
  Widget build(BuildContext context) {
    final nav = context.read<NavController>();
    final catalog = context.read<CatalogService>();
    final l = context.l;
    Widget chip({required IconData icon, required String label, required bool active, required VoidCallback onTap, VoidCallback? onClear}) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: InputChip(
            avatar: Icon(icon, size: 17, color: active ? context.cs.onPrimary : context.cs.primary),
            label: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(label, overflow: TextOverflow.ellipsis)),
            selected: active,
            showCheckmark: false,
            selectedColor: context.cs.primary,
            labelStyle: TextStyle(color: active ? context.cs.onPrimary : context.cs.onSurface, fontFamily: uiFont, fontSize: 13),
            onPressed: onTap,
            onDeleted: active ? onClear : null,
            deleteIconColor: context.cs.onPrimary,
          ),
        );

    return Row(children: [
      chip(icon: Icons.all_inclusive_rounded, label: l.scopeAll, active: scope.isAll, onTap: () => nav.setScope(SearchScope.all)),
      chip(
        icon: Icons.category_outlined,
        label: scope.categoryTitle ?? l.scopeCategory,
        active: scope.categoryId != null,
        onTap: () async {
          final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
          if (c != null) nav.setScope(scope.withCategory(c.id, c.title));
        },
        onClear: () => nav.setScope(scope.withCategory(null, null)),
      ),
      chip(
        icon: Icons.person_outline_rounded,
        label: scope.authorName ?? l.scopeAuthor,
        active: scope.authorId != null,
        onTap: () async {
          final a = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
          if (a != null) nav.setScope(scope.withAuthor(a.id, a.name));
        },
        onClear: () => nav.setScope(scope.withAuthor(null, null)),
      ),
      chip(
        icon: Icons.menu_book_outlined,
        label: scope.bookTitle ?? l.scopeBook,
        active: scope.bookId != null,
        onTap: () async {
          final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: scope.authorId, categoryId: scope.categoryId);
          if (b != null) nav.setScope(scope.withBook(b.id, b.title).withAuthor(b.authorId, catalog.author(b.authorId)?.name));
        },
        onClear: () => nav.setScope(scope.withBook(null, null)),
      ),
    ]);
  }
}

class _LanguageChip extends StatelessWidget {
  const _LanguageChip({required this.value});
  final String value;
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final labels = languageLabels(l);
    return PopupMenuButton<String>(
      tooltip: l.answerLanguage,
      initialValue: value,
      onSelected: (v) => context.read<SettingsController>().setAnswerLanguage(v),
      itemBuilder: (_) => [for (final e in labels.entries) PopupMenuItem(value: e.key, child: Text(e.value))],
      child: Chip(
        avatar: Icon(Icons.translate_rounded, size: 17, color: context.cs.primary),
        label: Text('${l.answerLanguage}: ${labels[value] ?? value}'),
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
