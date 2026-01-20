import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';

/// Service to handle Picture-in-Picture mode via Platform Channels.
class PipService {
  static const MethodChannel _channel = MethodChannel('com.example.hiffi/pip');

  /// Notifier for PiP mode changes.
  static final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  /// Initializes the PiP service and sets up native callbacks.
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPictureInPictureModeChanged') {
        final bool isPip = call.arguments as bool;
        debugPrint('PipService: PiP mode changed to $isPip');

        if (isInPipMode.value == true && isPip == false) {
          debugPrint(
            'PipService: PiP closed or exited, ensuring pause and preparing background',
          );
          // When PiP is closed (swiped away or X), the activity is usually backgrounded.
          // We want to stop the video player and prepare background audio handler so it's ready.
          MediaSyncService().pauseFromNotification();
          MediaSyncService().switchToBackground();
        }

        isInPipMode.value = isPip;
      }
    });
  }

  /// Updates the player status on the native side.
  /// If [active] is true, the native side will allow entering PiP when user leaves the app.
  static Future<void> updatePlayerStatus(bool active) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('updatePlayerStatus', active);
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: Failed to update player status: ${e.message}');
    }
  }

  /// Triggers the native Picture-in-Picture mode.
  static Future<void> enterPiP() async {
    try {
      // Only attempt on Android for now as iOS handles it differently via AVPlayerLayer
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('enterPiP');
        debugPrint('PipService: Successfully requested PiP mode');
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: Failed to enter PiP mode: ${e.message}');
    }
  }
}
