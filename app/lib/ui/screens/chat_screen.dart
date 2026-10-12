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
import '../widgets/suggestion_pool.dart';
import '../widgets/answer_card.dart';
import '../widgets/brand_logo.dart';
import '../widgets/common.dart';
import '../widgets/depth_picker.dart';
import '../widgets/message_sheet.dart';
import '../widgets/research_progress.dart';
import '../widgets/scope_picker.dart';

/// Chat page in the familiar ChatGPT layout: a quiet top bar, the
/// conversation, and one composer at the bottom.
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
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: chat.turns.length,
                  itemBuilder: (context, i) => ReadingWidth(maxWidth: 740, child: _TurnView(chat: chat, turn: chat.turns[i], progress: chats.progress[chat.turns[i].id])),
                ),
        ),
        if (empty) const _Suggestions(),
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
    final hasTurns = chat != null && chat!.turns.isNotEmpty;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(children: [
          if (!wide) RoundIconButton(icon: Icons.notes_rounded, tooltip: l.chats, onTap: () => Scaffold.of(context).openDrawer()) else const SizedBox(width: 8),
          const SizedBox(width: 10),
          Expanded(
            child: hasTurns
                ? Tooltip(
                    message: l.chatDetails,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => showChatDetails(context, chat!),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(chat!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: wide ? TextAlign.start : TextAlign.center,
                            style: TextStyle(fontFamily: uiFont, fontSize: 15, fontWeight: FontWeight.w600, color: a.text)),
                      ),
                    ),
                  )
                : (wide ? const SizedBox() : const Center(child: BrandLogo(height: 26, latin: false))),
          ),
          const SizedBox(width: 10),
          if (hasTurns) ...[
            RoundIconButton(
              tooltip: l.exportChat,
              icon: Icons.ios_share_rounded,
              filled: false,
              onTap: () => showExportSheet(context, title: chat!.title, turns: chat!.turns, uiLanguage: context.read<SettingsController>().uiLanguage),
            ),
            const SizedBox(width: 4),
          ],
          RoundIconButton(tooltip: l.newChat, icon: Icons.edit_square, onTap: () => context.read<ChatController>().newChat()),
        ]),
      ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AnimatedBrandLogo(height: 64),
          const SizedBox(height: 18),
          Reveal(
            delay: 80,
            child: Text(l.welcomeQuestion, textAlign: TextAlign.center, style: TextStyle(fontFamily: uiFont, fontSize: 19, fontWeight: FontWeight.w600, color: a.text, height: 1.5)),
          ),
          if (!configured)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Pressable(
                onTap: () => openSection(context, Section.settings),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.link_rounded, size: 17, color: a.accent),
                    const SizedBox(width: 8),
                    Flexible(child: Text(l.notConfiguredTitle, style: TextStyle(fontFamily: uiFont, fontSize: 13.5, fontWeight: FontWeight.w600, color: a.accent))),
                  ]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

/// Starter questions as a horizontal row of small filled cards above the
/// composer: a different mix each time, with a button for another mix.
class _Suggestions extends StatefulWidget {
  const _Suggestions();
  @override
  State<_Suggestions> createState() => _SuggestionsState();
}

class _SuggestionsState extends State<_Suggestions> {
  List<(String, SuggestionKind)>? _items;
  String? _language;
  int _round = 0;

  static (IconData, Color) _look(SuggestionKind k) => switch (k) {
        SuggestionKind.hadith => (Icons.format_quote_rounded, AuraHues.amber),
        SuggestionKind.fiqh => (Icons.balance_rounded, AuraHues.green),
        SuggestionKind.aqidah => (Icons.auto_awesome_rounded, AuraHues.violet),
        SuggestionKind.tafsir => (Icons.menu_book_rounded, AuraHues.blue),
        SuggestionKind.history => (Icons.history_edu_rounded, AuraHues.rose),
        SuggestionKind.ethics => (Icons.school_rounded, AuraHues.teal),
      };

