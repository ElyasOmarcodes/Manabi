import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/backend/backend.dart';
import '../../state/downloads.dart';
import '../../state/settings_controller.dart';
import '../theme.dart';
import 'common.dart';

/// Starts saving a book for offline reading; reports failures as a toast.
Future<void> saveBookOffline(BuildContext context, String bookId, String title) async {
  final downloads = context.read<DownloadController>();
  final backend = context.read<SettingsController>().backend;
  final l = context.l;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await downloads.download(backend, bookId, title);
    if (downloads.isSaved(bookId)) {
      messenger?.showSnackBar(SnackBar(content: Text(l.savedOffline), duration: const Duration(seconds: 2)));
    }
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text(errorText(l, mapError(e).code)), duration: const Duration(seconds: 3)));
  }
}

/// Save / progress + stop / saved + remove, for one book.
class SaveOfflineButton extends StatelessWidget {
  const SaveOfflineButton({super.key, required this.bookId, required this.title, this.dense = false});
  final String bookId;
  final String title;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadController>();
    final l = context.l;
    final a = context.aura;
    final progress = downloads.progressOf(bookId);
    if (progress != null) {
      return Container(
        padding: EdgeInsets.fromLTRB(16, dense ? 4 : 10, 8, dense ? 4 : 10),
        decoration: BoxDecoration(color: AuraHues.teal.withValues(alpha: a.dark ? 0.16 : 0.09), borderRadius: BorderRadius.circular(22)),
        child: Row(children: [
          const Icon(Icons.download_rounded, size: 18, color: AuraHues.teal),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(l.savingOffline((progress * 100).round()), style: TextStyle(fontFamily: uiFont, fontWeight: FontWeight.w600, fontSize: 13.5, color: AuraHues.teal)),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AuraProgress(value: progress == 0 ? null : progress, width: double.infinity, height: 4, color: AuraHues.teal),
              ),
            ]),
          ),
          TextButton(onPressed: () => downloads.cancel(bookId), child: Text(l.stopDownload)),
        ]),
      );
    }
    final saved = downloads.saved(bookId);
    if (saved != null && saved.complete) {
      return Row(children: [
        Expanded(child: SoftButton(dense: dense, icon: Icons.offline_pin_rounded, color: AuraHues.teal, label: l.savedOffline)),
        const SizedBox(width: 8),
        SoftButton(dense: dense, icon: Icons.delete_outline_rounded, color: AuraHues.rose, label: dense ? '' : l.removeDownload, onTap: () => downloads.remove(bookId)),
      ]);
    }
    return SoftButton(
      dense: dense,
      icon: Icons.download_for_offline_outlined,
      color: AuraHues.teal,
      // A stopped download resumes from the pages already kept.
      label: saved == null ? l.saveOffline : '${l.saveOffline} · ${(saved.pages * 100 / (saved.total == 0 ? 1 : saved.total)).round()}%',
      onTap: () => saveBookOffline(context, bookId, title),
    );
  }
}
