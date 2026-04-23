import 'dart:async';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';
import 'package:hiffi/core/services/pip_service.dart';
import 'package:hiffi/features/video/domain/models/video_model.dart';
import 'package:hiffi/features/video/domain/repositories/video_repository.dart';
import 'package:hiffi/features/video/presentation/controllers/hls_player_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Production-ready HLS Video Player widget using video_player + chewie.
///
/// This is the main entry point for the HLS video player. It creates
/// and manages an HlsPlayerController internally, and uses Chewie for UI controls.
///
/// Usage:
/// ```dart
/// HlsVideoPlayer(
///   video: video,
///   videoId: 'video123',
///   baseVideoUrl: 'https://.../videos/video123',
///   autoPlay: true,
///   initialMuted: false,
/// )
/// ```
class HlsVideoPlayer extends StatefulWidget {
  final VideoModel video;
  final String videoId;
  final String baseVideoUrl; // The URL from GET /videos/{videoId}
  final bool autoPlay;
  final bool initialMuted;
  final Duration? initialResumePosition;
  final VideoRepository? watchHoursRepository;
  final Function(PlayerState)? onStateChanged;
  final VoidCallback? onVideoEnded;

  const HlsVideoPlayer({
    super.key,
    required this.video,
    required this.videoId,
    required this.baseVideoUrl,
    this.autoPlay = true,
    this.initialMuted = false,
    this.initialResumePosition,
    this.watchHoursRepository,
    this.onStateChanged,
    this.onVideoEnded,
  });

  @override
  State<HlsVideoPlayer> createState() => _HlsVideoPlayerState();

  // Registry to access player controllers for pausing
  static final Map<String, HlsPlayerController> _controllers = {};

  static Future<void> pausePlayer(String videoId) async {
    final controller = _controllers[videoId];
    if (controller != null) {
      debugPrint(
        'HlsVideoPlayer: Pausing player for videoId $videoId via static method',
      );
      // Get current position and save it before pausing
      Duration? position;
      try {
        position = controller.controller?.value.position;
      } catch (e) {
        debugPrint(
          'HlsVideoPlayer: Ignoring position read from disposed controller for $videoId: $e',
        );
      }
      if (position != null) {
        // Save position to SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(
            'video_position_$videoId',
            position.inMilliseconds,
          );
          debugPrint(
            'HlsVideoPlayer: Saved position ${position.inSeconds}s for videoId $videoId',
          );
        } catch (e) {
          debugPrint('HlsVideoPlayer: Failed to save position: $e');
        }
      }
      controller.pause();
    } else {
      debugPrint(
        'HlsVideoPlayer: No controller found for videoId $videoId to pause',
      );
    }
  }

  static Future<void> playPlayer(String videoId) async {
    final controller = _controllers[videoId];
    if (controller != null) {
      debugPrint(
        'HlsVideoPlayer: Resuming player for videoId $videoId via static method',
      );
      controller.play();
    } else {
      debugPrint(
        'HlsVideoPlayer: No controller found for videoId $videoId to play',
      );
    }
  }

  static void registerController(
    String videoId,
    HlsPlayerController controller,
  ) {
    _controllers[videoId] = controller;
    debugPrint('HlsVideoPlayer: Registered controller for videoId $videoId');
  }

  static void unregisterController(String videoId) {
    _controllers.remove(videoId);
    debugPrint('HlsVideoPlayer: Unregistered controller for videoId $videoId');
  }

  static HlsPlayerController? getController(String videoId) {
    return _controllers[videoId];
  }

  /// Truly disposes and removes the controller for a given videoId.
  /// Call this when permanently leaving the video (page dispose / video change).
  /// Do NOT call this during PiP transitions – the controller must stay alive.
  static void disposeForVideo(String videoId) {
    final controller = _controllers[videoId];
    if (controller != null) {
      controller.dispose();
      _controllers.remove(videoId);
      debugPrint(
        'HlsVideoPlayer: Permanently disposed controller for $videoId',
      );
    }
  }
}

class _HlsVideoPlayerState extends State<HlsVideoPlayer> {
  late HlsPlayerController _controller;
  bool _isDisposed = false;
  bool? _lastFullScreen;

  // Gesture control state
  Timer? _tapTimer;
  static const Duration _skipDuration = Duration(seconds: 10);

  // Pull-up to fullscreen (YouTube-style)
  double _verticalDragUpTotal = 0;
  static const double _pullToFullscreenThresholdPx = 80;
  static const double _pullToFullscreenVelocityThreshold = 200;

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    debugPrint('HlsVideoPlayer: initState() for videoId ${widget.videoId}');

