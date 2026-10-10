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
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
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
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      bottom: false,
      child: Column(children: [
        _TopBar(chat: chat, wide: wide),
        Expanded(
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.03, 0.95, 1],
            ).createShader(r),
            child: chat == null || chat.turns.isEmpty
                ? _Welcome(configured: settings.isConfigured)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: chat.turns.length,
                    itemBuilder: (context, i) => ReadingWidth(child: _TurnView(turn: chat.turns[i], progress: chats.progress[chat.turns[i].id])),
                  ),
          ),
        ),
        const _Composer(),
        SizedBox(height: wide ? 14 : bottomInset + 4),
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
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Row(children: [
        if (!wide) ...[
          AuraIconButton(icon: Icons.notes_rounded, tooltip: l.chats, onTap: () => Scaffold.of(context).openDrawer()),
          const SizedBox(width: 12),
        ] else
          const SizedBox(width: 8),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(chat?.title ?? l.newChat,
                key: ValueKey(chat?.id),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: uiFont, fontSize: 17, fontWeight: FontWeight.w800, color: a.text)),
          ),
        ),
        if (chat != null && chat!.turns.isNotEmpty) ...[
          AuraIconButton(
            tooltip: l.exportChat,
            icon: Icons.ios_share_rounded,
            onTap: () => showExportSheet(context, title: chat!.title, turns: chat!.turns, uiLanguage: context.read<SettingsController>().uiLanguage),
          ),
          const SizedBox(width: 8),
        ],
        AuraIconButton(tooltip: l.newChat, icon: Icons.add_rounded, onTap: () => context.read<ChatController>().newChat()),
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
    final suggestions = [
      (Icons.format_quote_rounded, l.suggestion1, AuraHues.violet),
      (Icons.balance_rounded, l.suggestion2, AuraHues.cyan),
      (Icons.auto_awesome_rounded, l.suggestion3, AuraHues.pink),
      (Icons.school_rounded, l.suggestion4, AuraHues.amber),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
      child: ReadingWidth(
        maxWidth: 760,
        child: Column(children: [
          const Reveal(child: AuraOrb(size: 150, child: ManabiMark(size: 58))),
          const SizedBox(height: 10),
          Reveal(
            delay: 80,
            child: GradientText(l.welcomeTitle, textAlign: TextAlign.center, style: const TextStyle(fontFamily: uiFont, fontSize: 32, fontWeight: FontWeight.w800, height: 1.4)),
          ),
          const SizedBox(height: 8),
          Reveal(
            delay: 140,
            child: Text(l.welcomeBody, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.85, color: a.muted)),
          ),
          const SizedBox(height: 24),
          if (!configured)
            Reveal(
              delay: 180,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AuraCard(
                  padding: const EdgeInsets.all(14),
                  gradientBorder: true,
                  child: Row(children: [
                    const IconTile(icon: Icons.link_rounded, color: AuraHues.orange, gradient: true),
                    const SizedBox(width: 12),
                    Expanded(child: Text(l.notConfiguredTitle, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700, color: a.text))),
                    Flexible(child: GradientButton(label: l.openSettings, height: 40, gradient: a.warm, onTap: () => nav.go(Section.settings))),
                  ]),
                ),
              ),
            ),
          LayoutBuilder(builder: (context, c) {
            final two = c.maxWidth > 560;
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (final (i, (icon, text, color)) in suggestions.indexed)
                SizedBox(
                  width: two ? (c.maxWidth - 12) / 2 : c.maxWidth,
                  child: Reveal(
                    delay: 220 + i * 70,
                    child: AuraCard(
                      padding: const EdgeInsets.all(16),
                      onTap: () => nav.prefill(text),
                      child: Row(children: [
                        IconTile(icon: icon, color: color, size: 44),
                        const SizedBox(width: 14),
                        Expanded(child: Text(text, style: TextStyle(fontFamily: uiFont, fontSize: 14, height: 1.6, color: a.text, fontWeight: FontWeight.w500))),
                        Icon(Icons.north_east_rounded, size: 18, color: a.faint),
                      ]),
                    ),
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
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Reveal(child: _UserBubble(turn: turn)),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(
            opacity: a,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.03), end: Offset.zero).animate(a), child: child),
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
    final a = context.aura;
    final scope = turn.scope;
    final label = [?scope.bookTitle, ?scope.authorName, ?scope.categoryTitle].join(' · ');
    final dir = Directionality.of(context);
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              gradient: a.brand,
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(24),
                topEnd: Radius.circular(24),
                bottomStart: Radius.circular(24),
                bottomEnd: Radius.circular(8),
              ).resolve(dir),
              boxShadow: [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10), spreadRadius: -10)],
            ),
            child: SelectableText(turn.question, style: const TextStyle(fontFamily: uiFont, color: Colors.white, fontSize: 15.5, height: 1.65, fontWeight: FontWeight.w500)),
          ),
          if (label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.filter_alt_rounded, size: 14, color: a.accent),
                const SizedBox(width: 4),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.accent, fontWeight: FontWeight.w600))),
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
    final a = context.aura;
    return AuraCard(
      padding: const EdgeInsets.all(16),
      color: Color.alphaBlend(a.danger.withValues(alpha: 0.06), a.surface),
      child: Row(children: [
        IconTile(icon: Icons.error_outline_rounded, color: a.danger),
        const SizedBox(width: 12),
        Expanded(child: Text(errorText(l, code), style: TextStyle(fontFamily: uiFont, color: a.text, height: 1.6))),
        const SizedBox(width: 8),
        if (isSetupError(code))
          SoftButton(dense: true, label: l.openSettings, icon: Icons.tune_rounded, onTap: () => context.read<NavController>().go(Section.settings))
        else
          SoftButton(dense: true, label: l.retry, icon: Icons.refresh_rounded, onTap: onRetry),
      ]),
    );
  }
}

