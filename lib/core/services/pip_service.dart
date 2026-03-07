import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';

/// Service to handle Picture-in-Picture mode via Platform Channels.
class PipService {
  static const MethodChannel _channel = MethodChannel('com.hiffi.app/pip');

  /// Notifier for PiP mode changes.
  static final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  /// Flag to prevent background audio switch during PiP expansion.
  static bool isTransitioningFromPip = false;

  /// Initializes the PiP service and sets up native callbacks.
  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPictureInPictureModeChanged') {
        final bool isPip = call.arguments as bool;
        debugPrint('PipService: PiP mode changed to $isPip');

        if (isInPipMode.value && !isPip) {
          // 💡 EXPANSION/CLOSING detected
          isTransitioningFromPip = true;

          // Keep isInPipMode true for a while to lock MediaSyncService
          // until lifecycle states stabilize.
          Future.delayed(const Duration(milliseconds: 1000), () {
            isTransitioningFromPip = false;
            isInPipMode.value = false;
            debugPrint('PipService: Transition lock released');
          });

          // Determine if we are expanding or closing.
          Future.delayed(const Duration(milliseconds: 500), () {
            final state = WidgetsBinding.instance.lifecycleState;
            debugPrint('PipService: Exited PiP check, current state: $state');

            final isClosing = state != AppLifecycleState.resumed;

            if (isClosing) {
              debugPrint('PipService: PiP closed, ensuring pause');
              MediaSyncService().pauseFromNotification();
              MediaSyncService().switchToBackground();
            } else {
              debugPrint('PipService: PiP expanded, forcing play');
              // Force play to ensure any accidental lifecycle pauses are overridden
              MediaSyncService().playFromNotification();
            }
          });
        } else {
          // 💡 ENTERING PiP or other state
          isInPipMode.value = isPip;
        }
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