    // Reuse existing controller if one is alive for this videoId.
    // This is the key to surviving PiP-induced widget rebuilds:
    // when Android resizes the window for PiP the widget tree is torn down
    // and reconstructed, but the underlying VideoPlayerController must keep
    // playing at its current position rather than restarting from 0.
    final existing = HlsVideoPlayer._controllers[widget.videoId];
    if (existing != null && !existing.isDisposed) {
      _controller = existing;
      debugPrint(
        'HlsVideoPlayer: Reusing existing controller for ${widget.videoId} '
        '(pos: ${existing.controller?.value.position})',
      );
      MediaSyncService().setCurrentPlayer(_controller, widget.video);
    } else {
      _controller = HlsPlayerController(
        video: widget.video,
        videoId: widget.videoId,
        baseVideoUrl: widget.baseVideoUrl,
        autoPlay: widget.autoPlay,
        initialMuted: widget.initialMuted,
        initialResumePosition: widget.initialResumePosition,
        watchHoursRepository: widget.watchHoursRepository,
        onVideoEnded: widget.onVideoEnded,
      );
      HlsVideoPlayer.registerController(widget.videoId, _controller);
      MediaSyncService().setCurrentPlayer(_controller, widget.video);
    }

    _controller.addListener(_onControllerStateChanged);
  }

  @override
  void didUpdateWidget(HlsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoId != widget.videoId ||
        oldWidget.baseVideoUrl != widget.baseVideoUrl) {
      debugPrint(
        'HlsVideoPlayer: didUpdateWidget() - videoId changed from '
        '${oldWidget.videoId} to ${widget.videoId}.',
      );

      _controller.removeListener(_onControllerStateChanged);
      // Permanently dispose the old video's controller since we are
      // intentionally switching to a different video.
      HlsVideoPlayer.disposeForVideo(oldWidget.videoId);

      // Reuse if a controller already exists for the new videoId (unlikely
      // but safe), otherwise create fresh.
      final existing = HlsVideoPlayer._controllers[widget.videoId];
      if (existing != null && !existing.isDisposed) {
        _controller = existing;
        MediaSyncService().setCurrentPlayer(_controller, widget.video);
      } else {
        _controller = HlsPlayerController(
          video: widget.video,
          videoId: widget.videoId,
          baseVideoUrl: widget.baseVideoUrl,
          autoPlay: widget.autoPlay,
          initialMuted: widget.initialMuted,
          initialResumePosition: widget.initialResumePosition,
          watchHoursRepository: widget.watchHoursRepository,
          onVideoEnded: widget.onVideoEnded,
        );
        HlsVideoPlayer.registerController(widget.videoId, _controller);
        MediaSyncService().setCurrentPlayer(_controller, widget.video);
      }
      _controller.addListener(_onControllerStateChanged);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint(
      'HlsVideoPlayer: dispose() called for videoId ${widget.videoId} '
      '(controller kept alive in registry for PiP survival)',
    );

    WakelockPlus.disable();
    _tapTimer?.cancel();
    _controller.removeListener(_onControllerStateChanged);

    // Intentionally do NOT dispose the controller or remove it from the registry.
    // The controller must survive PiP-induced widget rebuild cycles so playback
    // continues at the exact same position when the widget is recreated.
    // VideoPlayerPage.dispose() will call HlsVideoPlayer.disposeForVideo() to
    // truly release resources when the user navigates away permanently.

    super.dispose();
  }

  /// Handles single tap for play/pause
  void _handleTap(BuildContext context, BoxConstraints constraints) {
    // Cancel any pending double-tap timer
    _tapTimer?.cancel();
    // Do not toggle playback from surface taps.
    // The tap area exists for double-tap seek and gesture coordination only.
    // Play/pause is controlled by the explicit center control button.
  }

  /// Handles double tap for skip forward/backward
  void _handleDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    // Cancel single tap timer since this is a double tap
    _tapTimer?.cancel();

    if (_isDisposed || !mounted) return;

    // Determine if tap is on left or right side of the video
    final tapX = details.localPosition.dx;
    final videoWidth = constraints.maxWidth;
    final isLeftSide = tapX < videoWidth / 2;

    // Skip backward on left side, forward on right side
    final skipDuration = isLeftSide ? -_skipDuration : _skipDuration;
    unawaited(_controller.seekBy(skipDuration));

    // Show visual feedback (optional - could add a skip indicator overlay)
    debugPrint(
      'HlsVideoPlayer: Double tap detected - skipping ${isLeftSide ? "backward" : "forward"} by ${_skipDuration.inSeconds}s',
    );
  }

  /// Pull-up to fullscreen (YouTube-style): in portrait, drag up to enter fullscreen.
  void _handleVerticalDragStart(DragStartDetails details) {
    _verticalDragUpTotal = 0;
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    if (details.delta.dy < 0) _verticalDragUpTotal += -details.delta.dy;
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    if (_isDisposed || !mounted || _controller.isFullScreen) return;
    if (MediaQuery.of(context).orientation != Orientation.portrait) return;
    final velocity = details.primaryVelocity ?? 0;
    final crossedThreshold =
        _verticalDragUpTotal >= _pullToFullscreenThresholdPx ||
        (velocity <= 0 && velocity.abs() >= _pullToFullscreenVelocityThreshold);
    if (crossedThreshold) {
      debugPrint('HlsVideoPlayer: Pull-up to fullscreen triggered');
      _controller.enterFullScreen();
    }
    _verticalDragUpTotal = 0;
  }

  void _onControllerStateChanged() {
    if (_isDisposed || !mounted) return;

    // Keep screen awake while video is playing (portrait and landscape)
    if (_controller.isPlaying) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    // Ensure we don't end up with double audio: if background audio is
    // still active and the inline player starts playing, force a switch
    // back to foreground video playback.
    if (_controller.isPlaying && MediaSyncService().isBackgrounded) {
      MediaSyncService().switchToForeground();
    }

    // Detect manual fullscreen changes (from button)
    if (_controller.isFullScreen != _lastFullScreen) {
      final wasFullScreen = _lastFullScreen;
      _lastFullScreen = _controller.isFullScreen;

      // 💡 GUARD: If we are currently switching profiles, ignore fullscreen state changes.
      // This prevents the UI from triggering an "exitFullscreen" snap while we're
      // just swapping the underlying video player.
      if (_controller.isSwitchingProfile) {
        debugPrint(
          'HlsVideoPlayer: Ignoring fullscreen change during profile switch',
        );
        return;
      }

      if (wasFullScreen != null) {
        if (!_controller.isFullScreen) {
          debugPrint('HlsVideoPlayer: Manual exit detected');
        }
      }
    }

    widget.onStateChanged?.call(_controller.currentState);

    // 💡 SIMPLIFIED: Just trigger a rebuild when controller state changes.
    // We no longer need to sync fullscreen state since Chewie handles it internally
    // and we're not conditionally rendering based on it.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Show error state
    if (_controller.hasError) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  _controller.errorMessage ?? 'Failed to load video',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _controller.retry(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFED1C2F),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final chewieController = _controller.chewieController;
    final isInitialized = _controller.isInitialized && chewieController != null;
    final showSwitchingOverlay = _controller.isSwitchingProfile;
    final containerKey = ValueKey(
      'container_${widget.videoId}_${_controller.currentProfile}',
    );
    final playerKey = ValueKey(
      'chewie_${widget.videoId}_${_controller.currentProfile}',
    );

    return Container(
      key: containerKey,
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                // 1. Loading overlay while the stream is initializing.
                Positioned.fill(
                  child: AnimatedOpacity(
                    opacity: isInitialized ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFED1C2F),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                  ),
                ),

                // 2. The Video Player
                // In PiP, do not wrap Chewie in this GestureDetector — it wins the gesture
                // arena over [HiffiVideoControls] corner InkWells so expand/fullscreen never fire.
                if (isInitialized)
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: AnimatedOpacity(
                        opacity: isInitialized ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: PipService.isInPipMode,
                          builder: (context, inPip, _) {
                            final chewie = Chewie(
                              key: playerKey,
                              controller: chewieController,
                            );
                            if (inPip) {
                              return chewie;
                            }
                            return GestureDetector(
                              onTap: () => _handleTap(context, constraints),
                              onDoubleTapDown: (details) =>
                                  _handleDoubleTap(details, constraints),
                              onVerticalDragStart: _handleVerticalDragStart,
                              onVerticalDragUpdate: _handleVerticalDragUpdate,
                              onVerticalDragEnd: _handleVerticalDragEnd,
                              behavior: HitTestBehavior.translucent,
                              child: chewie,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                // 3. Keep current frame visible and show loader while switching profile.
                if (showSwitchingOverlay)
                  Positioned.fill(
                    child: AbsorbPointer(
                      child: Container(
                        color: Colors.black.withOpacity(0.45),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFED1C2F),
                            strokeWidth: 3,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
