import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/material.dart';
import 'package:hiffi/core/services/media/hiffi_audio_handler.dart';
import 'package:hiffi/core/services/hls_proxy_service.dart';
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
  StreamSubscription<AudioInterruptionEvent>? _interruptionSub;
  StreamSubscription<void>? _becomingNoisySub;

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
    _interruptionSub ??= session.interruptionEventStream.listen(
      _handleAudioInterruption,
    );
    _becomingNoisySub ??= session.becomingNoisyEventStream.listen((_) {
      _handleBecomingNoisy();
    });

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
    if (_isSyncing || _audioHandler == null || _currentVideoController == null)
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

  /// Marks that the app moved to background.
  ///
  /// In the unified playback model we no longer start a separate audio
  /// pipeline here; the same video player keeps owning playback and we
  /// just expose controls via the existing MediaSession.
  Future<void> switchToBackground() async {
    if (_isBackgrounded) {
      debugPrint('MediaSyncService: Already backgrounded, skipping');
      return;
    }

    debugPrint('MediaSyncService: Marking as backgrounded (unified player)');
    _isBackgrounded = true;
  }

  /// Marks that the app came back to foreground.
  ///
  /// In the unified playback model we don't restart a separate audio
  /// pipeline here; we just resume normal video-driven syncing.
  Future<void> switchToForeground() async {
    if (!_isBackgrounded) {
      debugPrint('MediaSyncService: Not backgrounded, skipping');
      return;
    }

    debugPrint('MediaSyncService: Marking as foreground (unified player)');
    _isBackgrounded = false;
    _lastVideoPosition = null;
  }

  /// Gets whether the service is currently in background mode
  bool get isBackgrounded => _isBackgrounded;

  void _handleAudioInterruption(AudioInterruptionEvent event) {
    final controller = _currentVideoController;
    if (controller == null) return;
    if (event.begin && controller.isPlaying) {
      debugPrint(
        'MediaSyncService: Audio interruption began (${event.type}) - pausing video',
      );
      controller.pause();
    }
  }

  void _handleBecomingNoisy() {
    final controller = _currentVideoController;
    if (controller == null) return;
    if (controller.isPlaying) {
      debugPrint('MediaSyncService: Output became noisy - pausing video');
      controller.pause();
    }
  }

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

      // Stop notification handler if we no longer have a player
      _audioHandler?.stop();
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
    _interruptionSub?.cancel();
    _interruptionSub = null;
    _becomingNoisySub?.cancel();
    _becomingNoisySub = null;
    _audioHandler?.stop();
    _currentVideoController = null;
    _currentVideo = null;
    _isBackgrounded = false;
    _lastVideoPosition = null;
  }
}
