import 'dart:async';

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

  /// Video is playing (or ready to be considered for PiP) from [HlsPlayerController].
  static bool _playbackWantsPip = false;

  /// [VideoPlayerPage] is the active route (not covered by another screen).
  static bool _videoPageSurfaceActive = false;

  static bool? _lastNativePlayerActive;

  /// Whether the app is currently in PiP mode.
  static final ValueNotifier<bool> isInPipMode = ValueNotifier<bool>(false);

  /// True while the PiP→fullscreen expansion animation is in progress.
  /// Used to prevent false "paused" lifecycle signals from interrupting playback.
  static bool isTransitioningFromPip = false;

  /// After “open app” from PiP, ignore brief landscape metrics that would
  /// auto-trigger in-app fullscreen before portrait lock applies.
  static DateTime? _suppressOrientationDrivenFullscreenUntil;

  static bool get shouldSuppressOrientationDrivenFullscreen =>
      _suppressOrientationDrivenFullscreenUntil != null &&
      DateTime.now().isBefore(_suppressOrientationDrivenFullscreenUntil!);

  /// Call when expanding PiP back to the inline player (not PiP fullscreen).
  static void suppressOrientationDrivenFullscreenTemporarily({
    Duration duration = const Duration(seconds: 2),
  }) {
    _suppressOrientationDrivenFullscreenUntil = DateTime.now().add(duration);
  }

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

        // After PiP ends, lifecycle may be [inactive]/[hidden] briefly while the
        // window restores — that is NOT “dismissed PiP”. Only pause when we are
        // clearly backgrounded ([paused]), or after a deferred check.
        Future.delayed(const Duration(milliseconds: 300), () {
          final lifecycle = WidgetsBinding.instance.lifecycleState;
          debugPrint('PipService: Post-PiP lifecycle = $lifecycle');

          if (lifecycle == AppLifecycleState.resumed) {
            debugPrint('PipService: Post-PiP resumed – ensuring play');
            MediaSyncService().playFromNotification();
            return;
          }
          if (lifecycle == AppLifecycleState.inactive ||
              lifecycle == AppLifecycleState.hidden) {
            debugPrint(
              'PipService: Post-PiP mid-transition ($lifecycle) – defer pause check',
            );
            Future.delayed(const Duration(milliseconds: 800), () {
              final later = WidgetsBinding.instance.lifecycleState;
              debugPrint('PipService: Post-PiP deferred lifecycle = $later');
              if (later == AppLifecycleState.paused) {
                debugPrint('PipService: PiP dismissed in background – pausing');
                MediaSyncService().pauseFromNotification();
              } else if (later == AppLifecycleState.resumed) {
                MediaSyncService().playFromNotification();
              }
            });
            return;
          }
          if (lifecycle == AppLifecycleState.paused) {
            debugPrint('PipService: PiP dismissed – pausing');
            MediaSyncService().pauseFromNotification();
          }
        });
      }
    });
  }

  /// Call from [VideoPlayerPage] when the page becomes the active route again.
  static void setVideoPlayerPageSurfaceActive(bool active) {
    if (_videoPageSurfaceActive == active) return;
    _videoPageSurfaceActive = active;
    unawaited(_syncNativePlayerActive());
  }

  /// Call from [HlsPlayerController] when playback state changes.
  static void setPlaybackWantsPip(bool playing) {
    if (_playbackWantsPip == playing) return;
    _playbackWantsPip = playing;
    unawaited(_syncNativePlayerActive());
  }

  /// Android only: Home / Recents may enter PiP only when this is true —
  /// video is playing **and** the user is on [VideoPlayerPage] (not another route).
  static Future<void> _syncNativePlayerActive() async {
    final want = _playbackWantsPip && _videoPageSurfaceActive;
    if (_lastNativePlayerActive == want) return;
    if (defaultTargetPlatform != TargetPlatform.android) {
      _lastNativePlayerActive = want;
      return;
    }
    try {
      await _channel.invokeMethod('updatePlayerStatus', want);
      _lastNativePlayerActive = want;
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

  /// Restore the app from PiP to the normal window (Android).
  static Future<void> expandFromPip() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        await _channel.invokeMethod('expandFromPip');
        debugPrint('PipService: expandFromPip requested');
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: expandFromPip failed: ${e.message}');
    }
  }
}
