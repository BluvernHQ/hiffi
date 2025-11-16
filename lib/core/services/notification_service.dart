import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService();

  static const String _uploadChannelId = 'video_upload_channel';
  static const String _uploadChannelName = 'Video Uploads';
  static const String _uploadChannelDescription =
      'Notifications about background video uploads';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();

    final settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    final androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    const channel = AndroidNotificationChannel(
      _uploadChannelId,
      _uploadChannelName,
      description: _uploadChannelDescription,
      importance: Importance.high,
    );
    await androidPlugin?.createNotificationChannel(channel);

    _initialized = true;
  }

  Future<void> showProgress({
    required String taskId,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      _uploadChannelId,
      _uploadChannelName,
      channelDescription: _uploadChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      showProgress: true,
      maxProgress: maxProgress,
      progress: progress.clamp(0, maxProgress),
      onlyAlertOnce: true,
    );

    await _plugin.show(
      taskId.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> showCompletion({
    required String taskId,
    required String title,
    required String body,
    required bool success,
  }) async {
    await initialize();

    final androidDetails = AndroidNotificationDetails(
      _uploadChannelId,
      _uploadChannelName,
      channelDescription: _uploadChannelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: !kIsWeb,
    );

    await _plugin.show(
      taskId.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails),
    );
  }

  Future<void> cancel(String taskId) async {
    await initialize();
    await _plugin.cancel(taskId.hashCode);
  }
}
