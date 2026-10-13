import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../state/reading_controller.dart';
import '../theme.dart';
import 'common.dart';

/// Where text-error reports go: the developer's contacts, unless a build sets
/// `--dart-define=MANABI_REPORT_WHATSAPP=…` / `MANABI_REPORT_EMAIL=…` (an
/// empty define, as CI passes when the variable is unset, keeps these).
const _whatsAppDefine = String.fromEnvironment('MANABI_REPORT_WHATSAPP');
const _emailDefine = String.fromEnvironment('MANABI_REPORT_EMAIL');
const reportWhatsApp = _whatsAppDefine == '' ? '98766465848' : _whatsAppDefine;
const reportEmail = _emailDefine == '' ? 'ElyasOmar100@gmail.com' : _emailDefine;

/// The colour of a highlight that carries a comment.
const commentColor = Color(0xFFB794F6);

/// The reader's selection menu, icons only (like Turath's): four highlight
/// colours, copy, copy with the source, comment, report an error, and —
/// when the selection is on a saved mark — remove it or its comment.
class SelectionToolbar extends StatelessWidget {
  const SelectionToolbar({
    super.key,
    required this.anchors,
    required this.onColor,
    required this.onCopy,
    required this.onCopyCite,
    required this.onComment,
    required this.onReport,
    this.marked = const [],
    this.onRemove,
    this.onDeleteComment,
  });
  final TextSelectionToolbarAnchors anchors;
  final ValueChanged<int> onColor;
  final VoidCallback onCopy;
  final VoidCallback onCopyCite;
  final VoidCallback onComment;
  final VoidCallback onReport;

  /// Saved highlights under the selection.
  final List<Highlight> marked;
  final VoidCallback? onRemove;
  final VoidCallback? onDeleteComment;

  static const _padding = 8.0;

  @override
  Widget build(BuildContext context) {
    final a = context.aura;
    final l = context.l;
    final top = MediaQuery.paddingOf(context).top + _padding;
    final adjust = Offset(_padding, top);
    final colored = marked.where((h) => h.note == null).map((h) => h.color).toSet();
    final commented = marked.any((h) => h.note != null);
    Widget icon(IconData i, String tip, VoidCallback onTap, {Color? color}) => IconButton(
          tooltip: tip,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          icon: Icon(i, size: 20, color: color ?? a.text),
          onPressed: onTap,
        );
    Widget sep() => Container(width: 1, height: 22, margin: const EdgeInsets.symmetric(horizontal: 4), color: a.border);
    final bar = Material(
      color: a.surface,
      elevation: 8,
      shadowColor: a.shadow,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), border: Border.all(color: a.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < highlightColors.length; i++)
            Tooltip(
              message: l.highlight,
              child: InkResponse(
                onTap: () => onColor(i),
                radius: 18,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: highlightColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(color: colored.contains(i) ? a.text : Colors.white.withValues(alpha: 0.7), width: colored.contains(i) ? 2 : 1.5),
                    ),
                    child: colored.contains(i) ? Icon(Icons.check_rounded, size: 14, color: a.text) : null,
                  ),
                ),
              ),
            ),
          sep(),
          icon(Icons.copy_rounded, l.copy, onCopy),
          icon(Icons.format_quote_rounded, l.copyWithCitation, onCopyCite),
          icon(commented ? Icons.edit_note_rounded : Icons.add_comment_outlined, commented ? l.editComment : l.addComment, onComment, color: commentColor),
          icon(Icons.flag_outlined, l.reportError, onReport, color: AuraHues.rose),
          if (onRemove != null && colored.isNotEmpty) ...[sep(), icon(Icons.format_color_reset_outlined, l.removeHighlight, onRemove!, color: a.muted)],
          if (onDeleteComment != null && commented) ...[if (colored.isEmpty) sep(), icon(Icons.speaker_notes_off_outlined, l.deleteComment, onDeleteComment!, color: a.muted)],
        ]),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(_padding, top, _padding, _padding),
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          anchorAbove: anchors.primaryAnchor - adjust - const Offset(0, 6),
          anchorBelow: (anchors.secondaryAnchor ?? anchors.primaryAnchor) - adjust + const Offset(0, 26),
        ),
        child: FittedBox(fit: BoxFit.scaleDown, child: bar),
      ),
    );
  }
}

/// Asks for a comment on a passage; null when cancelled.
Future<String?> askComment(BuildContext context, {String initial = ''}) {
  final l = context.l;
  final field = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.mode_comment_outlined, color: commentColor),
      title: Text(initial.isEmpty ? l.addComment : l.editComment, style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w700)),
      content: TextField(
        controller: field,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        maxLength: 1000,
        decoration: InputDecoration(hintText: l.commentHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.of(context).pop(field.text.trim()), child: Text(l.save)),
      ],
    ),
  ).whenComplete(field.dispose);
}

