import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hiffi/core/services/pip_service.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';
import 'package:hiffi/core/utils/fullscreen_manager.dart';

import 'package:hiffi/features/video/domain/models/video_model.dart';
import 'package:hiffi/core/utils/image_utils.dart';
import 'package:hiffi/features/video/presentation/widgets/hiffi_video_controls.dart';

/// Controller for HLS video playback lifecycle and state management.
class HlsPlayerController extends ChangeNotifier {
  final VideoModel video;
  final String videoId;
  final String baseVideoUrl;
  final bool autoPlay;
  final bool initialMuted;
  final VoidCallback? _onVideoEnded;

  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  PlayerState _currentState = PlayerState.ready;
  bool _isFullScreen = false;
  bool _hasEnded = false;
  bool _isDisposed = false;
  bool _isSwitchingProfile = false;

  // Quality/Profile management
  String _currentProfile = 'original';
  List<String> _availableProfiles = [];

  // User preferences
  bool _userIntentMuted;
  double _userIntentVolume = 1.0;
  Duration? _lastKnownPosition;
  bool? _lastPipStatus;
  /// Avoids [notifyListeners] on every video frame (fixes Android ImageReader buffer spam).
  bool? _lastReportedIsPlaying;

  /// Drives fullscreen icon in [HiffiVideoControls] (Chewie fullscreen flag stays false).
  final ValueNotifier<bool> fullscreenUiForControls = ValueNotifier<bool>(false);

  HlsPlayerController({
    required this.video,
    required this.videoId,
    required this.baseVideoUrl,
    this.autoPlay = true,
    this.initialMuted = false,
    VoidCallback? onVideoEnded,
  }) : _userIntentMuted = initialMuted,
       _onVideoEnded = onVideoEnded {
    _initProfiles();
    _initialize();
  }

  void _initProfiles() {
    _availableProfiles = [];
    if (video.originalProfile != null) {
      _availableProfiles.add('original');
    }
    _availableProfiles.addAll(video.profiles);

    if (_availableProfiles.isEmpty) {
      _availableProfiles.add('original');
    }
  }

  String get currentProfile => _currentProfile;
  List<String> get availableProfiles => _availableProfiles;
  bool get isSwitchingProfile => _isSwitchingProfile;

  String get currentPlaybackUrl => ImageUtils.resolveVideoPlaybackUrl(
    baseVideoUrl,
    profile: _currentProfile,
  );

  VideoPlayerController? get controller => _videoPlayerController;
  ChewieController? get chewieController => _chewieController;
  bool get isInitialized => _isInitialized;
  bool get isDisposed => _isDisposed;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  PlayerState get currentState => _currentState;
  bool get isFullScreen => _isFullScreen;
  bool get isMuted => _userIntentMuted;
  double get volume => _userIntentVolume;

  VideoPlayerController? _safeVideoController() {
    final controller = _videoPlayerController;
    if (controller == null || _isDisposed) return null;
    try {
      controller.value;
      return controller;
    } catch (_) {
      return null;
    }
  }

  /// Switches the video quality profile
  Future<void> setProfile(String profile) async {
    if (_currentProfile == profile || _isSwitchingProfile || _isDisposed) return;

    debugPrint('HlsPlayerController: Switching profile to $profile');
    _isSwitchingProfile = true;

    try {
      // 1. Capture current state.
      final wasPlaying = isPlaying;
      final wasFullScreen = _isFullScreen;

      final activeController = _safeVideoController();
      if (activeController != null && activeController.value.isInitialized) {
        _lastKnownPosition = activeController.value.position;
        if (activeController.value.isPlaying) {
          await activeController.pause();
        }
      }

      // 2. Lock orientation during switch to prevent portrait snap.
      if (wasFullScreen) {
        debugPrint('HlsPlayerController: Locking landscape for profile switch');
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      } else {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
        ]);
      }
      await Future.delayed(const Duration(milliseconds: 100));

