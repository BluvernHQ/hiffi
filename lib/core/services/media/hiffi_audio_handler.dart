import 'dart:async';
import 'dart:ui';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:hiffi/core/services/media/media_sync_service.dart';

/// Production-grade AudioHandler with proper MediaSession support.
///
/// Implements:
/// - MediaItem with title, artist, artwork, duration
/// - PlaybackState with proper controls and actions
/// - Continuous position updates
/// - Seek support
/// - Proper state management for notification/lock screen controls
class HiffiAudioHandler extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  final _player = AudioPlayer();
  MediaItem? _currentMediaItem;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  HiffiAudioHandler() {
    // 💡 CRITICAL: Ensure plugins are registered in the background isolate
    DartPluginRegistrant.ensureInitialized();

    // Listen to player state changes and update PlaybackState
    _playerStateSubscription = _player.playerStateStream.listen((state) {
      // 💡 SYNC FIX: Only update from internal player if it's actually active
      if (state.processingState != ProcessingState.idle) {
        _updatePlaybackState();
      }
    });

    // Listen to position changes and update PlaybackState
    _positionSubscription = _player.positionStream.listen((position) {
      // 💡 SYNC FIX: Only update from internal player if it's actually active
      if (_player.playing) {
        _updatePlaybackState();
      }
    });

    // Listen to duration changes and update MediaItem
    _durationSubscription = _player.durationStream.listen((duration) {
      if (duration != null && _currentMediaItem != null) {
        mediaItem.add(_currentMediaItem!.copyWith(duration: duration));
      }
    });

    // Handle playback completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        playbackState.add(
          playbackState.value.copyWith(
            playing: false,
            processingState: AudioProcessingState.completed,
          ),
        );
      }
    });
  }

  /// Updates PlaybackState with current player state
  void _updatePlaybackState() {
    final state = _player.playerState;
    final position = _player.position;
    final buffered = _player.bufferedPosition;
    final speed = _player.speed;

    playbackState.add(
      PlaybackState(
        controls: [
          MediaControl.skipToPrevious,
          if (state.playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.skipToNext,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
          MediaAction.play,
          MediaAction.pause,
          MediaAction.stop,
        },
        androidCompactActionIndices: const [0, 1, 2],
        processingState: _mapProcessingState(state.processingState),
        playing: state.playing,
        updatePosition: position,
        bufferedPosition: buffered,
        speed: speed,
        updateTime: DateTime.now(),
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.loading;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() async {
    debugPrint('HiffiAudioHandler: play() called');
    if (_player.processingState == ProcessingState.idle) {
      // 💡 SYNC FIX: If background player is idle, we are likely in foreground.
      // Tell MediaSyncService to play the video.
      MediaSyncService().playFromNotification();
    } else {
      await _player.play();
      _updatePlaybackState();
    }
  }

  @override
  Future<void> pause() async {
    debugPrint('HiffiAudioHandler: pause() called');
    if (_player.processingState == ProcessingState.idle) {
      // 💡 SYNC FIX: If background player is idle, we are likely in foreground.
      // Tell MediaSyncService to pause the video.
      MediaSyncService().pauseFromNotification();
    } else {
      await _player.pause();
      _updatePlaybackState();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    debugPrint('HiffiAudioHandler: seek() to ${position.inSeconds}s');
    if (_player.processingState == ProcessingState.idle) {
      // 💡 SYNC FIX: If background player is idle, we are likely in foreground.
      // Tell MediaSyncService to seek the video.
      MediaSyncService().seekFromNotification(position);
    } else {
      await _player.seek(position);
      _updatePlaybackState();
    }
  }

  @override
  Future<void> stop() async {
    debugPrint('HiffiAudioHandler: stop() called');
    await _player.stop();
    _currentMediaItem = null;
    mediaItem.add(null);
    await super.stop();
  }

  @override
  Future<void> skipToNext() async {
    debugPrint('HiffiAudioHandler: skipToNext() called');
    MediaSyncService().skipToNextFromNotification();
  }

  @override
  Future<void> skipToPrevious() async {
    debugPrint('HiffiAudioHandler: skipToPrevious() called');
    MediaSyncService().skipToPreviousFromNotification();
  }

  /// Starts background audio playback from a video source.
  ///
  /// This method MUST be called with a complete MediaItem before playback starts
  /// to ensure notification/lock screen controls appear correctly.
  Future<void> startPlayback({
    required String videoId,
    required String url,
    required String title,
    String? artist,
    String? artwork,
    Duration? duration,
    required Duration position,
    Map<String, String>? headers,
  }) async {
    debugPrint(
      'HiffiAudioHandler: startPlayback() - videoId: $videoId, title: $title, position: ${position.inSeconds}s',
    );

    try {
      // 💡 CRITICAL: Set MediaItem BEFORE setting audio source
      // This ensures notification/lock screen controls appear immediately
      _currentMediaItem = MediaItem(
        id: videoId,
        album: 'Hiffi',
        title: title,
        artist: artist ?? 'Hiffi User',
        artUri: artwork != null ? Uri.tryParse(artwork) : null,
        duration: duration,
        // Enable seeking
        playable: true,
        // Additional metadata
        extras: {'videoId': videoId, 'url': url},
      );

      // Set MediaItem immediately so controls appear
      mediaItem.add(_currentMediaItem);
      debugPrint('HiffiAudioHandler: MediaItem set - controls should appear');

      // Set the audio source with headers (for HLS authentication)
      await _player.setAudioSource(
        AudioSource.uri(
          Uri.parse(url),
          headers: {
            ...?headers,
            'User-Agent': 'Hiffi/1.0 (Background AudioService)',
          },
        ),
        initialPosition: position,
      );

      debugPrint('HiffiAudioHandler: Audio source set, starting playback');

      // Start playing
      await _player.play();

      // Update playback state
      _updatePlaybackState();

      debugPrint('HiffiAudioHandler: Playback started successfully');
    } catch (e, stackTrace) {
      debugPrint('HiffiAudioHandler: Error starting playback: $e');
      debugPrint('HiffiAudioHandler: Stack trace: $stackTrace');

      // Clear MediaItem on error
      _currentMediaItem = null;
      mediaItem.add(null);

      rethrow;
    }
  }

  /// Gets the current playback position
  Duration get currentPosition => _player.position;

  /// Gets whether the player is currently playing
  bool get isPlaying => _player.playing;

  @override
  Future<void> onTaskRemoved() async {
    debugPrint('HiffiAudioHandler: onTaskRemoved() - stopping playback');
    await stop();
  }

  /// Cleanup method - call this when audio handler is no longer needed
  void cleanup() {
    debugPrint('HiffiAudioHandler: cleanup() called');
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _player.dispose();
  }
}