/// A tapped comment: the note, with edit and delete.
Future<void> showCommentSheet(BuildContext context, Highlight h, {required VoidCallback onEdit, required VoidCallback onDelete}) {
  final l = context.l;
  final a = context.aura;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.mode_comment_rounded, color: commentColor, size: 20),
            const SizedBox(width: 8),
            Text(l.comment, style: TextStyle(fontFamily: uiFont, fontSize: 16, fontWeight: FontWeight.w800, color: a.text)),
          ]),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: commentColor.withValues(alpha: a.dark ? 0.16 : 0.12), borderRadius: BorderRadius.circular(14)),
            child: Text(h.text, maxLines: 3, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl, style: arabicStyle(sheet, size: 15).copyWith(height: 1.8)),
          ),
          const SizedBox(height: 12),
          SelectableText(h.note ?? '', style: TextStyle(fontFamily: uiFont, fontSize: 15, height: 1.7, color: a.text)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: SoftButton(
                icon: Icons.edit_note_rounded,
                color: commentColor,
                label: l.editComment,
                onTap: () {
                  Navigator.of(sheet).pop();
                  onEdit();
                },
              ),
            ),
            const SizedBox(width: 8),
            SoftButton(
              icon: Icons.delete_outline_rounded,
              color: AuraHues.rose,
              label: l.delete,
              onTap: () {
                Navigator.of(sheet).pop();
                onDelete();
              },
            ),
          ]),
        ]),
      ),
    ),
  );
}

/// A form for a text error: the selection (filled in), where it is, and a
/// description, sent by WhatsApp or e-mail to the developer.
Future<void> showReportSheet(BuildContext context, {required String text, required String location}) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReportSheet(text: text, location: location),
    );

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.text, required this.location});
  final String text;
  final String location;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _what = TextEditingController();

  @override
  void dispose() {
    _what.dispose();
    super.dispose();
  }

  String get _body {
    final l = context.l;
    return '${l.reportSubject}\n\n${l.reportLocation}: ${widget.location}\n\n${l.selectedText}:\n«${widget.text}»\n\n${l.errorDescription}:\n${_what.text.trim()}';
  }

  Future<void> _open(Uri uri) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l = context.l;
    var ok = false;
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok) {
      messenger?.showSnackBar(SnackBar(content: Text(l.couldNotOpen)));
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _whatsApp() {
    final number = reportWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
    _open(Uri.parse('https://wa.me/$number?text=${Uri.encodeComponent(_body)}'));
  }

  void _email() => _open(Uri(scheme: 'mailto', path: reportEmail, query: 'subject=${Uri.encodeComponent(context.l.reportSubject)}&body=${Uri.encodeComponent(_body)}'));

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final a = context.aura;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.flag_rounded, color: AuraHues.rose, size: 20),
              const SizedBox(width: 8),
              Text(l.reportError, style: TextStyle(fontFamily: uiFont, fontSize: 16.5, fontWeight: FontWeight.w800, color: a.text)),
            ]),
            const SizedBox(height: 4),
            Text(l.reportErrorInfo, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, height: 1.6, color: a.muted)),
            const SizedBox(height: 12),
            Text(l.selectedText, style: TextStyle(fontFamily: uiFont, fontSize: 12.5, fontWeight: FontWeight.w700, color: a.muted)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(color: a.surfaceAlt, borderRadius: BorderRadius.circular(14)),
              child: SingleChildScrollView(child: Text(widget.text, textDirection: TextDirection.rtl, style: arabicStyle(context, size: 15).copyWith(height: 1.8))),
            ),
            const SizedBox(height: 6),
            Text('${l.reportLocation}: ${widget.location}', style: TextStyle(fontFamily: uiFont, fontSize: 12, color: a.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: _what,
              autofocus: true,
              minLines: 2,
              maxLines: 6,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(labelText: l.errorDescription, hintText: l.errorDescriptionHint),
            ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: SoftButton(icon: Icons.chat_rounded, color: AuraHues.green, label: l.sendWhatsApp, onTap: _what.text.trim().isEmpty ? null : _whatsApp)),
              const SizedBox(width: 8),
              Expanded(child: SoftButton(icon: Icons.mail_outline_rounded, color: AuraHues.rose, label: l.sendEmail, onTap: _what.text.trim().isEmpty ? null : _email)),
            ]),
          ]),
        ),
      ),
    );
  }
}
