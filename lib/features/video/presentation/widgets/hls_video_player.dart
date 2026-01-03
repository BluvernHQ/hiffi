import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hiffi/features/video/presentation/controllers/hls_player_controller.dart';
import 'package:hiffi/core/utils/fullscreen_manager.dart';

/// Production-ready HLS Video Player widget using video_player + chewie.
///
/// This is the main entry point for the HLS video player. It creates
/// and manages an HlsPlayerController internally, and uses Chewie for UI controls.
///
/// Usage:
/// ```dart
/// HlsVideoPlayer(
///   videoId: 'video123',
///   baseVideoUrl: 'https://.../videos/video123',
///   autoPlay: true,
///   initialMuted: false,
/// )
/// ```
class HlsVideoPlayer extends StatefulWidget {
  final String videoId;
  final String baseVideoUrl; // The URL from GET /videos/{videoId}
  final bool autoPlay;
  final bool initialMuted;
  final Function(PlayerState)? onStateChanged;
  final VoidCallback? onVideoEnded;

  const HlsVideoPlayer({
    super.key,
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
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    debugPrint('HlsVideoPlayer: initState() for videoId ${widget.videoId}');
    _controller = HlsPlayerController(
      videoId: widget.videoId,
      baseVideoUrl: widget.baseVideoUrl,
      autoPlay: widget.autoPlay,
      initialMuted: widget.initialMuted,
      onVideoEnded: widget.onVideoEnded,
    );
    _controller.addListener(_onControllerStateChanged);

    // Register controller for external pause access
    HlsVideoPlayer.registerController(widget.videoId, _controller);
  }

  @override
  void didUpdateWidget(HlsVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If videoId changed, we need to replace the controller
    // However, with proper key usage, this should rarely happen
    // as Flutter will dispose and recreate the widget instead
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.baseVideoUrl != widget.baseVideoUrl) {
      debugPrint(
        'HlsVideoPlayer: didUpdateWidget() - videoId changed from ${oldWidget.videoId} to ${widget.videoId}. '
        'This should not happen with proper key usage. Disposing old controller.',
      );

      // Dispose old controller
      HlsVideoPlayer.unregisterController(oldWidget.videoId);
      _controller.removeListener(_onControllerStateChanged);
      _chewieController?.removeListener(_handleFullscreenChange);
      _chewieController?.dispose();
      _controller.dispose();

      // Create new controller
      _controller = HlsPlayerController(
        videoId: widget.videoId,
        baseVideoUrl: widget.baseVideoUrl,
        autoPlay: widget.autoPlay,
        initialMuted: widget.initialMuted,
        onVideoEnded: widget.onVideoEnded,
      );
      _controller.addListener(_onControllerStateChanged);
      HlsVideoPlayer.registerController(widget.videoId, _controller);
    }
  }

  /// Pauses the video playback
  void pause() {
    _controller.pause();
  }

  @override
  void dispose() {
    debugPrint(
      'HlsVideoPlayer: dispose() called for videoId ${widget.videoId}',
    );

    // Pause before disposing to ensure immediate stop
    _controller.pause();

    _controller.removeListener(_onControllerStateChanged);
    // Remove fullscreen listener before disposing
    _chewieController?.removeListener(_handleFullscreenChange);
    _chewieController?.dispose();

    // Unregister controller before disposing
    HlsVideoPlayer.unregisterController(widget.videoId);

    _controller.dispose();

    // Safety net: restore orientation and UI when the widget is destroyed
    FullscreenManager.exitFullscreen();
    debugPrint(
      'HlsVideoPlayer: Disposal complete for videoId ${widget.videoId}',
    );
    super.dispose();
  }

  void _onControllerStateChanged() {
    if (mounted) {
      widget.onStateChanged?.call(_controller.currentState);
      _updateChewieController();
      setState(() {});
    }
  }

  void _updateChewieController() {
    final videoController = _controller.controller;
    if (videoController == null || !videoController.value.isInitialized) {
      return;
    }

    // Dispose old chewie controller (listeners are automatically removed on dispose)
    _chewieController?.removeListener(_handleFullscreenChange);
    _chewieController?.dispose();

    // Create new chewie controller
    final newChewieController = ChewieController(
      videoPlayerController: videoController,
      autoPlay: widget.autoPlay,
      looping: false,
      aspectRatio: videoController.value.aspectRatio,
      showControls: true,
      allowFullScreen: true,
      allowMuting: true,
      allowPlaybackSpeedChanging: true,
      fullScreenByDefault: false,
      // Let FullscreenManager handle orientation explicitly
      // deviceOrientationsOnEnterFullScreen and deviceOrientationsAfterFullScreen
      // are set to ensure Chewie doesn't interfere, but we handle via FullscreenManager
      deviceOrientationsOnEnterFullScreen: [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
      deviceOrientationsAfterFullScreen: [DeviceOrientation.portraitUp],
      systemOverlaysOnEnterFullScreen: [], // Hide all
      systemOverlaysAfterFullScreen: SystemUiOverlay.values, // Restore all
      additionalOptions: (context) {
        return <OptionItem>[
          OptionItem(
            onTap: _showQualityPicker,
            iconData: Icons.settings,
            title: 'Quality',
            subtitle: _controller.currentProfile?.name ?? 'Auto',
          ),
        ];
      },
      materialProgressColors: ChewieProgressColors(
        playedColor: const Color(0xFFFF6B35),
        handleColor: const Color(0xFFFF6B35),
        backgroundColor: Colors.white24,
        bufferedColor: Colors.white70,
      ),
      errorBuilder: (context, errorMessage) {
        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
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
        );
      },
    );

    // Store the controller
    _chewieController = newChewieController;

    // Sync fullscreen state and handle orientation changes
    // Use a periodic check to ensure orientation changes are applied
    _chewieController!.addListener(_handleFullscreenChange);
  }

  void _handleFullscreenChange() {
    if (_chewieController == null) return;

    final isFullScreen = _chewieController!.isFullScreen;
    final wasFullScreen = _controller.isFullScreen;

    if (isFullScreen != wasFullScreen) {
      _controller.setFullScreen(isFullScreen);

      // Ensure orientation changes are applied immediately
      if (isFullScreen) {
        FullscreenManager.enterFullscreen();
      } else {
        FullscreenManager.exitFullscreen();
      }
    }
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
    final videoController = _controller.controller;
    if (videoController == null || !videoController.value.isInitialized) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    // Update chewie controller if needed
    if (_chewieController == null ||
        _chewieController?.videoPlayerController != videoController) {
      _updateChewieController();
    }

    return Container(
      color: Colors.black,
      child: _chewieController != null
          ? Chewie(controller: _chewieController!)
          : const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
            ),
    );
  }
}
