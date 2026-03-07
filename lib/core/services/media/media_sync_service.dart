import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:hiffi/core/services/media/hiffi_audio_handler.dart';
import 'package:hiffi/core/services/hls_proxy_service.dart';
import 'package:hiffi/core/services/pip_service.dart';
import 'package:hiffi/features/video/presentation/controllers/hls_player_controller.dart';
import 'package:hiffi/features/video/domain/models/video_model.dart';
import 'package:hiffi/core/utils/image_utils.dart';

/// Service that manages seamless transitions between foreground video and background audio.
///
/// When app is foregrounded: Video plays using video_player + chewie
/// When app is backgrounded: Video stops, audio continues via audio_service
/// Media controls appear in notification/lock screen/control center
class MediaSyncService {
  static final MediaSyncService _instance = MediaSyncService._internal();
  factory MediaSyncService() => _instance;
  MediaSyncService._internal();

  HiffiAudioHandler? _audioHandler;
  HlsPlayerController? _currentVideoController;
  VideoModel? _currentVideo;

  bool _isBackgrounded = false;
  Duration? _lastVideoPosition;
  bool _isSyncing = false; // Prevents sync loops

  // Callbacks for UI-controlled navigation
  VoidCallback? _onNextRequested;
  VoidCallback? _onPreviousRequested;
  bool Function()? _hasPreviousVideo;

  /// Whether there is a previous video to go back to (e.g. after tapping Next).
  bool get hasPreviousVideo => _hasPreviousVideo?.call() ?? false;

  /// Registers navigation callbacks from the UI.
  void registerNavigationCallbacks({
    VoidCallback? onNext,
    VoidCallback? onPrevious,
    bool Function()? hasPreviousVideo,
  }) {
    _onNextRequested = onNext;
    _onPreviousRequested = onPrevious;
    _hasPreviousVideo = hasPreviousVideo;

    // Update notification controls visibility
    _syncVideoToNotification();
  }

  Future<void> initialize() async {
    debugPrint('MediaSyncService: Initializing...');

    // Configure audio session for background playback
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Initialize audio service with proper configuration
    // Note: androidNotificationOngoing requires androidStopForegroundOnPause to be true
    // The notification will persist as long as the service is running
    _audioHandler = await AudioService.init(
      builder: () => HiffiAudioHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelId: 'com.hiffi.app.channel.audio',
        androidNotificationChannelName: 'Hiffi Playback',
        androidNotificationOngoing: true, // Persistent notification
        androidStopForegroundOnPause: true, // Required when ongoing is true
        androidShowNotificationBadge: true,
        fastForwardInterval: const Duration(seconds: 10),
        rewindInterval: const Duration(seconds: 10),
      ),
    );

    // 💡 SYNC FIX: Listen to notification control events
    _audioHandler!.playbackState.listen(_handleNotificationStateChange);