  void _pick(SettingsController settings) {
    _language = settings.uiLanguage;
    _items = pickSuggestions(settings.uiLanguage, fixed: settings.fixedSuggestions);
  }

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    final nav = context.read<NavController>();
    final settings = context.watch<SettingsController>();
    if (_items == null || _language != settings.uiLanguage) _pick(settings);
    final items = _items!;
    return ReadingWidth(
      maxWidth: 788,
      child: SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: items.length + 1,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            if (i == items.length) {
              return Center(
                child: Tooltip(
                  message: l.moreSuggestions,
                  child: Pressable(
                    onTap: () => setState(() {
                      _round++;
                      _items = pickSuggestions(settings.uiLanguage);
                    }),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(color: a.surfaceAlt, shape: BoxShape.circle),
                      child: Icon(Icons.refresh_rounded, size: 20, color: a.muted),
                    ),
                  ),
                ),
              );
            }
            final (text, kind) = items[i];
            final (icon, color) = _look(kind);
            return Reveal(
              key: ValueKey('$_round-$i'),
              delay: 60 + i * 40,
              child: Pressable(
                onTap: () => nav.prefill(text),
                child: Container(
                  width: 232,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.topStart,
                      end: AlignmentDirectional.bottomEnd,
                      colors: [color.withValues(alpha: a.dark ? 0.20 : 0.13), color.withValues(alpha: a.dark ? 0.08 : 0.05)],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(color: color.withValues(alpha: a.dark ? 0.28 : 0.18), shape: BoxShape.circle),
                      child: Icon(icon, size: 17, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 13, height: 1.5, color: a.text))),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.chat, required this.turn, required this.progress});
  final Chat chat;
  final ChatTurn turn;
  final AskProgress? progress;

  @override
  Widget build(BuildContext context) {
    final chats = context.read<ChatController>();
    final settings = context.read<SettingsController>();
    void retry() => chats.retry(turn, fallbackLanguage: settings.uiLanguage, depth: settings.researchDepth);
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        GestureDetector(
          onLongPress: () => showMessageSheet(context, chat: chat, turn: turn, question: true),
          onSecondaryTap: () => showMessageSheet(context, chat: chat, turn: turn, question: true),
          child: _UserBubble(turn: turn),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 380),
          switchInCurve: Curves.easeOutCubic,
          transitionBuilder: (child, a) => FadeTransition(opacity: a, child: child),
          layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.topStart, children: [...previous, ?current]),
          child: switch (turn.state) {
            MessageState.pending => ResearchProgress(key: const ValueKey('p'), progress: progress ?? AskProgress(), rtlDraft: isRtlLanguage(turn.language)),
            MessageState.done when turn.result != null => GestureDetector(
                key: ValueKey('a${turn.id}'),
                onLongPress: () => showMessageSheet(context, chat: chat, turn: turn, question: false),
                onSecondaryTap: () => showMessageSheet(context, chat: chat, turn: turn, question: false),
                child: AnswerCard(turn: turn, onRetry: retry, onMore: () => showMessageSheet(context, chat: chat, turn: turn, question: false)),
              ),
            _ => _ErrorLine(key: const ValueKey('e'), code: turn.errorCode, detail: turn.errorDetail, onRetry: retry),
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(22)),
            child: Text(turn.question, style: TextStyle(fontFamily: uiFont, color: a.text, fontSize: 15, height: 1.6)),
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
  const _ErrorLine({super.key, required this.code, this.detail, required this.onRetry});
  final String? code;
  final String? detail;
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
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(detail!, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.ltr, style: TextStyle(fontFamily: uiFont, fontSize: 11.5, color: a.faint, height: 1.4)),
            ),
          const SizedBox(height: 6),
          if (isSetupError(code))
            SoftButton(dense: true, label: l.openSettings, icon: Icons.tune_rounded, onTap: () => openSection(context, Section.settings))
          else
            SoftButton(dense: true, label: l.retry, icon: Icons.refresh_rounded, onTap: onRetry),
        ]),
      ),
    ]);
  }
}

/// ChatGPT-style composer: + on one side, the text in the middle, research
/// depth and send on the other; chosen options show as pills above the text.
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
    await context.read<ChatController>().ask(text, language: settings.answerLanguage, fallbackLanguage: settings.uiLanguage, scope: nav.scope, depth: settings.researchDepth);
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
    final deepOrQuick = settings.researchDepth != 'standard';
    final pills = [
      if (scopeLabel.isNotEmpty) _Pill(icon: Icons.filter_list_rounded, label: scopeLabel, onTap: () => showOptionsSheet(context), onClear: () => nav.setScope(SearchScope.all)),
      if (langLabel != null) _Pill(icon: Icons.translate_rounded, label: langLabel, onTap: () => showOptionsSheet(context), onClear: () => settings.setAnswerLanguage('auto')),
      if (deepOrQuick)
        _Pill(icon: depthIcon(settings.researchDepth), label: depthLabel(l, settings.researchDepth), onTap: () => showDepthSheet(context), onClear: () => settings.setResearchDepth('standard')),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: ReadingWidth(
        maxWidth: 760,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: a.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _focus.hasFocus ? a.faint.withValues(alpha: 0.6) : a.border),
            boxShadow: [BoxShadow(color: a.shadow, blurRadius: 18, offset: const Offset(0, 6), spreadRadius: -10)],
          ),
          padding: const EdgeInsets.all(6),
          // Lines added or removed (and the pills above) resize the box smoothly.
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (pills.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 4, 6, 2),
                child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: pills)),
              ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              RoundIconButton(icon: Icons.add_rounded, tooltip: l.options, size: 40, filled: false, onTap: () => showOptionsSheet(context)),
              Expanded(
                child: CallbackShortcuts(
                  // Enter starts a new line; Ctrl/⌘+Enter sends.
                  bindings: {
                    const SingleActivator(LogicalKeyboardKey.enter, control: true): _send,
                    const SingleActivator(LogicalKeyboardKey.enter, meta: true): _send,
                  },
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 6,
                    maxLength: 2000,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.55, color: a.text),
                    decoration: InputDecoration(
                      hintText: l.askPlaceholder,
                      hintMaxLines: 1,
                      filled: false,
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    ),
                  ),
                ),
              ),
              RoundIconButton(
                icon: depthIcon(settings.researchDepth),
                tooltip: '${l.researchDepth}: ${depthLabel(l, settings.researchDepth)}',
                size: 40,
                filled: false,
                color: deepOrQuick ? a.accent : a.muted,
                onTap: () => showDepthSheet(context),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: busy ? l.stop : l.send,
                child: Pressable(
                  onTap: busy ? () => context.read<ChatController>().cancel(widget.pending!) : (canSend ? _send : null),
                  scale: 0.88,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: busy || canSend ? a.text : a.surfaceAlt),
                    child: Icon(busy ? Icons.stop_rounded : Icons.arrow_upward_rounded, size: 20, color: busy || canSend ? a.bg : a.faint),
                  ),
                ),
              ),
            ]),
          ]),
          ),
        ),
      ),
    );
  }
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
          padding: const EdgeInsetsDirectional.fromSTEB(10, 5, 6, 5),
          decoration: BoxDecoration(color: a.accentTint, borderRadius: BorderRadius.circular(16)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: a.accent),
            const SizedBox(width: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w600, color: a.accent)),
            ),
            const SizedBox(width: 2),
            GestureDetector(onTap: onClear, child: Icon(Icons.close_rounded, size: 15, color: a.accent)),
          ]),
        ),
      ),
    );
  }
}

