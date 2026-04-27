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

  /// After an inline player swap, native PiP briefly ends before the new layer
  /// exists. Keep in-app PiP / mini-player chrome and loaders until playback resumes.
  static final ValueNotifier<bool> pipUiHeldUntilReconnect =
      ValueNotifier<bool>(false);

  /// Listenable for widgets that should treat “PiP chrome” as visible when either
  /// native PiP is active or we are holding UI through a player swap.
  static Listenable get pipChromeListenable => Listenable.merge([
        isInPipMode,
        pipUiHeldUntilReconnect,
      ]);

  static bool get showPipChrome =>
      isInPipMode.value || pipUiHeldUntilReconnect.value;

  /// Clears [pipUiHeldUntilReconnect] once the new clip is actually playing.
  static void clearPipUiHoldWhenPlaybackResumes() {
    if (pipUiHeldUntilReconnect.value) {
      pipUiHeldUntilReconnect.value = false;
      unawaited(_syncNativePlayerActive());
    }
  }

  /// True while the PiP→fullscreen expansion animation is in progress.
  /// Used to prevent false "paused" lifecycle signals from interrupting playback.
  static bool isTransitioningFromPip = false;

  /// iOS fires [onPictureInPictureModeChanged(false)] when the [AVPlayerLayer] is torn
  /// down for **next/previous/autoplay** while PiP was active — not a user dismiss.
  /// Consuming this skips post-PiP pause/play choreography so the new clip keeps running.
  static bool _suppressNextPipStoppedForPlayerReplacement = false;

  /// One-shot: after player swap, call [enterPiP] once the new layer is playing.
  static bool _pendingIosPipReattachAfterSwap = false;

  /// Call immediately **before** disposing the inline player for an in-page video
  /// change while [isInPipMode] is true (e.g. autoplay / next / previous).
  static void suppressNextPipStoppedForControllerReplacement() {
    _suppressNextPipStoppedForPlayerReplacement = true;
  }

  /// After a swap while backgrounded (no PiP window), native PiP may not fire
  /// “stopped” — still mark so we try [enterPiP] once the new clip plays.
  static void markIosPipReattachAfterPlayerSwap() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    _pendingIosPipReattachAfterSwap = true;
  }

  /// When the new [VideoPlayerController] is playing and PiP is eligible, re-start
  /// PiP after the AVPlayerLayer was recreated (next / autoplay / previous).
  static void tryConsumeIosPipReattachAfterSwap() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!_pendingIosPipReattachAfterSwap) return;
    if (!iosPipNudgeEligible || _iosAutoEnterPipSuppressed) return;
    _pendingIosPipReattachAfterSwap = false;
    debugPrint('PipService: Scheduling PiP re-entry after player swap');
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      unawaited(enterPiP());
    });
  }

  /// After PiP closes, ignore brief lifecycle churn so we do not re-invoke [enterPiP].
  static DateTime? _suppressIosAutoEnterPipUntil;

  static bool get _iosAutoEnterPipSuppressed =>
      _suppressIosAutoEnterPipUntil != null &&
      DateTime.now().isBefore(_suppressIosAutoEnterPipUntil!);

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
        pipUiHeldUntilReconnect.value = false;
        isInPipMode.value = true;
        debugPrint('PipService: Entered PiP – player continues uninterrupted');
        unawaited(_syncNativePlayerActive());
      } else {
        // ─── Leaving PiP (expand back to full-screen OR closed) ─────────
        if (_suppressNextPipStoppedForPlayerReplacement) {
          _suppressNextPipStoppedForPlayerReplacement = false;
          isTransitioningFromPip = false;
          // Hold mini-player / PiP chrome until the next item is playing again.
          pipUiHeldUntilReconnect.value = true;
          isInPipMode.value = false;
          if (defaultTargetPlatform == TargetPlatform.iOS) {
            _pendingIosPipReattachAfterSwap = true;
          }
          debugPrint(
            'PipService: PiP stopped for inline player swap – skip post-PiP pause',
          );
          unawaited(_syncNativePlayerActive());
          return;
        }

        pipUiHeldUntilReconnect.value = false;

        if (defaultTargetPlatform == TargetPlatform.iOS) {
          _suppressIosAutoEnterPipUntil = DateTime.now().add(
            const Duration(milliseconds: 1600),
          );
        }
        isTransitioningFromPip = true;

        // Wait for Flutter's lifecycle to stabilize after the animation.
        Future.delayed(const Duration(milliseconds: 600), () {
          isTransitioningFromPip = false;
          isInPipMode.value = false;
          debugPrint('PipService: PiP transition lock released');
          unawaited(_syncNativePlayerActive());
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
          // Include [paused]: after expand-from-PiP, Flutter often still reports
          // [paused] at 300ms even though the user is returning to the app —
          // immediate pause was wrong. Defer like inactive/hidden.
          if (lifecycle == AppLifecycleState.inactive ||
              lifecycle == AppLifecycleState.hidden ||
              lifecycle == AppLifecycleState.paused) {
            debugPrint(
              'PipService: Post-PiP lifecycle $lifecycle – defer pause/play check',
            );
            Future.delayed(const Duration(milliseconds: 800), () {
              final later = WidgetsBinding.instance.lifecycleState;
              debugPrint('PipService: Post-PiP deferred lifecycle = $later');
              if (later == AppLifecycleState.paused) {
                debugPrint('PipService: Still paused after PiP – pausing playback');
                MediaSyncService().pauseFromNotification();
              } else if (later == AppLifecycleState.resumed) {
                MediaSyncService().playFromNotification();
              }
            });
            return;
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

  /// Whether iOS should try to enter PiP for multitasking / home (playing + video surface).
  static bool get iosPipNudgeEligible =>
      defaultTargetPlatform == TargetPlatform.iOS &&
      _playbackWantsPip &&
      _videoPageSurfaceActive &&
      !_iosAutoEnterPipSuppressed;

  /// Call from [HlsPlayerController] when playback state changes.
  static void setPlaybackWantsPip(bool playing) {
    if (_playbackWantsPip == playing) return;
    _playbackWantsPip = playing;
    // iOS: `applicationWillResignActive` can run before an in-flight
    // `updatePlayerStatus` completes — force the next sync to hit native.
    if (playing && defaultTargetPlatform == TargetPlatform.iOS) {
      _lastNativePlayerActive = null;
    }
    unawaited(_syncNativePlayerActive());
  }

  /// Native PiP eligibility: Home / Recents may enter PiP only when this is true —
  /// video is playing **and** the user is on [VideoPlayerPage] (not another route).
  ///
  /// On iOS, while PiP is visible we keep reporting active even if playback pauses,
  /// so the system does not tear down the PiP window and native prefs stay consistent.
  static Future<void> _syncNativePlayerActive() async {
    final baseWant = _playbackWantsPip && _videoPageSurfaceActive;
    final effectiveWant =
        defaultTargetPlatform == TargetPlatform.iOS &&
            (isInPipMode.value || pipUiHeldUntilReconnect.value)
        ? true
        : baseWant;
    if (_lastNativePlayerActive == effectiveWant) return;
    final supportsNativeSync =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!supportsNativeSync) {
      _lastNativePlayerActive = effectiveWant;
      return;
    }
    try {
      await _channel.invokeMethod('updatePlayerStatus', effectiveWant);
      _lastNativePlayerActive = effectiveWant;
    } on PlatformException catch (e) {
      debugPrint('PipService: updatePlayerStatus failed: ${e.message}');
    }
  }

  /// Earliest iOS hook: same native work as [enterPiP] (no extra channel method so
  /// older installs / hot Dart-only reloads never hit MissingPluginException).
  static Future<void> primeIosBackgroundPiP() => enterPiP();

  /// Explicitly enters PiP mode (e.g., when the user taps a PiP button).
  static Future<void> enterPiP() async {
    if (defaultTargetPlatform == TargetPlatform.iOS && _iosAutoEnterPipSuppressed) {
      debugPrint('PipService: enterPiP skipped (post-PiP cooldown)');
      return;
    }
    try {
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS: native `applicationWillResignActive` may run before a pending
        // `updatePlayerStatus`; push `true` immediately so `isPlayerActiveForPip`
        // and PiP controller refresh happen before `startPictureInPicture`.
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          try {
            await _channel.invokeMethod('updatePlayerStatus', true);
            _lastNativePlayerActive = true;
          } on PlatformException catch (e) {
            debugPrint('PipService: pre-enterPiP updatePlayerStatus failed: ${e.message}');
          }
        }
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
      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await _channel.invokeMethod('expandFromPip');
        debugPrint('PipService: expandFromPip requested');
      }
    } on PlatformException catch (e) {
      debugPrint('PipService: expandFromPip failed: ${e.message}');
    }
  }
}