      // 3. Surface loading state while old frame is still visible.
      _currentState = PlayerState.buffering;
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 80));

      // 4. Dispose old controller graph and build a fresh one.
      await _disposeControllers(isSwitchingProfile: true);
      await Future.delayed(const Duration(milliseconds: 250));

      _currentProfile = profile;
      if (!_isDisposed) {
        await _setupPlayer();
      }

      // 5. Resume playback once the new controller is initialized.
      if (wasPlaying && !_isDisposed && _isInitialized) {
        await play();
      }

      // Keep rotation unlocked; do not auto re-enter fullscreen route.
      if (!_isDisposed) {
        await SystemChrome.setPreferredOrientations([
          DeviceOrientation.portraitUp,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ]);
      }
    } finally {
      _isSwitchingProfile = false;
      if (!_isDisposed) {
        notifyListeners();
      }
    }
  }

  Duration get duration {
    final controller = _safeVideoController();
    if (controller != null && controller.value.isInitialized) {
      return controller.value.duration;
    }
    return Duration.zero;
  }

  Duration get position {
    final controller = _safeVideoController();
    if (controller != null && controller.value.isInitialized) {
      return controller.value.position;
    }
    return Duration.zero;
  }

  bool get isPlaying {
    final controller = _safeVideoController();
    if (controller != null && controller.value.isInitialized) {
      return controller.value.isPlaying;
    }
    return false;
  }

  Future<void> pause() async {
    final controller = _safeVideoController();
    if (controller == null || !_isInitialized || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      debugPrint('HlsPlayerController: Pausing playback');
      await controller.pause();
    }
  }

  Future<void> play() async {
    final controller = _safeVideoController();
    if (controller == null || !_isInitialized || !controller.value.isInitialized) {
      return;
    }
    if (!controller.value.isPlaying) {
      debugPrint('HlsPlayerController: Resuming playback');
      await controller.play();
    }
  }

  Future<void> togglePlayPause() async {
    final controller = _safeVideoController();
    if (controller == null || !_isInitialized || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> seekBy(Duration duration) async {
    final controller = _safeVideoController();
    if (controller == null || !_isInitialized || !controller.value.isInitialized) {
      return;
    }
    final currentPosition = controller.value.position;
    final videoDuration = controller.value.duration;
    final newPositionMs = (currentPosition + duration).inMilliseconds;
    final clampedPositionMs = newPositionMs.clamp(0, videoDuration.inMilliseconds);
    final clampedPosition = Duration(milliseconds: clampedPositionMs);
    await controller.seekTo(clampedPosition);
  }

  void enterFullScreen() {
    if (_isDisposed || _isFullScreen) return;
    debugPrint('HlsPlayerController: Entering fullscreen');
    _isFullScreen = true;
    fullscreenUiForControls.value = true;
    notifyListeners();
    FullscreenManager.enterFullscreen();
  }

  void exitFullScreen() {
    if (_isDisposed || !_isFullScreen) return;
    debugPrint('HlsPlayerController: Exiting fullscreen');
    _isFullScreen = false;
    fullscreenUiForControls.value = false;
    notifyListeners();
    FullscreenManager.exitFullscreen();
  }

  void setFullScreen(bool value) {
    if (_isFullScreen == value || _isDisposed) return;
    _isFullScreen = value;
    fullscreenUiForControls.value = value;
    notifyListeners();
  }

  /// PiP “open app”: inline player in portrait — not fullscreen, no landscape lock.
  Future<void> expandFromPipToInlinePortrait() async {
    PipService.suppressOrientationDrivenFullscreenTemporarily();
    await PipService.expandFromPip();
    if (_isDisposed) return;
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
    if (_isFullScreen) {
      _isFullScreen = false;
      fullscreenUiForControls.value = false;
      notifyListeners();
    }
    await FullscreenManager.lockToPortrait();
  }

  /// PiP fullscreen: leave PiP then immersive landscape (may rotate device).
  Future<void> expandFromPipThenFullscreen() async {
    await PipService.expandFromPip();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_isDisposed) return;
    enterFullScreen();
  }

  Future<void> _initialize() async {
    try {
      await _loadUserPreferences();
      await _setupPlayer();
    } catch (e) {
      _handleError('Initialization failed: $e');
    }
  }

  Future<void> _loadUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _userIntentMuted = prefs.getBool('video_user_muted') ?? initialMuted;
      _userIntentVolume = prefs.getDouble('video_user_volume') ?? 1.0;
    } catch (e) {
      debugPrint('Failed to load user preferences: $e');
    }
  }

  Future<void> _saveUserPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('video_user_muted', _userIntentMuted);
      await prefs.setDouble('video_user_volume', _userIntentVolume);
    } catch (e) {
      debugPrint('Failed to save user preferences: $e');
    }
  }

  Future<void> _setupPlayer() async {
    if (_isDisposed) return;
    try {
      _hasError = false;
      _errorMessage = null;
      _currentState = PlayerState.buffering;

      final profileUrl = ImageUtils.resolveVideoPlaybackUrl(
        baseVideoUrl,
        profile: _currentProfile,
      );
      
      final videoController = VideoPlayerController.networkUrl(
        Uri.parse(profileUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: true,
        ),
      );
      _videoPlayerController = videoController;

      await videoController.initialize();
      if (_isDisposed || _videoPlayerController != videoController) {
        await videoController.dispose();
        return;
      }

      await videoController.setVolume(_userIntentMuted ? 0.0 : _userIntentVolume);

      if (_lastKnownPosition == null) {
        _lastKnownPosition = await _loadPlaybackPosition();
      }
      if (_lastKnownPosition != null &&
          _lastKnownPosition!.inMilliseconds > 0 &&
          !_isDisposed &&
          _videoPlayerController == videoController) {
        await videoController.seekTo(_lastKnownPosition!);
      }

      if (_isDisposed || _videoPlayerController != videoController) {
        await videoController.dispose();
        return;
      }

      final chewieController = ChewieController(
        videoPlayerController: videoController,
        autoPlay: autoPlay,
        looping: false,
        aspectRatio: null,
        showControls: true,
        allowFullScreen: false,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        fullScreenByDefault: false,
        customControls: HiffiVideoControls(
          fullscreenUiListenable: fullscreenUiForControls,
          onToggleInAppFullscreen: () {
            if (_isFullScreen) {
              exitFullScreen();
            } else {
              enterFullScreen();
            }
          },
          onPipExpandToApp: expandFromPipToInlinePortrait,
          onPipEnterFullscreen: expandFromPipThenFullscreen,
        ),
        deviceOrientationsOnEnterFullScreen: [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
        deviceOrientationsAfterFullScreen: [
          DeviceOrientation.portraitUp,
        ],
        systemOverlaysOnEnterFullScreen: [],
        systemOverlaysAfterFullScreen: SystemUiOverlay.values,
        additionalOptions: (context) => <OptionItem>[
          if (_availableProfiles.length > 1)
            OptionItem(
              onTap: _showQualitySelectionDialog,
              iconData: Icons.settings,
              title: 'Quality',
              subtitle: _getProfileLabel(_currentProfile),
            ),
        ],
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFED1C2F),
          handleColor: const Color(0xFFED1C2F),
          backgroundColor: Colors.white24,
          bufferedColor: Colors.white70,
        ),
        cupertinoProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFFED1C2F),
          handleColor: const Color(0xFFED1C2F),
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
                  Text(errorMessage, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: retry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED1C2F),
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
      _chewieController = chewieController;

      chewieController.addListener(_handleChewieStateChange);
      videoController.addListener(_handlePlayerStateChange);

      if (autoPlay &&
          !_isDisposed &&
          _videoPlayerController == videoController) {
        try {
          await videoController.play();
        } catch (_) {
          // Ignore autoplay race failures during controller switches.
        }
      }

      if (!_isDisposed &&
          _videoPlayerController == videoController &&
          _chewieController == chewieController) {
        _isInitialized = true;
        _currentState = PlayerState.ready;
        notifyListeners();
      }
    } catch (e) {
      _handleError('Setup failed: $e');
    }
  }

  String _getProfileLabel(String profile) {
    if (profile == 'original') {
      return video.originalProfile ?? 'High';
    }
    return profile;
  }

  void _showQualitySelectionDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _availableProfiles.map((profile) {
              final isSelected = profile == _currentProfile;
              return ListTile(
                onTap: () {
                  Navigator.pop(context);
                  setProfile(profile);
                },
                leading: Icon(isSelected ? Icons.check : null, color: const Color(0xFFED1C2F)),
                title: Text(_getProfileLabel(profile), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                trailing: isSelected ? const Text('Selected', style: TextStyle(color: Color(0xFFED1C2F))) : null,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  double _aspectRatio = 16 / 9;
  double get aspectRatio => _aspectRatio;

  void _handlePlayerStateChange() {
    final controller = _safeVideoController();
    if (controller == null) return;
    if (controller.value.isInitialized) {
      if (_aspectRatio != controller.value.aspectRatio) {
        _aspectRatio = controller.value.aspectRatio;
        notifyListeners();
      }
    }
    if (controller.value.hasError) {
      _handleError(controller.value.errorDescription ?? 'Unknown error');
      return;
    }

    final buffering = controller.value.isBuffering;
    final playing = controller.value.isPlaying;
    var shouldNotify = false;

    if (playing) {
      if (_lastPipStatus != true) {
        PipService.setPlaybackWantsPip(true);
        _lastPipStatus = true;
        shouldNotify = true;
      }
    } else {
      if (_lastPipStatus != false) {
        PipService.setPlaybackWantsPip(false);
        _lastPipStatus = false;
        shouldNotify = true;
      }
    }

    final newState =
        buffering ? PlayerState.buffering : PlayerState.ready;
    if (newState != _currentState) {
      _currentState = newState;
      shouldNotify = true;
    }

    if (_lastReportedIsPlaying != playing) {
      _lastReportedIsPlaying = playing;
      shouldNotify = true;
    }

    if (shouldNotify) {
      notifyListeners();
    }

    _lastKnownPosition = controller.value.position;

    // Check if video has ended
    final duration = controller.value.duration;
    if (duration.inMilliseconds > 0 &&
        _lastKnownPosition!.inMilliseconds >= duration.inMilliseconds - 100) {
      if (!_hasEnded) {
        _hasEnded = true;
        _onVideoEnded?.call();
      }
    } else if (_hasEnded &&
        _lastKnownPosition!.inMilliseconds < duration.inMilliseconds - 1000) {
      _hasEnded = false;
    }
  }

  void _handleChewieStateChange() {
    if (_chewieController == null || _isDisposed) return;
  }

  void _handleError(String message) {
    if (_isDisposed) return;
    debugPrint('HLS Player Error: $message');
    _hasError = true;
    _errorMessage = message;
    _currentState = PlayerState.error;
    notifyListeners();
  }

  Future<void> retry() async {
    if (_isDisposed) return;
    await _setupPlayer();
  }

  Future<void> toggleMute() async {
    final controller = _safeVideoController();
    if (controller == null) return;
    _userIntentMuted = !_userIntentMuted;
    await controller.setVolume(_userIntentMuted ? 0.0 : _userIntentVolume);
    await _saveUserPreferences();
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    final controller = _safeVideoController();
    if (controller == null) return;
    _userIntentVolume = volume.clamp(0.0, 1.0);
    if (!_userIntentMuted) {
      await controller.setVolume(_userIntentVolume);
    }
    await _saveUserPreferences();
    notifyListeners();
  }

  Future<void> _savePlaybackPosition() async {
    final controller = _safeVideoController();
    if (controller != null) {
      _lastKnownPosition = controller.value.position;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('video_position_$videoId', _lastKnownPosition!.inMilliseconds);
      } catch (e) {
        debugPrint('Failed to save playback position: $e');
      }
    }
  }

  Future<Duration?> _loadPlaybackPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionMs = prefs.getInt('video_position_$videoId');
      if (positionMs != null) return Duration(milliseconds: positionMs);
    } catch (e) {
      debugPrint('Failed to load playback position: $e');
    }
    return null;
  }

  static Future<void> clearPlaybackPosition(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('video_position_$videoId');
    } catch (e) {
      debugPrint('Failed to clear playback position: $e');
    }
  }

  Future<void> _disposeControllers({bool isSwitchingProfile = false}) async {
    final previousController = _safeVideoController();
    if (previousController != null) {
      try {
        _lastKnownPosition = previousController.value.position;
      } catch (_) {}
    }
    await _savePlaybackPosition();
    PipService.setPlaybackWantsPip(false);
    _lastPipStatus = false;
    _isInitialized = false;
    _lastReportedIsPlaying = null;

    final videoController = _videoPlayerController;
    final chewieController = _chewieController;
    _videoPlayerController = null;
    _chewieController = null;

    if (videoController != null) {
      videoController.removeListener(_handlePlayerStateChange);
    }

    if (chewieController != null) {
      chewieController.removeListener(_handleChewieStateChange);
      if (chewieController.isFullScreen) {
        debugPrint('HlsPlayerController: Exiting fullscreen and waiting for route to close');
        chewieController.exitFullScreen();
        // 💡 CRITICAL: Fullscreen transitions on some Android devices can be slow.
        // If we dispose the controller before the route has popped, Chewie will crash.
        await Future.delayed(const Duration(milliseconds: 1000));
      }
      try {
        chewieController.dispose();
      } catch (e) {
        debugPrint('HlsPlayerController: Ignored error during Chewie disposal: $e');
      }
    }

    if (videoController != null) {
      try {
        await videoController.dispose();
      } catch (e) {
        debugPrint('HlsPlayerController: Ignored error during VideoPlayer disposal: $e');
      }
    }
  }

  @override
  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    debugPrint('HlsPlayerController: dispose() called for videoId $videoId');
    fullscreenUiForControls.dispose();
    MediaSyncService().clearCurrentPlayer(this);
    _disposeControllers(isSwitchingProfile: false);
    super.dispose();
  }
}

enum PlayerState { ready, buffering, error }
