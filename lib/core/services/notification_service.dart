import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  bool _pluginActuallyInitialized = false;

  Future<void> initialize({bool skipPermissionRequest = false}) async {
    if (_initialized) return;

    // In background workers, skip initialization entirely to avoid PlatformException
    // The plugin requires Activity context which isn't available in background workers
    if (skipPermissionRequest) {
      debugPrint(
        'Skipping notification plugin initialization (background worker - no Activity context)',
      );
      _initialized = true;
      _pluginActuallyInitialized = false; // Plugin not actually initialized
      return;
    }

    try {
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const iosSettings = DarwinInitializationSettings();

      final settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      // Initialize plugin - this might internally try to request permissions
      // so we catch any errors, especially PlatformException in background workers
      try {
        await _plugin.initialize(settings);
        _pluginActuallyInitialized = true; // Successfully initialized
      } on PlatformException catch (e) {
        // PlatformException occurs when plugin tries to access Android context
        // in background workers (no Activity context available)
        // This is expected in background workers, so we continue
        debugPrint(
          'Plugin initialization PlatformException (expected in background): ${e.message}',
        );
        _pluginActuallyInitialized = false; // Failed to initialize
      } catch (e) {
        // If initialization fails due to other issues, continue anyway
        // The plugin might still work for showing notifications
        debugPrint('Plugin initialization warning: $e');
        _pluginActuallyInitialized = false; // Failed to initialize
      }

      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      // Skip permission request in background workers (they don't have Activity context)
      if (!skipPermissionRequest) {
        try {
          await androidPlugin?.requestNotificationsPermission();
        } catch (e) {
          // Ignore permission errors - they may occur in background context
          // Permissions should be requested from the main app
          debugPrint('Could not request notification permission: $e');
        }
      } else {
        // In background workers, we still need to create the channel
        // but we skip permission requests
        debugPrint(
          'Skipping notification permission request (background worker)',
        );
      }

      // Create notification channel (this should work even without permissions)
      try {
        const channel = AndroidNotificationChannel(
          _uploadChannelId,
          _uploadChannelName,
          description: _uploadChannelDescription,
          importance: Importance.high,
        );
        await androidPlugin?.createNotificationChannel(channel);
      } catch (e) {
        // Channel creation might fail in background, but that's okay
        // The channel might already exist or will be created when needed
        debugPrint('Could not create notification channel: $e');
      }

      _initialized = true;
    } catch (e, stackTrace) {
      // If initialization fails completely, log but don't throw
      // This allows the app to continue even if notifications aren't available
      debugPrint('Notification service initialization error: $e');
      debugPrint('Stack trace: $stackTrace');
      // Still mark as initialized to prevent retry loops
      _initialized = true;
      _pluginActuallyInitialized = false; // Failed to initialize
    }
  }

  Future<void> showProgress({
    required String taskId,
    required String title,
    required String body,
    required int progress,
    required int maxProgress,
  }) async {
    await initialize();

    // Skip if plugin wasn't actually initialized (e.g., in background worker)
    if (!_pluginActuallyInitialized) return;

    try {
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
    } catch (e) {
      // Silently fail - notifications are optional
      debugPrint('Failed to show progress notification: $e');
    }
  }

  Future<void> showCompletion({
    required String taskId,
    required String title,
    required String body,
    required bool success,
  }) async {
    await initialize();

    // Skip if plugin wasn't actually initialized (e.g., in background worker)
    if (!_pluginActuallyInitialized) return;

    try {
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
    } catch (e) {
      // Silently fail - notifications are optional
      debugPrint('Failed to show completion notification: $e');
    }
  }

  Future<void> cancel(String taskId) async {
    await initialize();
    await _plugin.cancel(taskId.hashCode);
  }
}
