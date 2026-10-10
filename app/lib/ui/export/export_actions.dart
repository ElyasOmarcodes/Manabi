import 'dart:convert';
import 'dart:io' show File;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/chat.dart';
import '../widgets/common.dart';
import 'exporter.dart';
import 'pdf_builder.dart';

bool get _isDesktop => !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.linux);

/// Saves (desktop) or shares/downloads (mobile, web) a generated file.
Future<bool> deliverFile(BuildContext context, Uint8List bytes, String fileName, String mime) async {
  if (_isDesktop) {
    final location = await getSaveLocation(suggestedName: fileName);
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return true;
  }
  if (kIsWeb) {
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, mimeType: mime, name: fileName)], fileNameOverrides: [fileName]));
    return true;
  }
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$fileName'; // mobile only: desktop and web return above
  await File(path).writeAsBytes(bytes, flush: true);
  if (!context.mounted) return false;
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    files: [XFile(path, mimeType: mime)],
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
  return true;
}

Future<void> shareTurnText(BuildContext context, ChatTurn turn) async {
  final text = answerAsText(turn, context.l);
  if (_isDesktop) {
    await copyText(context, text);
    return;
  }
  final box = context.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    text: text,
    subject: turn.question,
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}

Future<void> showExportSheet(BuildContext context, {required String title, required List<ChatTurn> turns, required String uiLanguage}) async {
  final l = context.l;
  final done = turns.where((t) => t.result != null).toList();
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(l.export, style: Theme.of(ctx).textTheme.titleMedium)),
        ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: Text(l.exportPdf), onTap: () => Navigator.pop(ctx, 'pdf')),
        ListTile(leading: const Icon(Icons.code_rounded), title: Text(l.exportMarkdown), subtitle: const Text('.md'), onTap: () => Navigator.pop(ctx, 'md')),
        ListTile(leading: const Icon(Icons.notes_rounded), title: Text(l.exportText), subtitle: const Text('.txt'), onTap: () => Navigator.pop(ctx, 'txt')),
        const SizedBox(height: 12),
      ]),
    ),
  );
  if (choice == null || !context.mounted) return;
  final name = safeFileName(title);
  try {
    final (bytes, ext, mime) = switch (choice) {
      'pdf' => (await buildPdf(title: title, turns: done, l: l, uiLanguage: uiLanguage), 'pdf', 'application/pdf'),
      'md' => (Uint8List.fromList(utf8.encode(turnsAsMarkdown(title, done, l))), 'md', 'text/markdown'),
      _ => (Uint8List.fromList(utf8.encode(turnsAsText(title, done, l))), 'txt', 'text/plain'),
    };
    if (!context.mounted) return;
    final ok = await deliverFile(context, bytes, '$name.$ext', mime);
    if (ok && context.mounted) toast(context, l.exported);
  } catch (e) {
    if (context.mounted) toast(context, l.errGeneric);
  }
}
