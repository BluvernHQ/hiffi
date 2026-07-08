import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/data/user_repository.dart';
import '../../../user/domain/models/user_model.dart';
import 'package:hiffi/features/video/presentation/controllers/video_comments_controller.dart';
import 'package:hiffi/features/video/presentation/widgets/video_comments_section.dart';
import '../../../../core/connectivity/connectivity_controller.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/utils/fullscreen_manager.dart';
import '../../../../core/utils/error_toast_utils.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/widgets/network_page_shell.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/services/pip_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/services/media/media_sync_service.dart';
import '../../../../core/routes/app_router.dart';
import '../../../../core/services/playlist_session_storage.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../../core/analytics/first_party_analytics_service.dart';
import '../../../playlist/domain/models/playlist_models.dart';
import '../../../playlist/presentation/widgets/add_to_playlist_sheet.dart';
import '../../../liked/presentation/viewmodels/liked_videos_view_model.dart';
import '../../../flags/presentation/widgets/report_flag_sheet.dart';
import '../coordinators/video_player_coordinator.dart';
import '../widgets/video_playback_options_sheet.dart';
import '../widgets/video_player_metadata_section.dart';
import '../widgets/hls_video_player.dart';
import '../widgets/video_playlist_queue.dart';
import '../widgets/video_suggested_section.dart';
import '../controllers/hls_player_controller.dart';

/// Vertical space above and below the divider between suggested videos and comments.
const double _kSuggestedToCommentsGap = 12;

