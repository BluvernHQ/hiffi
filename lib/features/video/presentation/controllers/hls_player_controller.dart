import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:hiffi/core/services/hls_source_resolver.dart';
import 'package:hiffi/core/services/hls_proxy_service.dart';
import 'package:hiffi/core/utils/image_utils.dart';
import 'package:hiffi/features/video/domain/models/video_profile.dart';

/// Controller for HLS video playback lifecycle and state management.
///
/// Handles:
/// - Local HLS Proxy management (solves iOS headers & segment paths)
/// - Video Player controller initialization
/// - Playback state persistence (volume, mute, position)
/// - Quality selection
/// - App lifecycle management
/// - Error handling and retry logic
class HlsPlayerController extends ChangeNotifier {
  final HlsSourceResolver _resolver = HlsSourceResolver();
  final HlsProxyService _proxyService = HlsProxyService();
  final String videoId;
  final String baseVideoUrl;
  final bool autoPlay;
  final bool initialMuted;
  final VoidCallback? _onVideoEnded;

  VideoPlayerController? _videoPlayerController;
  List<VideoProfile> _profiles = [];
  VideoProfile? _currentProfile;

  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;
  PlayerState _currentState = PlayerState.ready;
  bool _isFullScreen = false;
  bool _hasEnded = false;

  // User preferences
  bool _userIntentMuted;
  double _userIntentVolume = 1.0;
  Duration? _lastKnownPosition;

  HlsPlayerController({
    required this.videoId,
    required this.baseVideoUrl,
    this.autoPlay = true,
    this.initialMuted = false,
    VoidCallback? onVideoEnded,
  }) : _userIntentMuted = initialMuted,
       _onVideoEnded = onVideoEnded {
    _initialize();
  }

  VideoPlayerController? get controller => _videoPlayerController;
  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  String? get errorMessage => _errorMessage;
  PlayerState get currentState => _currentState;
  bool get isFullScreen => _isFullScreen;
  List<VideoProfile> get profiles => _profiles;
  VideoProfile? get currentProfile => _currentProfile;
  bool get isMuted => _userIntentMuted;
  double get volume => _userIntentVolume;

  /// Pauses the video player if it's currently playing
  Future<void> pause() async {
    if (_videoPlayerController != null &&
        _videoPlayerController!.value.isPlaying) {
      debugPrint('HlsPlayerController: Pausing playback');
      await _videoPlayerController!.pause();
    }
  }

  /// Plays the video player if it's initialized and not already playing
  Future<void> play() async {
    if (_videoPlayerController != null &&
        !_videoPlayerController!.value.isPlaying &&
        _videoPlayerController!.value.isInitialized) {
      debugPrint('HlsPlayerController: Resuming playback');
      await _videoPlayerController!.play();
    }
  }

  void setFullScreen(bool value) {
    if (_isFullScreen == value) return;
    _isFullScreen = value;
    notifyListeners();
  }

