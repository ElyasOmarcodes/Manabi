import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

/// Opens the app's database in the platform's own folder for app data:
/// the app's private storage on Android and iOS, %APPDATA% on Windows,
/// ~/Library/Application Support on macOS, ~/.local/share on Linux, and
/// IndexedDB on the web. Data from earlier versions (kept under Documents)
/// is moved there once.
Future<String?> initAppStorage() async {
  if (kIsWeb) {
    await Hive.initFlutter('manabi');
    return null;
  }
  final support = await getApplicationSupportDirectory();
  final dir = Directory('${support.path}${Platform.pathSeparator}manabi');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
    try {
      final old = Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}manabi');
      if (old.existsSync() && old.path != dir.path) {
        for (final f in old.listSync().whereType<File>()) {
          f.copySync('${dir.path}${Platform.pathSeparator}${f.uri.pathSegments.last}');
        }
      }
    } catch (e) {
      debugPrint('storage move: $e');
    }
  }
  Hive.init(dir.path);
  return dir.path;
}