/// Result of the sign-in prompt on the video page (guest like/follow/etc.).
enum _SignInPromptResult { cancelled, signIn, signUp }

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.video,
    this.videoId,
    this.returningFromAuth = false,
    this.initialResumePosition,
    this.playlistSession,
  });

  // Simple cache to store video temporarily when navigating away for authentication
  static VideoModel? _cachedVideo;
  static String? _cachedVideoId;

  static void cacheVideo(String videoId, VideoModel video) {
    _cachedVideo = video;
    _cachedVideoId = videoId;
  }

  static VideoModel? getCachedVideo(String videoId) {
    if (_cachedVideoId == videoId) {
      return _cachedVideo;
    }
    return null;
  }

  static void clearCache() {
    _cachedVideo = null;
    _cachedVideoId = null;
  }

  final VideoModel video;
  final String? videoId;
  final bool returningFromAuth; // True if returning from auth pages

  /// When non-null (e.g. watch history), seek here on first load instead of prefs alone.
  final Duration? initialResumePosition;
  final PlaylistSession? playlistSession;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver, RouteAware {
  late VideoModel _video;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNoInternet = false;
  bool _isDescriptionExpanded = false;
  bool _isUpvoted = false;
  bool _isDownvoted = false;
  bool _isLikeActionInFlight = false;
  int _upvoteCount = 0;
  int _downvoteCount = 0;
  String? _videoUrlFromApi;
  String? _playConversionSentForVideoId;

  // Follow state
  bool _isFollowing = false;
  bool _isLoadingFollowStatus = false;
  UserModel? _videoOwner;
  UserModel? _currentUser;

  // Comments state
  late VideoCommentsController _commentsController;

  // Player key - changing this forces Flutter to dispose and recreate the player
  // When videoId changes, this key changes, forcing complete disposal and recreation
  Key _playerKey = const ValueKey('player');

  // Flag to prevent autoplay when navigating away
  bool _isNavigatingAway = false;

  // Flag to prevent autoplay when returning from auth (video should be paused)
  bool _isReturningFromAuth = false;

  /// Android: remembers if video was playing before we paused for app background.
  bool _androidWasPlayingBeforeBackground = false;

  // Suggested videos for autoplay (loaded on page; not tied to portrait-only subtree)
  List<VideoModel> _suggestedVideos = [];
  String? _suggestedSeed;
  bool _suggestedLoading = false;
  bool _suggestedError = false;
  bool _suggestedNoInternet = false;
  bool _isAddToPlaylistSheetOpen = false;

  // Previous-video stack: when user taps Next we push current; Previous pops and navigates back
  final VideoPlayerCoordinator _playerCoordinator = VideoPlayerCoordinator();
  PlaylistSession? _playlistSession;
  final Map<String, VideoModel> _playlistQueueVideoCache = {};

  // Track orientation for auto-fullscreen logic
  Orientation? _lastOrientation;
  bool _isAutoRotating = false;

  // Cooldown to prevent premature fullscreen exit after manual entry
  DateTime? _fullscreenEnteredAt;
  DateTime? _fullscreenExitedAt;
  bool _lastKnownFullscreenState = false;

  RouteObserver<ModalRoute<void>>? _routeObserver;
  bool _routeAwareSubscribed = false;

  /// iOS: after [inactive], probe once for [paused]/[hidden] to start PiP earlier than
  /// relying on native notifications alone (closer to Hotstar-style timing).
  Timer? _iosInactivePipProbe;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Allow both portrait and landscape orientations for this page
    FullscreenManager.resetOrientation();

    _video = widget.video;
    _playlistSession = widget.playlistSession;
    _playlistQueueVideoCache[_video.videoId] = _video;
    _primePlaylistQueueMetadata();

    // Set flag if returning from auth - video should not autoplay
    _isReturningFromAuth = widget.returningFromAuth;
    if (_isReturningFromAuth) {
      debugPrint('VideoPlayerPage: Returning from auth - video will be paused');
      // When returning from auth, we want to restore the position where it was paused
      // So we don't clear the position here - it will be loaded from SharedPreferences
    } else if (widget.initialResumePosition == null) {
      // Normal navigation: clear stale resume so we don't jump unexpectedly.
      HlsPlayerController.clearPlaybackPosition(_video.videoId);
      debugPrint(
        'VideoPlayerPage: Cleared saved position for normal navigation',
      );
    }

    _commentsController = VideoCommentsController(
      repository: context.read<VideoRepository>(),
      videoId: _video.videoId,
      userRepository: context.read<UserRepository>(),
      connectivityService: context.read<NetworkConnectivityService>(),
    );

    _upvoteCount = _video.videoUpvotes;
    _downvoteCount = _video.videoDownvotes;
    _syncPlaylistSessionForCurrentVideo();

    // Initialize vote status based on user's current vote
    if (_video.userVoteStatus != null) {
      if (_video.userVoteStatus == 'upvoted') {
        _isUpvoted = true;
        _isDownvoted = false;
      } else if (_video.userVoteStatus == 'downvoted') {
        _isUpvoted = false;
        _isDownvoted = true;
      }
    }

    _fetchAndInitializePlayer();
    _loadUserAndFollowStatus();

    // 💡 SYNC FIX: Register navigation callbacks for notification controls
    MediaSyncService().registerNavigationCallbacks(
      onNext: () => _playNextVideo(userInitiated: true),
      onPrevious: _playPreviousVideo,
      hasPreviousVideo: () => _playerCoordinator.hasPrevious,
    );

    // 5️⃣ Fetch lightweight preview data
    _commentsController.fetchLatestComment();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) PipService.setVideoPlayerPageSurfaceActive(true);
      _loadSuggestedVideosForPlayer();
    });
  }

  @override
  void didUpdateWidget(VideoPlayerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playlistSession != oldWidget.playlistSession &&
        widget.playlistSession != null) {
      _playlistSession = widget.playlistSession;
      _syncPlaylistSessionForCurrentVideo();
      _primePlaylistQueueMetadata();
      if (mounted) setState(() {});
    }
  }

  @override
  void activate() {
    super.activate();
    // Route is visible again (e.g. popped a screen that was on top of the player).
    PipService.setVideoPlayerPageSurfaceActive(true);
    _refreshVoteStateIfAuthenticated();
  }

  @override
  void deactivate() {
    // Do not clear PiP surface here: on Home/Recents, [isInPipMode] is still false until
    // native PiP starts, so we'd tell Android isPlayerActive=false and break the mini player.
    // In-app "another route on top" is handled by [didPushNext] / [didPopNext].
    // Only pause for in-app route coverage while the app is still foregrounded.
    // On iOS, background transitions also trigger deactivate(), and pausing here
    // breaks background playback.
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    final isForegroundRouteTransition =
        lifecycleState == AppLifecycleState.resumed;
    if (!PipService.isInPipMode.value &&
        !PipService.pipUiHeldUntilReconnect.value &&
        !PipService.isTransitioningFromPip &&
        isForegroundRouteTransition &&
        !_isNavigatingAway) {
      debugPrint('VideoPlayerPage: deactivate() – pausing (not PiP)');
      _pauseVideo();
    } else {
      debugPrint(
        'VideoPlayerPage: deactivate() – background/PiP transition, NOT pausing',
      );
    }
    super.deactivate();
  }

  String _generateSuggestedSeed() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        32,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<bool> _isDeviceOnline() async {
    final connectivity = context.read<NetworkConnectivityService>();
    await connectivity.ensureInitialized();
    return connectivity.isConnected;
  }

  Future<void> _loadSuggestedVideosForPlayer({bool useNewSeed = false}) async {
    final forVideoId = _video.videoId;
    if (!await _isDeviceOnline()) {
      if (!mounted || _video.videoId != forVideoId) return;
      setState(() {
        _suggestedLoading = false;
        _suggestedError = true;
        _suggestedNoInternet = true;
      });
      return;
    }
    setState(() {
      _suggestedLoading = true;
      _suggestedError = false;
      _suggestedNoInternet = false;
    });
    try {
      if (useNewSeed || _suggestedSeed == null) {
        _suggestedSeed = _generateSuggestedSeed();
      }
      final videoRepository = context.read<VideoRepository>();
      final videos = await videoRepository.getVideos(
        page: 1,
        limit: 24,
        seed: _suggestedSeed,
      );
      if (!mounted || _video.videoId != forVideoId) {
        return;
      }
      setState(() {
        _suggestedVideos = videos
            .where((video) => video.videoId != forVideoId)
            .take(12)
            .toList();
        _suggestedLoading = false;
        _suggestedError = false;
        _suggestedNoInternet = false;
      });
    } catch (e) {
      if (!mounted || _video.videoId != forVideoId) {
        return;
      }
      setState(() {
        _suggestedLoading = false;
        _suggestedError = true;
        _suggestedNoInternet = isOfflineError(e);
      });
    }
  }

  void _playNextVideo({required bool userInitiated}) {
    if (userInitiated) {
      final nextTag = _playlistSession != null
          ? AnalyticsTags.playerNextPlaylist
          : AnalyticsTags.playerNextRecommended;
      unawaited(
        AnalyticsCapture.click(
          context,
          elementUiName: nextTag,
          screenName: 'watch',
          videoId: _video.videoId,
          videoTitle: _video.videoTitle,
        ),
      );
      unawaited(
        AnalyticsCapture.conversion(
          context,
          eventName: AnalyticsEvents.conversionNextClicked,
          screenName: 'watch',
          videoId: _video.videoId,
          videoTitle: _video.videoTitle,
          properties: {
            'source': _playlistSession != null ? 'playlist' : 'suggested',
          },
        ),
      );
    }

    final playlist = _playlistSession;
    if (playlist != null && playlist.isValid) {
      final nextIndex = playlist.currentIndex + 1;
      if (nextIndex < playlist.videoIds.length) {
        final nextVideoId = playlist.videoIds[nextIndex];
        _playPlaylistItem(nextVideoId, nextIndex);
        return;
      }
    }
    if (_suggestedVideos.isEmpty) {
      debugPrint('VideoPlayerPage: No suggested videos available for autoplay');
      return;
    }

    // Find the next video in the suggested list (first one that's not the current video)
    VideoModel? nextVideo;
    for (final video in _suggestedVideos) {
      if (video.videoId != _video.videoId) {
        nextVideo = video;
        break;
      }
    }

    if (nextVideo != null) {
      debugPrint(
        'VideoPlayerPage: Autoplay/Next - navigating to ${nextVideo.videoId}',
      );
      final previousSession = _playlistSession;
      _clearPlaylistSession();
      _replaceVideo(
        nextVideo,
        pushCurrentToHistory: true,
        historyPlaylistSessionOverride: previousSession,
      );
    } else {
      debugPrint('VideoPlayerPage: Could not find a suitable next video');
    }
  }

  void _playPreviousVideo() {
    final playlist = _playlistSession;
    if (playlist != null && playlist.isValid) {
      final prevIndex = playlist.currentIndex - 1;
      if (prevIndex >= 0) {
        final prevVideoId = playlist.videoIds[prevIndex];
        _playPlaylistItem(prevVideoId, prevIndex);
        return;
      }
    }
    if (!_playerCoordinator.hasPrevious) {
      debugPrint('VideoPlayerPage: No previous video in history');
      return;
    }
    final previous = _playerCoordinator.popPrevious();
    if (previous == null) return;
    debugPrint(
      'VideoPlayerPage: Previous - navigating back to ${previous.video.videoId}',
    );
    _replaceVideo(
      previous.video,
      pushCurrentToHistory: false,
      restorePlaylistSession: true,
      playlistSessionOverride: previous.playlistSession,
    );
  }

  void _onVideoEnded() {
    if (_playlistSession?.autoplay == false) {
      return;
    }
    debugPrint('VideoPlayerPage: Video ended - triggering autoplay');
    _playNextVideo(userInitiated: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routeObserver ??= context.read<AppRouter>().routeObserver;
    final route = ModalRoute.of(context);
    if (!_routeAwareSubscribed && route != null) {
      _routeObserver!.subscribe(this, route);
      _routeAwareSubscribed = true;
    }
  }

  @override
  void didPushNext() {
    // Another GoRoute was pushed on top (e.g. login) — block PiP from Home until user returns.
    PipService.setVideoPlayerPageSurfaceActive(false);
    unawaited(_pauseVideo());
  }

  @override
  void didPopNext() {
    // Covered route was popped; video page is visible again.
    PipService.setVideoPlayerPageSurfaceActive(true);
    _refreshVoteStateIfAuthenticated();
  }

  /// Await native `enterPiP` before [MediaSyncService.switchToBackground] so the
  /// platform channel is not starved behind other work while iOS is suspending.
  Future<void> _iosEnterPipBeforeMarkingBackground() async {
    await PipService.enterPiP();
    if (!mounted) return;
    debugPrint('VideoPlayerPage: lifecycle paused – going to background');
    MediaSyncService().switchToBackground();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.inactive) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        if (mounted &&
            !_isLoading &&
            !_hasError &&
            _videoUrlFromApi != null &&
            !PipService.isInPipMode.value &&
            !PipService.pipUiHeldUntilReconnect.value &&
            !PipService.isTransitioningFromPip &&
            PipService.iosPipNudgeEligible) {
          unawaited(PipService.primeIosBackgroundPiP());
        }
        _iosInactivePipProbe?.cancel();
        _iosInactivePipProbe = Timer(const Duration(milliseconds: 12), () {
          if (!mounted) return;
          final phase = WidgetsBinding.instance.lifecycleState;
          if (phase != AppLifecycleState.paused &&
              phase != AppLifecycleState.hidden) {
            return;
          }
          if (!PipService.isTransitioningFromPip &&
              !PipService.pipUiHeldUntilReconnect.value &&
              PipService.iosPipNudgeEligible) {
            unawaited(PipService.enterPiP());
          }
        });
      }
    } else if (state == AppLifecycleState.paused) {
      // When entering PiP the lifecycle fires "paused" too.
      // We must NOT pause the player or start a background engine here.
      if (PipService.isInPipMode.value ||
          PipService.pipUiHeldUntilReconnect.value ||
          PipService.isTransitioningFromPip) {
        debugPrint('VideoPlayerPage: lifecycle paused – inside PiP, ignoring');
        // We skip [switchToBackground] here, but iOS still needs a fresh
        // MPRemoteCommandCenter / Now Playing update so prev–play–next appear
        // on the lock screen like other media apps.
        MediaSyncService().syncNowPlayingFromVideoIfPossible();
        return;
      }
      if (defaultTargetPlatform == TargetPlatform.iOS &&
          PipService.iosPipNudgeEligible) {
        unawaited(_iosEnterPipBeforeMarkingBackground());
      } else {
        debugPrint('VideoPlayerPage: lifecycle paused – going to background');
        MediaSyncService().switchToBackground();
      }

      // Android: stop decoding against a Surface that Android is about to tear down.
      // Helps avoid stale MediaCodec / ExoPlayer state when returning hours later.
      if (defaultTargetPlatform == TargetPlatform.android &&
          !_isLoading &&
          !_hasError &&
          _videoUrlFromApi != null) {
        final controller = HlsVideoPlayer.getController(_video.videoId);
        final wasPlaying =
            controller != null &&
            !controller.isDisposed &&
            controller.isPlaying;
        _androidWasPlayingBeforeBackground = wasPlaying;
        unawaited(HlsVideoPlayer.pausePlayer(_video.videoId));
      }
    } else if (state == AppLifecycleState.resumed) {
      _iosInactivePipProbe?.cancel();
      _iosInactivePipProbe = null;
      debugPrint('VideoPlayerPage: lifecycle resumed – back to foreground');
      MediaSyncService().switchToForeground();

      final shouldResumePlayback = _androidWasPlayingBeforeBackground;
      _androidWasPlayingBeforeBackground = false;

      if (defaultTargetPlatform == TargetPlatform.android &&
          !_isLoading &&
          !_hasError &&
          _videoUrlFromApi != null &&
          !_isReturningFromAuth) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            HlsVideoPlayer.onAndroidLifecycleResumedFromBackground(
              _video.videoId,
              resumePlaybackIntent: shouldResumePlayback,
            ),
          );
        });
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Safely get orientation from platform dispatcher to detect changes even in fullscreen
    final view = View.of(context);
    final orientation = view.physicalSize.width > view.physicalSize.height
        ? Orientation.landscape
        : Orientation.portrait;

    if (_lastOrientation != orientation) {
      debugPrint('VideoPlayerPage: Orientation changed to $orientation');
      final oldOrientation = _lastOrientation;
      _lastOrientation = orientation;

      // Only handle if it was initialized
      if (oldOrientation != null) {
        Future.microtask(() {
          if (mounted) _handleOrientationChange(orientation);
        });
      }
    }
    // Note: Removed the aggressive auto-exit logic that was causing fullscreen
    // to exit prematurely when entered via button while in portrait orientation.
    // The normal orientation change handling above will take care of exiting
    // when the user actually rotates to portrait.
  }

  Future<void> _pausePlaybackOnly() async {
    await HlsVideoPlayer.pausePlayer(_video.videoId);
    final controller = HlsVideoPlayer.getController(_video.videoId);
    if (controller != null && !controller.isDisposed) {
      controller.pause();
    }
  }

  Future<void> _pauseVideo({bool updateUiState = true}) async {
    _isNavigatingAway = true;

    debugPrint(
      'VideoPlayerPage: _pauseVideo() called - pausing player and saving position',
    );

    FirstPartyAnalyticsService? analytics;
    if (mounted && context.mounted) {
      analytics = context.read<FirstPartyAnalyticsService>();
    }
    final videoId = _video.videoId;
    final videoTitle = _video.videoTitle;

    await _pausePlaybackOnly();

    if (analytics != null) {
      unawaited(
        analytics.capture(
          AnalyticsEvents.click,
          elementUiName: AnalyticsTags.pausedVideo,
          screenName: 'watch',
          videoId: videoId,
          videoTitle: videoTitle,
        ),
      );
    }

    if (updateUiState && mounted) {
      setState(() {});
    }
  }

  Future<void> _resumeVideo() async {
    if (_videoUrlFromApi != null) {
      debugPrint('VideoPlayerPage: _resumeVideo() called - resuming player');
      FirstPartyAnalyticsService? analytics;
      final shouldTrackPlayConversion =
          _playConversionSentForVideoId != _video.videoId;
      if (mounted && context.mounted) {
        analytics = context.read<FirstPartyAnalyticsService>();
      }
      final videoId = _video.videoId;
      final videoTitle = _video.videoTitle;
      final playlistSession = _playlistSession;

      await HlsVideoPlayer.playPlayer(videoId);

      if (shouldTrackPlayConversion) {
        _playConversionSentForVideoId = videoId;
        if (analytics != null) {
          unawaited(
            analytics.capture(
              AnalyticsEvents.conversionPlayStarted,
              screenName: 'watch',
              videoId: videoId,
              videoTitle: videoTitle,
              properties: {
                'source_path': '/watch/$videoId',
                'source': 'watch',
                if (playlistSession != null) 'source_path': 'playlist',
              },
            ),
          );
        }
      }

      if (analytics != null) {
        unawaited(
          analytics.capture(
            AnalyticsEvents.click,
            elementUiName: AnalyticsTags.playedVideo,
            screenName: 'watch',
            videoId: videoId,
            videoTitle: videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: videoId,
              source: 'watch',
            ),
          ),
        );
      }

      if (_isNavigatingAway) {
        setState(() {
          _isNavigatingAway = false;
        });
      }
    }
  }

  void _handleBackNavigation() {
    final controller = HlsVideoPlayer.getController(_video.videoId);
    if (controller != null && controller.isFullScreen) {
      debugPrint(
        'VideoPlayerPage: Back button pressed in fullscreen - exiting fullscreen',
      );
      controller.exitFullScreen();
      FullscreenManager.exitFullscreen(); // Force orientation reset
      return;
    }

    debugPrint('VideoPlayerPage: Back button pressed');
    _pauseVideo();
    if (context.canPop()) {
      context.pop();
    } else {
      // If this player is in an active playlist context, back should return
      // to playlists instead of home.
      if (_playlistSession != null) {
        context.go('/playlists');
      } else {
        context.go('/home');
      }
    }
  }

  Future<void> _replaceVideo(
    VideoModel newVideo, {
    bool pushCurrentToHistory = false,
    bool restorePlaylistSession = false,
    PlaylistSession? playlistSessionOverride,
    PlaylistSession? historyPlaylistSessionOverride,
  }) async {
    debugPrint(
      'VideoPlayerPage: Replacing video ${_video.videoId} with ${newVideo.videoId}',
    );

    // Replacing the player tears down the native AVPlayerLayer; iOS then emits a
    // spurious PiP "stopped" — suppress so we do not pause the new clip in background.
    if (PipService.isInPipMode.value) {
      PipService.suppressNextPipStoppedForControllerReplacement();
    }
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        (MediaSyncService().isBackgrounded ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.paused)) {
      PipService.markIosPipReattachAfterPlayerSwap();
    }

    if (pushCurrentToHistory) {
      _playerCoordinator.pushCurrent(
        video: _video,
        playlistSession: historyPlaylistSessionOverride ?? _playlistSession,
      );
      debugPrint(
        'VideoPlayerPage: Pushed current to history (size ${_playerCoordinator.historyLength})',
      );
    }

    // Permanently release the old video's controller before switching.
    // This is a deliberate video change, not a PiP rebuild, so we dispose now.
    HlsVideoPlayer.disposeForVideo(
      _video.videoId,
      isSwitchingToAnotherVideo: true,
    );

    await HlsPlayerController.clearPlaybackPosition(newVideo.videoId);

    _isNavigatingAway = false;
    _isReturningFromAuth = false;

    setState(() {
      _playerKey = ValueKey('player_${newVideo.videoId}');
      _video = newVideo;
      _playlistQueueVideoCache[newVideo.videoId] = newVideo;
      if (restorePlaylistSession) {
        _playlistSession = playlistSessionOverride;
      }
      _isLoading = true;
      _hasError = false;
      _isDescriptionExpanded = false;
      _videoUrlFromApi = null;

      _upvoteCount = newVideo.videoUpvotes;
      _downvoteCount = newVideo.videoDownvotes;
      _isUpvoted = false;
      _isDownvoted = false;
      if (newVideo.userVoteStatus == 'upvoted') {
        _isUpvoted = true;
      } else if (newVideo.userVoteStatus == 'downvoted') {
        _isDownvoted = true;
      }

      _commentsController.dispose();
      _commentsController = VideoCommentsController(
        repository: context.read<VideoRepository>(),
        videoId: newVideo.videoId,
        userRepository: context.read<UserRepository>(),
        connectivityService: context.read<NetworkConnectivityService>(),
      );
    });

    if (restorePlaylistSession) {
      if (_playlistSession != null) {
        await PlaylistSessionStorage().save(_playlistSession!);
      } else {
        await PlaylistSessionStorage().clear();
      }
    }

    await _fetchAndInitializePlayer();
    await _loadUserAndFollowStatus();
    _commentsController.fetchLatestComment();
    // Keep recommended rail stable while stepping through an active playlist.
    // Refresh suggestions only when playlist context has ended/cleared.
    if (_playlistSession == null) {
      await _loadSuggestedVideosForPlayer(useNewSeed: true);
    }
    _primePlaylistQueueMetadata();
  }

  Future<void> _loadUserAndFollowStatus() async {
    if (!await _isDeviceOnline()) return;
    try {
      final userRepository = context.read<UserRepository>();
      try {
        _currentUser = await userRepository.getCurrentUser();
        setState(() {});
      } catch (e) {
        debugPrint('Failed to load current user: $e');
      }

      if (_video.userUsername.isNotEmpty &&
          _currentUser?.username != _video.userUsername) {
        setState(() {
          _isLoadingFollowStatus = true;
        });

        try {
          _videoOwner = await userRepository.getUser(_video.userUsername);
          setState(() {
            _isLoadingFollowStatus = false;
          });
        } catch (e) {
          debugPrint('Failed to load user: $e');
          setState(() {
            _isLoadingFollowStatus = false;
          });
        }
      } else {
        setState(() {
          _isLoadingFollowStatus = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user/follow status: $e');
      setState(() {
        _isLoadingFollowStatus = false;
      });
    }
  }

  Future<void> _syncPlaylistSessionForCurrentVideo() async {
    final current = _playlistSession;
    if (current == null) return;
    final idx = current.videoIds.indexOf(_video.videoId);
    if (idx < 0) return;
    _playlistSession = current.copyWith(currentIndex: idx);
    await PlaylistSessionStorage().save(_playlistSession!);
    _primePlaylistQueueMetadata();
  }

  Future<void> _playPlaylistItem(String videoId, int index) async {
    final session = _playlistSession;
    if (session == null) return;
    if (videoId != _video.videoId && !await _isDeviceOnline()) {
      if (mounted) {
        showCatchToast(
          context,
          NoInternetException(),
          fallback: offlineUserMessage,
        );
      }
      return;
    }
    final nextSession = session.copyWith(currentIndex: index);
    setState(() {
      _playlistSession = nextSession;
    });
    await PlaylistSessionStorage().save(nextSession);
    final cached = _playlistQueueVideoCache[videoId];
    if (cached != null) {
      await _replaceVideo(cached, pushCurrentToHistory: true);
      return;
    }
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    await _pauseVideo(updateUiState: false);
    try {
      final repo = context.read<VideoRepository>();
      final info = await repo.getVideoInfo(videoId);
      final loaded = info.video;
      if (loaded != null) {
        _playlistQueueVideoCache[videoId] = loaded;
        await _replaceVideo(loaded, pushCurrentToHistory: true);
      } else {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        await _resumeVideo();
      }
    } catch (e) {
      debugPrint('VideoPlayerPage: Failed to open playlist item $videoId: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      await _resumeVideo();
    }
  }

  Future<void> _clearPlaylistSession() async {
    if (_playlistSession == null) return;
    if (mounted) {
      setState(() {
        _playlistSession = null;
      });
    } else {
      _playlistSession = null;
    }
    await PlaylistSessionStorage().clear();
  }

  bool _playlistQueueEntryNeedsFetch(String id) {
    final cached = _playlistQueueVideoCache[id];
    if (cached == null) return true;
    final title = cached.videoTitle.trim();
    if (title.isEmpty || title.toLowerCase() == 'video') return true;
    if (cached.videoThumbnail.trim().isEmpty) return true;
    return false;
  }

  Future<void> _primePlaylistQueueMetadata() async {
    final session = _playlistSession;
    if (session == null || session.videoIds.isEmpty) return;
    if (!await _isDeviceOnline()) return;
    final repo = context.read<VideoRepository>();
    var changed = false;
    for (final id in session.videoIds) {
      if (!_playlistQueueEntryNeedsFetch(id)) continue;
      try {
        final info = await repo.getVideoInfo(id);
        final video = info.video;
        if (video != null) {
          _playlistQueueVideoCache[id] = video;
          changed = true;
        }
      } catch (_) {
        // Best-effort preload; queue can still fall back to ID.
      }
    }
    if (changed && mounted) {
      setState(() {});
    }
  }

  Future<void> _handleFollowUnfollow() async {
    if (_video.userUsername.isEmpty) return;

    if (_currentUser == null) {
      _showSignInRequiredDialog();
      return;
    }

    if (_currentUser!.username == _video.userUsername) {
      return;
    }

    final wasFollowing = _isFollowing;
    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      final userRepository = context.read<UserRepository>();
      if (wasFollowing) {
        await userRepository.unfollowUser(_video.userUsername);
      } else {
        await userRepository.followUser(_video.userUsername);
      }
      _videoOwner = await userRepository.getUser(_video.userUsername);
      setState(() {
        _isFollowing = _videoOwner?.isFollowing ?? false;
      });
      unawaited(
        AnalyticsCapture.click(
          context,
          elementUiName: wasFollowing
              ? AnalyticsTags.unfollowedCreator
              : AnalyticsTags.followedCreator,
          screenName: 'watch',
          videoId: _video.videoId,
          videoTitle: _video.videoTitle,
        ),
      );
    } catch (e) {
      setState(() {
        _isFollowing = wasFollowing;
      });
      if (mounted) {
        showCatchToast(
          context,
          e,
          fallback: wasFollowing
              ? 'Could not unfollow. Please try again.'
              : 'Could not follow. Please try again.',
        );
      }
    }
  }

  Future<void> _showSignInRequiredDialog() async {
    await _pauseVideo();
    if (!mounted) return;
    unawaited(
      AnalyticsCapture.conversion(
        context,
        eventName: AnalyticsEvents.conversionAuthPromptShown,
        screenName: 'watch',
        videoId: _video.videoId,
        videoTitle: _video.videoTitle,
      ),
    );
    final result = await showDialog<_SignInPromptResult>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Sign In Required',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: const Text(
            'You need to sign in to follow users. Would you like to sign in or create an account?',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_SignInPromptResult.cancelled);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6B6B6B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_SignInPromptResult.signIn);
              },
              child: const Text(
                'Sign In',
                style: TextStyle(
                  color: Color(0xFFED1C2F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(_SignInPromptResult.signUp);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED1C2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Sign Up',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) return;

    switch (result) {
      case _SignInPromptResult.signIn:
        {
          VideoPlayerPage.cacheVideo(_video.videoId, _video);
          final currentRoute = '/watch/${_video.videoId}';
          if (!mounted) return;
          context.go('/login?returnTo=${Uri.encodeComponent(currentRoute)}');
        }
      case _SignInPromptResult.signUp:
        {
          VideoPlayerPage.cacheVideo(_video.videoId, _video);
          final currentRoute = '/watch/${_video.videoId}';
          if (!mounted) return;
          context.go('/signup?returnTo=${Uri.encodeComponent(currentRoute)}');
        }
      case _SignInPromptResult.cancelled:
      case null:
        unawaited(
          AnalyticsCapture.conversion(
            context,
            eventName: AnalyticsEvents.conversionAuthPromptDismissed,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
          ),
        );
        await _resumeVideo();
    }
  }

  @override
  void dispose() {
    debugPrint('VideoPlayerPage: dispose() called - cleaning up resources');
    _iosInactivePipProbe?.cancel();
    _iosInactivePipProbe = null;
    if (_routeAwareSubscribed) {
      _routeObserver?.unsubscribe(this);
      _routeAwareSubscribed = false;
    }
    PipService.setVideoPlayerPageSurfaceActive(false);
    FullscreenManager.lockToPortrait();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_pausePlaybackOnly());
    _commentsController.dispose();
    // Permanently dispose the HlsPlayerController now that the page is gone.
    // HlsVideoPlayer.dispose() intentionally keeps the controller alive in the
    // registry so PiP-induced widget rebuilds can reuse it. This call is the
    // definitive teardown that actually releases the VideoPlayerController.
    if (!_isLoading && !_hasError) {
      HlsVideoPlayer.disposeForVideo(_video.videoId);
    }
    MediaSyncService().endMediaSessionIfNoPlayerAttached();
    MediaSyncService().registerNavigationCallbacks(
      onNext: null,
      onPrevious: null,
      hasPreviousVideo: null,
    );
    super.dispose();
  }

  void _openCommentsSheet() {
    unawaited(
      context.read<FirstPartyAnalyticsService>().capture(
        r'$click',
        elementUiName: AnalyticsTags.openedComments,
        screenName: 'watch',
        videoId: _video.videoId,
        videoTitle: _video.videoTitle,
        properties: {
          'source': 'watch',
          'source_path': '/watch/${_video.videoId}',
          'path': '/watch/${_video.videoId}',
          'video_id': _video.videoId,
          'video_title': _video.videoTitle,
        },
      ),
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        controller: _commentsController,
        onSignInRequired: _showSignInRequiredDialog,
      ),
    );
  }

  Future<void> _handleCreatorProfileTap() async {
    if (_video.userUsername.isEmpty) return;

    // go_router does not preserve `extra` when popping back to /video/:id.
    VideoPlayerPage.cacheVideo(_video.videoId, _video);
    await _pauseVideo();
    if (!mounted) return;
    await context.push('/users/${_video.userUsername}');
  }

  /// Save to Liked Videos (same API as legacy upvote).
  Future<void> _toggleSaveToLiked() async {
    final authRepository = context.read<AuthRepository>();
    if (authRepository.currentUser == null) {
      await _showSignInRequiredDialog();
      return;
    }
    if (_isLikeActionInFlight) {
      return;
    }

    final connectivity = context.read<NetworkConnectivityService>();
    await connectivity.ensureInitialized();
    if (!connectivity.isConnected) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(offlineUserMessage),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    _isLikeActionInFlight = true;
    final wasUpvoted = _isUpvoted;
    final previousUpvoteCount = _upvoteCount;
    final wasDownvoted = _isDownvoted;
    final previousDownvoteCount = _downvoteCount;
    setState(() {
      if (_isUpvoted) {
        _isUpvoted = false;
        _upvoteCount--;
      } else {
        if (_isDownvoted) {
          _isDownvoted = false;
          _downvoteCount--;
        }
        _isUpvoted = true;
        _upvoteCount++;
      }
    });
    try {
      if (wasUpvoted) {
        // Product contract: unliking uses downvote endpoint.
        await context.read<VideoRepository>().downvoteVideo(_video.videoId);
      } else {
        await context.read<VideoRepository>().upvoteVideo(_video.videoId);
      }
      if (!mounted) return;
      _video = _video.copyWith(
        userVoteStatus: _isUpvoted
            ? 'upvoted'
            : (_isDownvoted ? 'downvoted' : null),
      );
      _playlistQueueVideoCache[_video.videoId] = _video;
      // Keep liked library immediately consistent with detail action.
      context.read<LikedVideosViewModel>().applyLikeState(
        videoId: _video.videoId,
        isLiked: _isUpvoted,
        likedAt: DateTime.now(),
        likedVideo: _video,
      );
      await _refreshVoteStateIfAuthenticated();

      final firstParty = context.read<FirstPartyAnalyticsService>();
      if (_isUpvoted) {
        unawaited(
          AnalyticsCapture.click(
            context,
            elementUiName: AnalyticsTags.watchLikeVideo,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: _video.videoId,
              source: 'watch',
            ),
          ),
        );
        unawaited(
          firstParty.capture(
            r'$click',
            elementUiName: AnalyticsTags.liked,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: _video.videoId,
              source: 'watch',
            ),
          ),
        );
        unawaited(
          AnalyticsCapture.conversion(
            context,
            eventName: AnalyticsEvents.conversionLikeSuccess,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: _video.videoId,
              source: 'watch',
            ),
          ),
        );
      } else {
        unawaited(
          AnalyticsCapture.click(
            context,
            elementUiName: AnalyticsTags.watchUnlikeVideo,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: _video.videoId,
              source: 'watch',
            ),
          ),
        );
        unawaited(
          firstParty.capture(
            r'$click',
            elementUiName: AnalyticsTags.unliked,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: _video.videoId,
              source: 'watch',
            ),
          ),
        );
        unawaited(
          AnalyticsCapture.conversion(
            context,
            eventName: AnalyticsEvents.conversionUnlikeSuccess,
            screenName: 'watch',
            videoId: _video.videoId,
            videoTitle: _video.videoTitle,
            properties: AnalyticsCapture.watchProperties(
              videoId: _video.videoId,
              source: 'watch',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpvoted = wasUpvoted;
          _upvoteCount = previousUpvoteCount;
          _isDownvoted = wasDownvoted;
          _downvoteCount = previousDownvoteCount;
        });
        showCatchToast(
          context,
          e,
          fallback: 'Could not update like. Please try again.',
        );
      }
    } finally {
      _isLikeActionInFlight = false;
    }
  }

  Future<void> _reportCurrentVideo() async {
    final authRepository = context.read<AuthRepository>();
    if (authRepository.currentUser == null) {
      await _showSignInRequiredDialog();
      return;
    }
    if (!mounted) return;
    unawaited(
      AnalyticsCapture.click(
        context,
        elementUiName: AnalyticsTags.reportVideo,
        screenName: 'watch',
        videoId: _video.videoId,
        videoTitle: _video.videoTitle,
      ),
    );
    await ReportFlagSheet.show(
      context,
      title: 'video',
      reportType: 'video',
      targetId: _video.videoId,
      targetType: 'video',
      metadata: {
        'video_title': _video.videoTitle,
        'thumbnail_url': _video.videoThumbnail,
        'username': _video.userUsername,
      },
    );
  }

  Future<void> _showVideoOptionsBottomSheet() async {
    final controller = HlsVideoPlayer.getController(_video.videoId);
    if (controller == null) return;
    if (!mounted) return;

    await showVideoPlaybackOptionsSheet(
      context: context,
      controller: controller,
      onReport: () {
        if (!mounted) return;
        _reportCurrentVideo();
      },
    );
  }

  void _shareVideo() {
    final videoId = _video.videoId;
    if (videoId.isEmpty) return;

    unawaited(
      context.read<FirstPartyAnalyticsService>().capture(
        r'$click',
        elementUiName: AnalyticsTags.sharedVideo,
        screenName: 'watch',
        videoId: videoId,
        videoTitle: _video.videoTitle,
        properties: {
          'source': 'watch',
          'source_path': '/watch/$videoId',
          'path': '/watch/$videoId',
          'video_id': videoId,
          'video_title': _video.videoTitle,
        },
      ),
    );
    unawaited(
      context.read<FirstPartyAnalyticsService>().capture(
        r'$click',
        elementUiName: AnalyticsTags.shareVideoNativeShareButton,
        screenName: 'watch',
        videoId: videoId,
        videoTitle: _video.videoTitle,
        properties: {
          'source': 'watch',
          'source_path': '/watch/$videoId',
          'path': '/watch/$videoId',
          'video_id': videoId,
          'video_title': _video.videoTitle,
        },
      ),
    );

    final url = 'https://www.hiffi.com/watch/$videoId';
    final title = _video.videoTitle;
    final renderObject = context.findRenderObject();
    Rect shareOrigin;
    if (renderObject is RenderBox && renderObject.hasSize) {
      final topLeft = renderObject.localToGlobal(Offset.zero);
      shareOrigin = topLeft & renderObject.size;
    } else {
      final size = MediaQuery.sizeOf(context);
      shareOrigin = Rect.fromCenter(
        center: Offset(size.width / 2, size.height / 2),
        width: 1,
        height: 1,
      );
    }

    Share.share(
      url,
      subject: title.isNotEmpty ? title : 'Watch this video on Hiffi',
      sharePositionOrigin: shareOrigin,
    );
  }

  Future<void> _openAddToPlaylistSheet() async {
    if (_isAddToPlaylistSheetOpen) return;

    final authRepository = context.read<AuthRepository>();
    if (authRepository.currentUser == null) {
      await _showSignInRequiredDialog();
      return;
    }

    _isAddToPlaylistSheetOpen = true;
    unawaited(
      context.read<FirstPartyAnalyticsService>().capture(
        r'$click',
        elementUiName: AnalyticsTags.videoCardAddToPlaylistButton,
        screenName: 'watch',
        videoId: _video.videoId,
        videoTitle: _video.videoTitle,
      ),
    );
    // Fire-and-forget analytics so the sheet appears instantly.
    context.read<AnalyticsService>().logEvent(
      context,
      'add_to_playlist_opened',
      parameters: {'video_id': _video.videoId, 'source': 'watch'},
    );
    if (!mounted) return;
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AddToPlaylistSheet(
          videoId: _video.videoId,
          videoTitle: _video.videoTitle,
        ),
      );
    } finally {
      _isAddToPlaylistSheetOpen = false;
    }
  }

  Future<void> _refreshAfterReconnect() async {
    if (!mounted) return;
    await _fetchAndInitializePlayer();
    if (!mounted) return;
    await Future.wait([
      _loadSuggestedVideosForPlayer(useNewSeed: true),
      _commentsController.fetchLatestComment(),
      _refreshVoteStateIfAuthenticated(),
      _primePlaylistQueueMetadata(),
    ]);
  }

  Future<void> _fetchAndInitializePlayer() async {
    if (!await _isDeviceOnline()) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNoInternet = true;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _isNoInternet = false;
      });
    }

    try {
      final videoRepository = context.read<VideoRepository>();
      final videoInfo = await videoRepository.getVideoInfo(_video.videoId);
      if (videoInfo.videoUrl.isEmpty) {
        throw Exception('Failed to get video URL from API');
      }
      _videoUrlFromApi = videoInfo.videoUrl;
      if (mounted) {
        setState(() {
          if (videoInfo.video != null) {
            _video = videoInfo.video!;
            _upvoteCount = _video.videoUpvotes;
            _downvoteCount = _video.videoDownvotes;
          }
          if (videoInfo.profilePicture != null &&
              videoInfo.profilePicture!.isNotEmpty) {
            _video = _video.copyWith(profilePicture: videoInfo.profilePicture);
          }
          _isUpvoted = videoInfo.upvoted;
          _isDownvoted = videoInfo.downvoted;
          _isFollowing = videoInfo.following;
          _isLoading = false;
          _hasError = false;
          _isNoInternet = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNoInternet = isOfflineError(e);
        });
      }
    }
  }

  Future<void> _refreshVoteStateIfAuthenticated() async {
    final authRepository = context.read<AuthRepository>();
    if (authRepository.currentUser == null) return;
    if (!await _isDeviceOnline()) return;
    try {
      final info = await context.read<VideoRepository>().getVideoInfo(
        _video.videoId,
      );
      if (!mounted) return;
      setState(() {
        _isUpvoted = info.upvoted;
        _isDownvoted = info.downvoted;
        if (info.video != null) {
          _video = info.video!;
          _upvoteCount = _video.videoUpvotes;
          _downvoteCount = _video.videoDownvotes;
          _playlistQueueVideoCache[_video.videoId] = _video;
        }
      });
    } catch (_) {
      // Best effort refresh; optimistic state remains.
    }
  }

  void _handleOrientationChange(Orientation orientation) {
    if (_isAutoRotating ||
        _isLoading ||
        _hasError ||
        _videoUrlFromApi == null) {
      return;
    }
    if (PipService.isInPipMode.value ||
        PipService.pipUiHeldUntilReconnect.value ||
        PipService.isTransitioningFromPip ||
        PipService.shouldSuppressOrientationDrivenFullscreen) {
      return;
    }

    final controller = HlsVideoPlayer.getController(_video.videoId);
    if (controller == null) return;

    if (orientation == Orientation.landscape) {
      if (!controller.isFullScreen) {
        // Check if we're still in the cooldown period after manual exit
        if (_fullscreenExitedAt != null &&
            DateTime.now().difference(_fullscreenExitedAt!) <
                const Duration(seconds: 4)) {
          debugPrint(
            'VideoPlayerPage: Skipping auto-entry - still in manual exit cooldown',
          );
          return;
        }

        debugPrint('VideoPlayerPage: Auto-entering landscape fullscreen');
        setState(() {
          _isAutoRotating = true;
          _fullscreenEnteredAt = DateTime.now();
        });
        controller.enterFullScreen();
        // Reset flag after a delay to allow the transition to complete
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _isAutoRotating = false);
        });
      }
    } else if (orientation == Orientation.portrait) {
      if (controller.isFullScreen) {
        // Clear manual exit timestamp since we're now back in portrait
        _fullscreenExitedAt = null;

        // Check if we're still in the cooldown period after entering fullscreen
        // This prevents premature exit when fullscreen was just entered via button
        if (_fullscreenEnteredAt != null &&
            DateTime.now().difference(_fullscreenEnteredAt!) <
                const Duration(seconds: 2)) {
          debugPrint(
            'VideoPlayerPage: Skipping auto-exit - still in fullscreen entry cooldown',
          );
          return;
        }

        debugPrint('VideoPlayerPage: Auto-exiting to portrait');
        setState(() => _isAutoRotating = true);
        controller.exitFullScreen();
        FullscreenManager.exitFullscreen(); // Force orientation reset
        _fullscreenEnteredAt = null; // Clear the timestamp
        // Reset flag after a delay to allow the transition to complete
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _isAutoRotating = false);
        });
      }
    }
  }

  Widget _buildVideoChild() {
    if (_isLoading) return const VideoPlayerShimmer();
    if (_video.status == 'temp') {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sync, color: Colors.redAccent, size: 48),
            SizedBox(height: 16),
            Text(
              'Video is processing...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isNoInternet
                  ? Icons.wifi_off_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white70,
              size: 48,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _isNoInternet ? offlineUserMessage : 'Failed to load video',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _isNoInternet ? 14 : 16,
                  fontWeight: _isNoInternet ? FontWeight.w500 : FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _refreshAfterReconnect,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFED1C2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      );
    }
    if (_videoUrlFromApi != null) {
      return HlsVideoPlayer(
        key: _playerKey,
        video: _video,
        videoId: _video.videoId,
        baseVideoUrl: _videoUrlFromApi!,
        autoPlay: !_isNavigatingAway && !_isReturningFromAuth,
        initialResumePosition: widget.initialResumePosition,
        watchHoursRepository: context.read<VideoRepository>(),
        onVideoEnded: _onVideoEnded,
      );
    }
    return const SizedBox.shrink();
  }

  @override
  Widget build(BuildContext context) {
    final controller = HlsVideoPlayer.getController(_video.videoId);
    final isCurrentlyFullscreen = controller?.isFullScreen ?? false;

    if (isCurrentlyFullscreen && !_lastKnownFullscreenState) {
      // Fullscreen was just entered (possibly via button click)
      _fullscreenEnteredAt = DateTime.now();
      debugPrint('VideoPlayerPage: Fullscreen entered - setting cooldown');
    }

    if (!isCurrentlyFullscreen && _lastKnownFullscreenState) {
      // Fullscreen was just exited (possibly via button click)
      _fullscreenExitedAt = DateTime.now();
      debugPrint('VideoPlayerPage: Fullscreen exited - setting cooldown');
    }

    _lastKnownFullscreenState = isCurrentlyFullscreen;

    return OrientationBuilder(
      builder: (context, orientation) {
        final isLandscape = orientation == Orientation.landscape;

        // Auto-handle fullscreen transition when orientation changes
        if (_lastOrientation != orientation) {
          final oldOrientation = _lastOrientation;
          _lastOrientation = orientation;

          // Only trigger if we have a previous orientation (prevent trigger on first load)
          if (oldOrientation != null) {
            // Use addPostFrameCallback to ensure we don't trigger transitions during build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleOrientationChange(orientation);
            });
          }
        }

        final size = MediaQuery.of(context).size;
        final padding = MediaQuery.of(context).padding;
        final screenWidth = isLandscape
            ? max(size.width, size.height)
            : min(size.width, size.height);
        final screenHeight = isLandscape
            ? min(size.width, size.height)
            : max(size.width, size.height);
        // On tablet/iPad portrait, constrain video width so it doesn't stretch too much
        final contentWidth = isLandscape
            ? screenWidth
            : min(screenWidth, kMaxContentWidth);
        final videoWidth = isLandscape
            ? screenWidth - padding.horizontal
            : contentWidth;
        final videoHeight = isLandscape
            ? screenHeight - padding.vertical
            : contentWidth * (9 / 16);
        final videoPadding = isLandscape
            ? padding
            : EdgeInsets.only(top: padding.top);

        return PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) _handleBackNavigation();
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            extendBodyBehindAppBar: true,
            appBar: isLandscape
                ? null
                : AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _handleBackNavigation,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.5),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: _showVideoOptionsBottomSheet,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                    ),
                  ),
            body: NetworkPageShell(
              hasCachedContent: _video.videoId.isNotEmpty,
              isLoading: _isLoading && !_hasError,
              emptyDescription: 'Connect to the internet to load this video.',
              onRetry: _refreshAfterReconnect,
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                bottom: false,
                child: CustomScrollView(
                  physics: isLandscape
                      ? const NeverScrollableScrollPhysics()
                      : const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.black,
                        child: isLandscape
                            ? Padding(
                                padding: videoPadding,
                                child: Container(
                                  width: videoWidth,
                                  height: videoHeight,
                                  color: Colors.black,
                                  child: _buildVideoChild(),
                                ),
                              )
                            : Center(
                                child: Padding(
                                  padding: videoPadding,
                                  child: Container(
                                    width: videoWidth,
                                    height: videoHeight,
                                    color: Colors.black,
                                    child: _buildVideoChild(),
                                  ),
                                ),
                              ),
                      ),
                    ),
                    if (!isLandscape) ...[
                      SliverToBoxAdapter(
                        child: VideoPlayerMetadataSection(
                          video: _video,
                          isUpvoted: _isUpvoted,
                          upvoteCount: _upvoteCount,
                          isFollowing: _isFollowing,
                          isLoadingFollowStatus: _isLoadingFollowStatus,
                          showFollowButton: _video.userUsername.isNotEmpty &&
                              (_currentUser == null ||
                                  _currentUser!.username != _video.userUsername),
                          isDescriptionExpanded: _isDescriptionExpanded,
                          formatCount: _formatCount,
                          onToggleLike: _toggleSaveToLiked,
                          onAddToPlaylist: _openAddToPlaylistSheet,
                          onShare: _shareVideo,
                          onCreatorTap: _handleCreatorProfileTap,
                          onFollow: _handleFollowUnfollow,
                          onToggleDescription: () => setState(
                            () => _isDescriptionExpanded =
                                !_isDescriptionExpanded,
                          ),
                          onOpenDescriptionLink: _openDescriptionLink,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Container(
                          height: 8,
                          color: const Color(0xFFF5F5F5),
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: ColoredBox(
                          color: Colors.white,
                          child: Builder(
                            builder: (context) {
                              final hasSuggestedBlock =
                                  _suggestedLoading ||
                                  _suggestedError ||
                                  _suggestedVideos.isNotEmpty;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_playlistSession != null &&
                                      _playlistSession!.videoIds.isNotEmpty)
                                    VideoPlaylistQueue(
                                      session: _playlistSession!,
                                      currentVideoId: _video.videoId,
                                      videoLookup: _playlistQueueVideoCache,
                                      isOffline: context
                                          .watch<ConnectivityController>()
                                          .isOffline,
                                      onTapItem: (videoId, index) {
                                        _playPlaylistItem(videoId, index);
                                      },
                                    ),
                                  VideoSuggestedSection(
                                    videos: _suggestedVideos,
                                    isLoading: _suggestedLoading,
                                    hasError: _suggestedError,
                                    isNoInternet: _suggestedNoInternet,
                                    onRetry: () =>
                                        _loadSuggestedVideosForPlayer(),
                                    onVideoSelected: (video) async {
                                      unawaited(
                                        AnalyticsCapture.videoOpened(
                                          context,
                                          openUiName: AnalyticsTags
                                              .openedVideoFromRecommended,
                                          screenName: 'watch',
                                          videoId: video.videoId,
                                          videoTitle: video.videoTitle,
                                          source: 'suggested',
                                        ),
                                      );
                                      final previousSession = _playlistSession;
                                      await _clearPlaylistSession();
                                      await _replaceVideo(
                                        video,
                                        pushCurrentToHistory: true,
                                        historyPlaylistSessionOverride:
                                            previousSession,
                                      );
                                    },
                                  ),
                                  if (hasSuggestedBlock) ...[
                                    const SizedBox(
                                      height: _kSuggestedToCommentsGap,
                                    ),
                                    const Divider(
                                      height: 1,
                                      thickness: 1,
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                    const SizedBox(
                                      height: _kSuggestedToCommentsGap,
                                    ),
                                  ],
                                  VideoPlayerCommentsPanel(
                                    controller: _commentsController,
                                    onOpenSheet: _openCommentsSheet,
                                    onSignInRequired: _showSignInRequiredDialog,
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}K';
    return count.toString();
  }

  Future<void> _openDescriptionLink(String rawUrl) async {
    final normalized =
        rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
        ? rawUrl
        : 'https://$rawUrl';
    final uri = Uri.tryParse(normalized);
    if (uri == null) return;

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open this link')));
    }
  }
}