  Future<void> _initialize() async {
    try {
      await _loadUserPreferences();
      // Start the local proxy before anything else
      await _proxyService.start();
      await _fetchProfiles();
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

  Future<void> _fetchProfiles() async {
    try {
      final profilesUrl = _resolver.resolveProfilesUrl(baseVideoUrl);
      if (profilesUrl == null) {
        _profiles = [VideoProfile.auto(_resolver.resolveHlsUrl(baseVideoUrl))];
        return;
      }

      final response = await http.get(
        Uri.parse(profilesUrl),
        headers: {'x-api-key': ImageUtils.profileImageApiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> profilesJson = data['profiles'] ?? [];

        final masterUrl = _resolver.resolveHlsUrl(baseVideoUrl);
        _profiles = [
          VideoProfile.auto(masterUrl),
          ...profilesJson.map((j) => VideoProfile.fromJson(j, baseVideoUrl)),
        ];
      } else {
        // Fallback to Auto-only
        _profiles = [VideoProfile.auto(_resolver.resolveHlsUrl(baseVideoUrl))];
      }
    } catch (e) {
      debugPrint('Failed to fetch profiles: $e');
      // Fallback to Auto-only
      _profiles = [VideoProfile.auto(_resolver.resolveHlsUrl(baseVideoUrl))];
    }
  }

  Future<void> _setupPlayer({VideoProfile? targetProfile}) async {
    try {
      _hasError = false;
      _errorMessage = null;
      _currentState = PlayerState.buffering;

      // Dispose existing controller
      await _disposeController();

      // Determine HLS URL
      final profile =
          targetProfile ??
          (_profiles.isNotEmpty
              ? _profiles.first
              : VideoProfile.auto(_resolver.resolveHlsUrl(baseVideoUrl)));
      _currentProfile = profile;

      // 1. Get the proxied URL
      final proxiedUrl = _proxyService.getProxiedUrl(profile.playlistUrl);
      debugPrint('HLS Player: Loading via Proxy: $proxiedUrl');

      // 2. Create Video Player controller
      // We don't need httpHeaders here anymore because the proxy handles them!
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(proxiedUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize the controller
      debugPrint('HLS Player: Initializing controller...');
      await _videoPlayerController!.initialize();
      debugPrint('HLS Player: Controller initialized successfully');

      // Set initial volume
      await _videoPlayerController!.setVolume(
        _userIntentMuted ? 0.0 : _userIntentVolume,
      );

      // Load saved position from SharedPreferences (for returning from auth)
      // Always try to load, as it might have been saved before navigation
      final savedPosition = await _loadPlaybackPosition();
      if (savedPosition != null) {
        _lastKnownPosition = savedPosition;
      }

      // Set initial position if available (don't seek if position is at start)
      if (_lastKnownPosition != null &&
          _lastKnownPosition!.inMilliseconds > 0) {
        await _videoPlayerController!.seekTo(_lastKnownPosition!);
        debugPrint(
          'HlsPlayerController: Restored position to ${_lastKnownPosition!.inSeconds}s for videoId $videoId',
        );
      }

      // Subscribe to state changes
      _videoPlayerController!.addListener(_handlePlayerStateChange);

      // Auto-play if requested
      if (autoPlay) {
        await _videoPlayerController!.play().catchError((e) {
          debugPrint("Autoplay blocked: $e");
          // Fallback to muted autoplay
          _videoPlayerController!.setVolume(0.0);
          _videoPlayerController!.play();
        });
      }

      _isInitialized = true;
      _currentState = PlayerState.ready;
      notifyListeners();
    } catch (e) {
      _handleError('Setup failed: $e');
    }
  }

  void _handlePlayerStateChange() {
    if (_videoPlayerController == null) return;

    if (_videoPlayerController!.value.hasError) {
      _handleError(
        _videoPlayerController!.value.errorDescription ?? 'Unknown error',
      );
    }

    if (_videoPlayerController!.value.isBuffering) {
      _currentState = PlayerState.buffering;
      notifyListeners();
    } else if (_videoPlayerController!.value.isPlaying) {
      _currentState = PlayerState.ready;
      notifyListeners();
    }

    // Check if video has ended
    final position = _videoPlayerController!.value.position;
    final duration = _videoPlayerController!.value.duration;
    if (duration.inMilliseconds > 0 &&
        position.inMilliseconds >= duration.inMilliseconds - 100) {
      // Video has ended (with 100ms tolerance for buffering)
      if (!_hasEnded) {
        _hasEnded = true;
        _onVideoEnded?.call();
        debugPrint(
          'HlsPlayerController: Video ended - position: ${position.inSeconds}s, duration: ${duration.inSeconds}s',
        );
      }
    } else if (_hasEnded &&
        position.inMilliseconds < duration.inMilliseconds - 1000) {
      // Video has been seeked back or restarted
      _hasEnded = false;
    }

    // Save position periodically
    _lastKnownPosition = position;
  }

  void _handleError(String message) {
    debugPrint('HLS Player Error: $message');
    _hasError = true;
    _errorMessage = message;
    _currentState = PlayerState.error;
    notifyListeners();
  }

  Future<void> retry() async {
    await _setupPlayer();
  }

  Future<void> changeQuality(VideoProfile profile) async {
    if (profile == _currentProfile) return;
    await _setupPlayer(targetProfile: profile);
  }

  Future<void> toggleMute() async {
    if (_videoPlayerController == null) return;

    _userIntentMuted = !_userIntentMuted;
    await _videoPlayerController!.setVolume(
      _userIntentMuted ? 0.0 : _userIntentVolume,
    );
    await _saveUserPreferences();
    notifyListeners();
  }

  Future<void> setVolume(double volume) async {
    if (_videoPlayerController == null) return;

    _userIntentVolume = volume.clamp(0.0, 1.0);
    if (!_userIntentMuted) {
      await _videoPlayerController!.setVolume(_userIntentVolume);
    }
    await _saveUserPreferences();
    notifyListeners();
  }

  Future<void> _savePlaybackPosition() async {
    if (_videoPlayerController?.value.position != null) {
      _lastKnownPosition = _videoPlayerController!.value.position;

      // Persist to SharedPreferences so position is preserved across navigation
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(
          'video_position_$videoId',
          _lastKnownPosition!.inMilliseconds,
        );
        debugPrint(
          'HlsPlayerController: Saved position ${_lastKnownPosition!.inSeconds}s for videoId $videoId',
        );
      } catch (e) {
        debugPrint('Failed to save playback position: $e');
      }
    }
  }

  /// Loads saved playback position from SharedPreferences
  Future<Duration?> _loadPlaybackPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final positionMs = prefs.getInt('video_position_$videoId');
      if (positionMs != null) {
        final position = Duration(milliseconds: positionMs);
        debugPrint(
          'HlsPlayerController: Loaded saved position ${position.inSeconds}s for videoId $videoId',
        );
        return position;
      }
    } catch (e) {
      debugPrint('Failed to load playback position: $e');
    }
    return null;
  }

  /// Clears saved playback position for a video (e.g., when starting a new video)
  static Future<void> clearPlaybackPosition(String videoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('video_position_$videoId');
      debugPrint(
        'HlsPlayerController: Cleared saved position for videoId $videoId',
      );
    } catch (e) {
      debugPrint('Failed to clear playback position: $e');
    }
  }

  Future<void> _disposeController() async {
    await _savePlaybackPosition();
    if (_videoPlayerController != null) {
      _videoPlayerController!.removeListener(_handlePlayerStateChange);
    }
    await _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  @override
  void dispose() {
    debugPrint('HlsPlayerController: dispose() called for videoId $videoId');
    _disposeController();
    super.dispose();
    debugPrint('HlsPlayerController: dispose() complete for videoId $videoId');
  }
}

/// Player state enum
enum PlayerState { ready, buffering, error }
