import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hiffi/features/video/presentation/controllers/hls_player_controller.dart';
import 'package:hiffi/features/video/domain/models/video_model.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';

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
  final Function(PlayerState)? onStateChanged;
  final VoidCallback? onVideoEnded;

  const HlsVideoPlayer({
    super.key,
    required this.video,
    required this.videoId,
    required this.baseVideoUrl,
    this.autoPlay = true,
    this.initialMuted = false,
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
      final position = controller.controller?.value.position;
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
}

class _HlsVideoPlayerState extends State<HlsVideoPlayer> {
  late HlsPlayerController _controller;
  bool _isDisposed = false;

  // Gesture control state
  Timer? _tapTimer;
  static const Duration _doubleTapDelay = Duration(milliseconds: 300);
  static const Duration _skipDuration = Duration(seconds: 10);

  @override
  void initState() {
    super.initState();
    _isDisposed = false;
    debugPrint('HlsVideoPlayer: initState() for videoId ${widget.videoId}');
    _controller = HlsPlayerController(
      videoId: widget.videoId,
      baseVideoUrl: widget.baseVideoUrl,
      autoPlay: widget.autoPlay,
      initialMuted: widget.initialMuted,
      onVideoEnded: widget.onVideoEnded,
      onShowQualityPicker: _showQualityPicker,
    );
    _controller.addListener(_onControllerStateChanged);

    // Register controller for external pause access
    HlsVideoPlayer.registerController(widget.videoId, _controller);

    // Register with MediaSyncService for background audio transitions
    MediaSyncService().setCurrentPlayer(_controller, widget.video);
  }

  @override
  void didUpdateWidget(HlsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.videoId != widget.videoId ||
        oldWidget.baseVideoUrl != widget.baseVideoUrl) {
      debugPrint(
        'HlsVideoPlayer: didUpdateWidget() - videoId changed from ${oldWidget.videoId} to ${widget.videoId}.',
      );

      HlsVideoPlayer.unregisterController(oldWidget.videoId);
      _controller.removeListener(_onControllerStateChanged);
      _controller.dispose();

      _controller = HlsPlayerController(
        videoId: widget.videoId,
        baseVideoUrl: widget.baseVideoUrl,
        autoPlay: widget.autoPlay,
        initialMuted: widget.initialMuted,
        onVideoEnded: widget.onVideoEnded,
        onShowQualityPicker: _showQualityPicker,
      );
      _controller.addListener(_onControllerStateChanged);
      HlsVideoPlayer.registerController(widget.videoId, _controller);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    debugPrint(
      'HlsVideoPlayer: dispose() called for videoId ${widget.videoId}',
    );

    _tapTimer?.cancel();
    _controller.removeListener(_onControllerStateChanged);

    // 💡 ARCHITECTURAL FIX: We no longer dispose ChewieController here.
    // ChewieController is now owned by HlsPlayerController, which survives
    // when the HlsVideoPlayer widget is moved in the tree (e.g., rotation).
    // It will be disposed only when HlsPlayerController is disposed.
    //
    // Chewie automatically restores orientation when disposed, so we don't need
    // to manually call FullscreenManager here.

    HlsVideoPlayer.unregisterController(widget.videoId);
    _controller.dispose();

    super.dispose();
  }

  /// Handles single tap for play/pause
  void _handleTap(BuildContext context, BoxConstraints constraints) {
    // Cancel any pending double-tap timer
    _tapTimer?.cancel();

    // Use a timer to distinguish single tap from double tap
    // This allows double-tap to cancel the single-tap action
    _tapTimer = Timer(_doubleTapDelay, () {
      // Single tap detected - toggle play/pause
      // Only execute if we haven't been disposed and widget is still mounted
      if (!_isDisposed && mounted) {
        _controller.togglePlayPause();
      }
    });
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

    _controller.seekBy(skipDuration);

    // Show visual feedback (optional - could add a skip indicator overlay)
    debugPrint(
      'HlsVideoPlayer: Double tap detected - skipping ${isLeftSide ? "backward" : "forward"} by ${_skipDuration.inSeconds}s',
    );
  }

  void _onControllerStateChanged() {
    if (_isDisposed || !mounted) return;

    widget.onStateChanged?.call(_controller.currentState);

    // 💡 SIMPLIFIED: Just trigger a rebuild when controller state changes.
    // We no longer need to sync fullscreen state since Chewie handles it internally
    // and we're not conditionally rendering based on it.
    setState(() {});
  }

  void _showQualityPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 16),
                child: Text(
                  'Video Quality',
                  style: TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ..._controller.profiles.map((profile) {
                final isSelected = _controller.currentProfile == profile;
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 4,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFFF6B35).withOpacity(0.1)
                            : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isSelected ? Icons.check : Icons.high_quality,
                        size: 20,
                        color: isSelected
                            ? const Color(0xFFFF6B35)
                            : Colors.grey[600],
                      ),
                    ),
                    title: Text(
                      profile.name,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFFF6B35)
                            : const Color(0xFF1A1A1A),
                        fontSize: 16,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    trailing: isSelected
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      _controller.changeQuality(profile);
                    },
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
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
                    backgroundColor: const Color(0xFFFF6B35),
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

    // Show loading state
    if (!_controller.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    // Show player
    final chewieController = _controller.chewieController;
    if (chewieController == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    // 💡 CRITICAL FIX: Always render the same Chewie widget.
    // Chewie handles fullscreen internally via overlays, so we shouldn't
    // conditionally render different widgets based on fullscreen state.
    // This prevents disposal/recreation during orientation changes, which
    // causes the "PlayerNotifier used after disposed" error.
    //
    // Use a stable key based on videoId to ensure Flutter doesn't unnecessarily
    // recreate the widget during rebuilds.
    final playerKey = ValueKey('chewie_${widget.videoId}');

    return Container(
      color: Colors.black,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: GestureDetector(
              onTap: () => _handleTap(context, constraints),
              onDoubleTapDown: (details) =>
                  _handleDoubleTap(details, constraints),
              // Allow taps to pass through to Chewie controls when not in center area
              behavior: HitTestBehavior.translucent,
              child: Chewie(key: playerKey, controller: chewieController),
            ),
          );
        },
      ),
    );
  }
}
