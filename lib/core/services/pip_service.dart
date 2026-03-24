import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';

/// Service to handle Picture-in-Picture mode via Platform Channels.
///
/// YouTube-style design: the video player is NEVER paused when entering PiP.
/// PiP is just a different window on the same running player.
/// We only pause when PiP is explicitly CLOSED (dismissed) by the user.
class PipService {
  static const MethodChannel _channel = MethodChannel('com.hiffi.app/pip');

  /// Whether the app is currently in PiP mode.
  static final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  /// True while the PiP→fullscreen expansion animation is in progress.
  /// Used to prevent false "paused" lifecycle signals from interrupting playback.
  static bool isTransitioningFromPip = false;

  static void initialize() {
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onPictureInPictureModeChanged') return;

      final bool isPip = call.arguments as bool;
      debugPrint('PipService: PiP mode changed → $isPip');

      if (isPip) {
        // ─── Entering PiP ───────────────────────────────────────────────
        // Keep the player running; just record that we are in PiP.
        isInPipMode.value = true;
        debugPrint('PipService: Entered PiP – player continues uninterrupted');
      } else {
        // ─── Leaving PiP (expand back to full-screen OR closed) ─────────
        isTransitioningFromPip = true;

        // Wait for Flutter's lifecycle to stabilize after the animation.
        Future.delayed(const Duration(milliseconds: 600), () {
          isTransitioningFromPip = false;
          isInPipMode.value = false;
          debugPrint('PipService: PiP transition lock released');
        });

        // After a short delay, check if the app is visible again.
        Future.delayed(const Duration(milliseconds: 300), () {
          final lifecycle = WidgetsBinding.instance.lifecycleState;
          debugPrint('PipService: Post-PiP lifecycle = $lifecycle');

          if (lifecycle == AppLifecycleState.resumed) {
            // User expanded PiP back to full screen – keep playing.
            debugPrint('PipService: Expanded to fullscreen – ensuring play');
            MediaSyncService().playFromNotification();
          } else {
            // PiP window was closed / dismissed – pause cleanly.
            debugPrint('PipService: PiP dismissed – pausing');
            MediaSyncService().pauseFromNotification();
          }
        });
      }
    });
  }

  /// Tells the native side whether a video is active so it can decide
  /// whether to enter PiP when the user presses Home.
  static Future<void> updatePlayerStatus(bool active) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('updatePlayerStatus', active);
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: updatePlayerStatus failed: ${e.message}');
    }
  }

  /// Explicitly enters PiP mode (e.g., when the user taps a PiP button).
  static Future<void> enterPiP() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('enterPiP');
        debugPrint('PipService: enterPiP requested');
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: enterPiP failed: ${e.message}');
    }
  }
}
