import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Keeps the app running while an answer is being prepared, so it is not cut
/// off when the user minimizes the app or switches to another one.
///
/// On Android a foreground service (with a quiet notification) keeps the
/// process and its network connection alive; elsewhere this does nothing and
/// an interrupted answer resumes when the app comes back.
abstract class AnswerKeepAlive {
  factory AnswerKeepAlive.platform() => !kIsWeb && Platform.isAndroid ? AndroidAnswerKeepAlive() : const NoAnswerKeepAlive();

  /// Notification text, in the interface language.
  set labels(({String title, String text}) value);

  void start();
  void stop();
}

class NoAnswerKeepAlive implements AnswerKeepAlive {
  const NoAnswerKeepAlive();
  @override
  set labels(({String title, String text}) value) {}
  @override
  void start() {}
  @override
  void stop() {}
}

class AndroidAnswerKeepAlive implements AnswerKeepAlive {
  bool _wanted = false;
  bool _running = false;
  bool _busy = false;
  bool _initialized = false;
  bool _askedPermission = false;
  ({String title, String text}) _labels = (title: 'Manabi', text: 'Preparing your answer from the sources…');

  @override
  set labels(({String title, String text}) value) => _labels = value;

  void _init() {
    if (_initialized) return;
    _initialized = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'manabi_answers',
        channelName: 'Answers in progress',
        channelDescription: 'Shown while Manabi prepares an answer in the background',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(showNotification: false),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowWifiLock: true,
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
  }

  @override
  void start() {
    _wanted = true;
    _sync();
  }

  @override
  void stop() {
    _wanted = false;
    _sync();
  }

  /// Starts or stops the service to match [_wanted], one call at a time.
  Future<void> _sync() async {
    if (_busy) return;
    _busy = true;
    try {
      while (_wanted != _running) {
        if (_wanted) {
          _init();
          if (!_askedPermission) {
            _askedPermission = true;
            // Without it the service still runs; only the notification is hidden.
            if (await FlutterForegroundTask.checkNotificationPermission() != NotificationPermission.granted) {
              await FlutterForegroundTask.requestNotificationPermission();
            }
          }
          final result = await FlutterForegroundTask.startService(
            serviceId: 7101,
            serviceTypes: const [ForegroundServiceTypes.dataSync],
            notificationTitle: _labels.title,
            notificationText: _labels.text,
          );
          _running = result is ServiceRequestSuccess || await FlutterForegroundTask.isRunningService;
          if (!_running) break;
        } else {
          await FlutterForegroundTask.stopService();
          _running = false;
        }
      }
    } catch (e) {
      debugPrint('keep-alive: $e');
    } finally {
      _busy = false;
    }
  }
}