Future<void> showOptionsSheet(BuildContext context) => showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => const _OptionsSheet());

/// "+" sheet: where to search (tiles) and the answer options (rows).
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
    final tiles = [
      (Icons.all_inclusive_rounded, l.scopeAll, null as String?, AuraHues.violet, scope.isAll, () => nav.setScope(SearchScope.all)),
      (Icons.category_outlined, l.scopeCategory, scope.categoryTitle, AuraHues.blue, scope.categoryTitle != null, () async {
        final c = await pickFromCatalog<CatalogCategory>(context, PickKind.category);
        if (c != null) nav.setScope(scope.withCategory(c.id, c.title));
      }),
      (Icons.person_outline_rounded, l.scopeAuthor, scope.authorName, AuraHues.amber, scope.authorName != null, () async {
        final x = await pickFromCatalog<CatalogAuthor>(context, PickKind.author);
        if (x != null) nav.setScope(scope.withAuthor(x.id, x.name));
      }),
      (Icons.menu_book_outlined, l.scopeBook, scope.bookTitle, AuraHues.teal, scope.bookTitle != null, () async {
        final b = await pickFromCatalog<CatalogBook>(context, PickKind.book, authorId: scope.authorId, categoryId: scope.categoryId);
        if (b != null) nav.setScope(scope.withBook(b.id, b.title).withAuthor(b.authorId, catalog.author(b.authorId)?.name));
      }),
    ];
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: ReadingWidth(
          maxWidth: 620,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 10),
              child: Text(l.scopeTitle, style: TextStyle(fontFamily: uiFont, fontSize: 13, fontWeight: FontWeight.w600, color: a.muted)),
            ),
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 440 ? 4 : 2;
              final w = (c.maxWidth - 8 * (cols - 1)) / cols;
              return Wrap(spacing: 8, runSpacing: 8, children: [
                for (final (icon, title, value, color, selected, onTap) in tiles)
                  SizedBox(
                    width: w,
                    child: Pressable(
                      onTap: onTap,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 92,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selected ? a.accentTint : a.surfaceAlt,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: selected ? a.accent : Colors.transparent, width: 1.4),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Icon(icon, size: 22, color: color),
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: uiFont, fontSize: 14, fontWeight: FontWeight.w600, color: a.text)),
                            if (value != null)
                              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: arabicStyle(context, size: 12.5, color: a.accent).copyWith(height: 1.4)),
                          ]),
                        ]),
                      ),
                    ),
                  ),
              ]);
            }),
            const SizedBox(height: 14),
            Material(
              color: a.surfaceAlt,
              clipBehavior: Clip.antiAlias,
              borderRadius: BorderRadius.circular(18),
              child: Column(children: [
                SettingsRow(
                  icon: depthIcon(settings.researchDepth),
                  color: AuraHues.violet,
                  title: l.researchDepth,
                  value: depthLabel(l, settings.researchDepth),
                  onTap: () => showDepthSheet(context),
                ),
                Divider(height: 1, indent: 58, color: a.border),
                SettingsRow(
                  icon: Icons.translate_rounded,
                  color: AuraHues.amber,
                  title: l.answerLanguage,
                  value: labels[settings.answerLanguage],
                  onTap: () async {
                    final v = await showChoiceDialog(context, title: l.answerLanguage, options: labels, selected: settings.answerLanguage);
                    if (v != null) await settings.setAnswerLanguage(v);
                  },
                ),
                Divider(height: 1, indent: 58, color: a.border),
                SettingsRow(
                  icon: Icons.auto_stories_outlined,
                  color: AuraHues.teal,
                  title: l.openLibrary,
                  subtitle: l.openLibrarySub,
                  onTap: () {
                    final navigator = Navigator.of(context)..pop();
                    navigator.push(MaterialPageRoute(builder: (_) => sectionPage(Section.library)));
                  },
                ),
              ]),
            ),
          ]),
        ),
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