/// Input area: scope chips, answer language and the glass message capsule.
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
    final canSend = _controller.text.trim().isNotEmpty;
    final focused = _focus.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
      child: ReadingWidth(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              _ScopeChips(scope: nav.scope),
              _LanguageChip(value: settings.answerLanguage),
            ]),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(1.6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: focused ? a.brand : LinearGradient(colors: [a.border, a.border]),
              boxShadow: [
                BoxShadow(
                  color: focused ? AuraHues.violet.withValues(alpha: 0.28) : a.shadow,
                  blurRadius: focused ? 34 : 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -12,
                ),
              ],
            ),
            child: Glass(
              radius: 30,
              shadow: false,
              border: false,
              color: a.surface.withValues(alpha: a.dark ? 0.9 : 0.96),
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 6, 4),
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
                      style: TextStyle(fontFamily: uiFont, fontSize: 15.5, height: 1.6, color: a.text),
                      decoration: InputDecoration(
                        hintText: l.askPlaceholder,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        counterText: '',
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Tooltip(
                    message: l.send,
                    child: Pressable(
                      onTap: canSend ? _send : null,
                      scale: 0.88,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: canSend ? a.brand : null,
                          color: canSend ? null : a.surfaceAlt,
                          boxShadow: canSend ? [BoxShadow(color: AuraHues.violet.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6), spreadRadius: -4)] : null,
                        ),
                        child: Icon(Icons.arrow_upward_rounded, color: canSend ? Colors.white : a.faint),
                      ),
                    ),
                  ),
                ),
              ]),
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
    Widget gap(Widget w) => Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: w);
    return Row(children: [
      gap(AuraChip(icon: Icons.all_inclusive_rounded, label: l.scopeAll, selected: scope.isAll, onTap: () => nav.setScope(SearchScope.all))),
      gap(AuraChip(
        icon: Icons.category_rounded,
        color: AuraHues.mint,
        label: scope.categoryTitle ?? l.scopeCategory,
        selected: scope.categoryId != null,
        onTap: () async {
          final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
          if (c != null) nav.setScope(scope.withCategory(c.id, c.title));
        },
        onClear: () => nav.setScope(scope.withCategory(null, null)),
      )),
      gap(AuraChip(
        icon: Icons.person_rounded,
        color: AuraHues.pink,
        label: scope.authorName ?? l.scopeAuthor,
        selected: scope.authorId != null,
        onTap: () async {
          final x = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
          if (x != null) nav.setScope(scope.withAuthor(x.id, x.name));
        },
        onClear: () => nav.setScope(scope.withAuthor(null, null)),
      )),
      gap(AuraChip(
        icon: Icons.menu_book_rounded,
        color: AuraHues.blue,
        label: scope.bookTitle ?? l.scopeBook,
        selected: scope.bookId != null,
        onTap: () async {
          final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: scope.authorId, categoryId: scope.categoryId);
          if (b != null) nav.setScope(scope.withBook(b.id, b.title).withAuthor(b.authorId, catalog.author(b.authorId)?.name));
        },
        onClear: () => nav.setScope(scope.withBook(null, null)),
      )),
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
      child: IgnorePointer(child: AuraChip(icon: Icons.translate_rounded, color: AuraHues.orange, label: '${l.answerLanguage}: ${labels[value] ?? value}')),
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