    debugPrint('MediaSyncService: Initialized successfully');
  }

  /// Handles state changes from the notification controls.
  /// This ensures that tapping pause in the notification pauses the video.
  void _handleNotificationStateChange(PlaybackState state) {
    if (_isSyncing || _currentVideoController == null) return;

    // We only care about syncing FROM notification TO app when in foreground or PiP
    if (!_isBackgrounded) {
      _isSyncing = true;
      try {
        // Sync Play/Pause
        if (state.playing != _currentVideoController!.isPlaying) {
          debugPrint(
            'MediaSyncService: Syncing Play/Pause from Notification -> Video: ${state.playing}',
          );
          if (state.playing) {
            _currentVideoController!.play();
          } else {
            _currentVideoController!.pause();
          }
        }

        // Sync Position (if changed significantly from notification seek)
        final notificationPos = state.position;
        final videoPos = _currentVideoController!.position;
        if ((notificationPos - videoPos).inSeconds.abs() > 2) {
          debugPrint(
            'MediaSyncService: Syncing Seek from Notification -> Video: ${notificationPos.inSeconds}s',
          );
          _currentVideoController!.controller?.seekTo(notificationPos);
        }
      } finally {
        _isSyncing = false;
      }
    }
  }

  /// Sets the current video player and video model.
  /// Call this when a new video starts playing.
  void setCurrentPlayer(HlsPlayerController controller, VideoModel video) {
    debugPrint(
      'MediaSyncService: Setting current player for video ${video.videoId}',
    );
    // Remove listener from old controller if any
    _currentVideoController?.removeListener(_syncVideoToNotification);

    _currentVideoController = controller;
    _currentVideo = video;
    _isBackgrounded = false;

    // 💡 SYNC FIX: Listen to video player changes to update notification
    _currentVideoController!.addListener(_syncVideoToNotification);

    // 💡 SMOOTHNESS FIX: Sync the notification immediately while in foreground
    _updateForegroundMetadata();

    // 💡 SYNC FIX: Trigger immediate playback state sync
    _syncVideoToNotification();
  }

  /// Syncs video player state TO the notification controls.
  void _syncVideoToNotification() {
    if (_isSyncing ||
        _audioHandler == null ||
        _isBackgrounded ||
        _currentVideoController == null)
      return;

    _isSyncing = true;
    try {
      final isPlaying = _currentVideoController!.isPlaying;
      final position = _currentVideoController!.position;
      final duration = _currentVideoController!.duration;

      // Keep track of the last position for background transitions
      _lastVideoPosition = position;

      // Update the playback state in the notification to match the video
      _audioHandler!.playbackState.add(
        _audioHandler!.playbackState.value.copyWith(
          controls: [
            MediaControl.skipToPrevious,
            MediaControl.rewind,
            if (isPlaying) MediaControl.pause else MediaControl.play,
            MediaControl.fastForward,
            MediaControl.skipToNext,
          ],
          systemActions: const {
            MediaAction.seek,
            MediaAction.seekForward,
            MediaAction.seekBackward,
            MediaAction.play,
            MediaAction.pause,
            MediaAction.stop,
            MediaAction.skipToNext,
            MediaAction.skipToPrevious,
          },
          androidCompactActionIndices: const [
            0,
            2,
            4,
          ], // Prev, Play/Pause, Next
          // 💡 SYNC FIX: Sync processing state (buffering, ready, etc.)
          processingState: _mapPlayerStateToAudioProcessingState(
            _currentVideoController!.currentState,
          ),
          playing: isPlaying,
          updatePosition: position,
        ),
      );

      // Also ensure duration and metadata are updated if it was zero before
      if ((_audioHandler!.mediaItem.value?.duration != duration &&
              duration != Duration.zero) ||
          (_currentVideoController!.isInitialized &&
              _audioHandler!.mediaItem.value?.artUri?.scheme != 'http')) {
        _updateForegroundMetadata();
      }
    } finally {
      _isSyncing = false;
    }
  }

  AudioProcessingState _mapPlayerStateToAudioProcessingState(
    PlayerState state,
  ) {
    switch (state) {
      case PlayerState.ready:
        return AudioProcessingState.ready;
      case PlayerState.buffering:
        return AudioProcessingState.buffering;
      case PlayerState.error:
        return AudioProcessingState.error;
    }
  }

  /// Called from AudioHandler when user taps Play in notification while app is in foreground.
  void playFromNotification() {
    if (_currentVideoController != null &&
        !_currentVideoController!.isPlaying) {
      debugPrint(
        'MediaSyncService: Play requested from notification (foreground/PiP)',
      );

      // If we are in foreground or PiP mode, we use the video controller.
      // backgrounded mode is only for pure audio playback.
      if (!_isBackgrounded) {
        _currentVideoController!.play();
      }
    }
  }

  /// Called from AudioHandler when user taps Pause in notification while app is in foreground.
  void pauseFromNotification() {
    if (PipService.isTransitioningFromPip) {
      debugPrint(
        'MediaSyncService: Skipping pause request during PiP transition',
      );
      return;
    }

    if (_currentVideoController != null && _currentVideoController!.isPlaying) {
      debugPrint(
        'MediaSyncService: Pause requested from notification (foreground)',
      );
      _currentVideoController!.pause();
    }
  }

  /// Called from AudioHandler when user seeks in notification while app is in foreground.
  void seekFromNotification(Duration position) {
    if (_currentVideoController != null) {
      debugPrint(
        'MediaSyncService: Seek requested from notification (foreground): ${position.inSeconds}s',
      );
      _currentVideoController!.controller?.seekTo(position);
    }
  }

  /// Called from AudioHandler when user fast forwards in notification while app is in foreground.
  void fastForwardFromNotification() {
    if (_currentVideoController != null) {
      debugPrint('MediaSyncService: Fast Forward requested from notification');
      _currentVideoController!.seekBy(const Duration(seconds: 10));
    }
  }

  /// Called from AudioHandler when user rewinds in notification while app is in foreground.
  void rewindFromNotification() {
    if (_currentVideoController != null) {
      debugPrint('MediaSyncService: Rewind requested from notification');
      _currentVideoController!.seekBy(const Duration(seconds: -10));
    }
  }

  /// Called from AudioHandler when user skips to next in notification.
  void skipToNextFromNotification() {
    debugPrint('MediaSyncService: Skip to next requested from notification');
    _onNextRequested?.call();
  }

  /// Called from AudioHandler when user skips to previous in notification.
  void skipToPreviousFromNotification() {
    debugPrint(
      'MediaSyncService: Skip to previous requested from notification',
    );
    _onPreviousRequested?.call();
  }

  /// Request to play the next recommended video (e.g. from in-player controls).
  void requestNextVideo() {
    _onNextRequested?.call();
  }

  /// Request to play the previous video (e.g. from in-player controls).
  void requestPreviousVideo() {
    _onPreviousRequested?.call();
  }

  /// Updates the MediaSession metadata while the video is in foreground.
  /// This ensures the notification is ready BEFORE the app is minimized.
  void _updateForegroundMetadata() {
    if (_audioHandler == null ||
        _currentVideo == null ||
        _currentVideoController == null)
      return;

    final playbackUrl = _currentVideoController!.currentPlaybackUrl;
    final artworkUrl = HlsProxyService().getProxiedUrl(
      ImageUtils.getVideoThumbnailUrl(_currentVideo!.videoThumbnail) ?? '',
    );

    // Update the notification metadata without starting just_audio playback
    _audioHandler!.mediaItem.add(
      MediaItem(
        id: _currentVideo!.videoId,
        album: 'Hiffi',
        title: _currentVideo!.videoTitle,
        artist: _currentVideo!.userUsername,
        artUri: Uri.tryParse(artworkUrl),
        duration: _currentVideoController!.duration,
        playable: true,
        extras: {'videoId': _currentVideo!.videoId, 'url': playbackUrl},
      ),
    );

    // Ensure playback state has navigation buttons
    _audioHandler!.playbackState.add(
      _audioHandler!.playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          MediaControl.rewind,
          if (_currentVideoController!.isPlaying)
            MediaControl.pause
          else
            MediaControl.play,
          MediaControl.fastForward,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 2, 4],
        processingState: AudioProcessingState.ready,
      ),
    );
  }

  /// Switches from video playback to background audio playback.
  ///
  /// This is called when the app goes to background (paused/inactive).
  /// The video player is paused and audio_service takes over playback.
  Future<void> switchToBackground() async {
    if (_isBackgrounded) {
      debugPrint('MediaSyncService: Already backgrounded, skipping');
      return;
    }

    if (PipService.isInPipMode.value || PipService.isTransitioningFromPip) {
      debugPrint(
        'MediaSyncService: In PiP or transitioning from PiP, skipping background audio switch',
      );
      return;
    }

    if (_currentVideoController == null || _currentVideo == null) {
      debugPrint(
        'MediaSyncService: Cannot switch to background - no active video',
      );
      return;
    }

    final videoController = _currentVideoController!.controller;
    if (videoController == null || !videoController.value.isInitialized) {
      debugPrint('MediaSyncService: Video controller not initialized');
      return;
    }

    debugPrint('MediaSyncService: Switching to background audio playback');

    _isSyncing = true; // Block listeners during transition
    try {
      // 1. Get current playback state from video player
      final isPlaying = videoController.value.isPlaying;
      _lastVideoPosition = videoController.value.position;
      final duration = _currentVideoController!.duration;

      debugPrint(
        'MediaSyncService: Video state - playing: $isPlaying, position: ${_lastVideoPosition?.inSeconds}s, duration: ${duration.inSeconds}s',
      );

      // 2. Pause video player (stop rendering)
      if (isPlaying) {
        await _currentVideoController!.pause();
        debugPrint('MediaSyncService: Video player paused');
      }

      // 3. Start background audio service
      if (_audioHandler != null && _lastVideoPosition != null) {
        final playbackUrl = _currentVideoController!.currentPlaybackUrl;
        final proxiedUrl = HlsProxyService().getProxiedUrl(playbackUrl);

        debugPrint(
          'MediaSyncService: Starting background audio via Proxy: $proxiedUrl',
        );

        await _audioHandler!.startPlayback(
          videoId: _currentVideo!.videoId,
          url: proxiedUrl,
          title: _currentVideo!.videoTitle,
          artist: _currentVideo!.userUsername,
          artwork: HlsProxyService().getProxiedUrl(
            ImageUtils.getVideoThumbnailUrl(_currentVideo!.videoThumbnail) ??
                '',
          ),
          duration: duration.inMilliseconds > 0 ? duration : null,
          position: _lastVideoPosition!,
          autoPlay: isPlaying,
          headers: {'x-api-key': ImageUtils.profileImageApiKey},
        );

        // Update background controls with next/prev
        _audioHandler!.playbackState.add(
          _audioHandler!.playbackState.value.copyWith(
            controls: [
              MediaControl.skipToPrevious,
              MediaControl.rewind,
              if (isPlaying) MediaControl.pause else MediaControl.play,
              MediaControl.fastForward,
              MediaControl.skipToNext,
            ],
            androidCompactActionIndices: const [0, 2, 4],
          ),
        );

        _isBackgrounded = true;
        debugPrint(
          'MediaSyncService: Successfully switched to background audio',
        );
      } else {
        debugPrint('MediaSyncService: Audio handler not available');
      }
    } catch (e, stackTrace) {
      debugPrint('MediaSyncService: Failed to switch to background: $e');
      debugPrint('MediaSyncService: Stack trace: $stackTrace');
      _isBackgrounded = false;

      // Try to resume video if background switch failed
      try {
        await _currentVideoController?.play();
      } catch (e) {
        debugPrint('MediaSyncService: Failed to resume video: $e');
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Switches from background audio back to foreground video playback.
  ///
  /// This is called when the app comes back to foreground (resumed).
  /// Audio service stops and video player resumes from the same position.
  Future<void> switchToForeground() async {
    if (!_isBackgrounded) {
      debugPrint('MediaSyncService: Not backgrounded, skipping');
      return;
    }

    if (_currentVideoController == null) {
      debugPrint('MediaSyncService: No video controller available');
      return;
    }

    debugPrint('MediaSyncService: Switching to foreground video playback');

    _isSyncing = true; // Block listeners during transition
    try {
      // 1. Get current position from audio handler
      Duration? position;
      if (_audioHandler != null) {
        position = _audioHandler!.currentPosition;
        final wasPlaying = _audioHandler!.isPlaying;

        debugPrint(
          'MediaSyncService: Audio state - position: ${position.inSeconds}s, playing: $wasPlaying',
        );

        // 2. Stop background audio service
        await _audioHandler!.stop();
        debugPrint('MediaSyncService: Background audio stopped');
      } else {
        // Fallback to last known position
        position = _lastVideoPosition;
      }

      // 3. Sync video controller to audio position
      final videoController = _currentVideoController!.controller;
      if (videoController != null && position != null) {
        // Seek to the position from audio playback
        await videoController.seekTo(position);
        debugPrint(
          'MediaSyncService: Video seeked to position: ${position.inSeconds}s',
        );

        // Resume video playback
        await _currentVideoController!.play();
        debugPrint('MediaSyncService: Video playback resumed');
      }

      _isBackgrounded = false;
      _lastVideoPosition = null;
      debugPrint('MediaSyncService: Successfully switched to foreground video');
    } catch (e, stackTrace) {
      debugPrint('MediaSyncService: Failed to switch to foreground: $e');
      debugPrint('MediaSyncService: Stack trace: $stackTrace');
      _isBackgrounded = false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Gets whether the service is currently in background mode
  bool get isBackgrounded => _isBackgrounded;

  /// Clears the current video player.
  /// Call this when the video player is being disposed.
  void clearCurrentPlayer(HlsPlayerController controller) {
    if (_currentVideoController == controller) {
      debugPrint(
        'MediaSyncService: Clearing current player for video ${_currentVideo?.videoId}',
      );
      _currentVideoController?.removeListener(_syncVideoToNotification);
      _currentVideoController = null;
      _currentVideo = null;

      // Stop background audio if it was playing for this video
      if (!_isBackgrounded) {
        _audioHandler?.stop();
      }
    }
  }

  /// Gets the current playback position (from audio if backgrounded, video if foregrounded)
  Duration? get currentPosition {
    if (_isBackgrounded && _audioHandler != null) {
      return _audioHandler!.currentPosition;
    } else if (_currentVideoController?.controller != null) {
      return _currentVideoController!.controller!.value.position;
    }
    return _lastVideoPosition;
  }

  void dispose() {
    debugPrint('MediaSyncService: dispose() called');
    _audioHandler?.stop();
    _currentVideoController = null;
    _currentVideo = null;
    _isBackgrounded = false;
    _lastVideoPosition = null;
  }
}
