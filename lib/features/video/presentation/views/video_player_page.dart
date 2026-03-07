import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/data/user_repository.dart';
import '../../../user/domain/models/user_model.dart';
import 'package:hiffi/features/video/presentation/controllers/video_comments_controller.dart';
import 'package:hiffi/features/video/presentation/widgets/video_comments_section.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/fullscreen_manager.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/services/media/media_sync_service.dart';
import '../widgets/hls_video_player.dart';
import '../controllers/hls_player_controller.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({
    super.key,
    required this.video,
    this.videoId,
    this.returningFromAuth = false,
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

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage>
    with WidgetsBindingObserver {
  late VideoModel _video;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isNoInternet = false;
  bool _isDescriptionExpanded = false;
  bool _isUpvoted = false;
  bool _isDownvoted = false;
  int _upvoteCount = 0;
  int _downvoteCount = 0;
  String? _videoUrlFromApi;

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

  // Suggested videos for autoplay
  List<VideoModel> _suggestedVideos = [];

  // Previous-video stack: when user taps Next we push current; Previous pops and navigates back
  final List<VideoModel> _videoHistory = [];

  // Track orientation for auto-fullscreen logic
  Orientation? _lastOrientation;
  bool _isAutoRotating = false;

  // Cooldown to prevent premature fullscreen exit after manual entry
  DateTime? _fullscreenEnteredAt;
  DateTime? _fullscreenExitedAt;
  bool _lastKnownFullscreenState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Allow both portrait and landscape orientations for this page
    FullscreenManager.resetOrientation();

    _video = widget.video;

    // Set flag if returning from auth - video should not autoplay
    _isReturningFromAuth = widget.returningFromAuth;
    if (_isReturningFromAuth) {
      debugPrint('VideoPlayerPage: Returning from auth - video will be paused');
      // When returning from auth, we want to restore the position where it was paused
      // So we don't clear the position here - it will be loaded from SharedPreferences
    } else {
      // If NOT returning from auth (normal navigation), clear saved position
      // This ensures videos start from beginning when navigating normally
      HlsPlayerController.clearPlaybackPosition(_video.videoId);
      debugPrint(
        'VideoPlayerPage: Cleared saved position for normal navigation',
      );
    }

    _commentsController = VideoCommentsController(
      repository: context.read<VideoRepository>(),
      videoId: _video.videoId,
      userRepository: context.read<UserRepository>(),
    );

    _upvoteCount = _video.videoUpvotes;
    _downvoteCount = _video.videoDownvotes;

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
      onNext: _playNextVideo,
      onPrevious: _playPreviousVideo,
      hasPreviousVideo: () => _videoHistory.isNotEmpty,
    );

    // 5️⃣ Fetch lightweight preview data
    _commentsController.fetchLatestComment();
  }

  void _playNextVideo() {
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
      _replaceVideo(nextVideo, pushCurrentToHistory: true);
    } else {
      debugPrint('VideoPlayerPage: Could not find a suitable next video');
    }
  }

  void _playPreviousVideo() {
    if (_videoHistory.isEmpty) {
      debugPrint('VideoPlayerPage: No previous video in history');
      return;
    }
    final previousVideo = _videoHistory.removeLast();
    debugPrint(
      'VideoPlayerPage: Previous - navigating back to ${previousVideo.videoId}',
    );
    _replaceVideo(previousVideo, pushCurrentToHistory: false);
  }

  void _onVideoEnded() {
    debugPrint('VideoPlayerPage: Video ended - triggering autoplay');
    _playNextVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void deactivate() {
    debugPrint(
      'VideoPlayerPage: deactivate() called - widget being removed from tree',
    );
    _pauseVideo();
    super.deactivate();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      debugPrint(
        'VideoPlayerPage: App paused - switching to background audio if needed',
      );
      MediaSyncService().switchToBackground();
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('VideoPlayerPage: App resumed - returning to foreground');
      MediaSyncService().switchToForeground();
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

  Future<void> _pauseVideo() async {
    if (_videoUrlFromApi != null) {
      debugPrint(
        'VideoPlayerPage: _pauseVideo() called - pausing player and saving position',
      );
      await HlsVideoPlayer.pausePlayer(_video.videoId);
    }

    if (!_isNavigatingAway) {
      setState(() {
        _isNavigatingAway = true;
      });
    }
  }

  Future<void> _resumeVideo() async {
    if (_videoUrlFromApi != null) {
      debugPrint('VideoPlayerPage: _resumeVideo() called - resuming player');
      await HlsVideoPlayer.playPlayer(_video.videoId);

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
      context.go('/home');
    }
  }

  Future<void> _replaceVideo(VideoModel newVideo,
      {bool pushCurrentToHistory = false}) async {
    debugPrint(
      'VideoPlayerPage: Replacing video ${_video.videoId} with ${newVideo.videoId}',
    );

    if (pushCurrentToHistory) {
      _videoHistory.add(_video);
      debugPrint(
        'VideoPlayerPage: Pushed current to history (size ${_videoHistory.length})',
      );
    }

    await HlsPlayerController.clearPlaybackPosition(newVideo.videoId);

    _isNavigatingAway = false;
    _isReturningFromAuth = false;

    setState(() {
      _playerKey = ValueKey('player_${newVideo.videoId}');
      _video = newVideo;
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
      );
    });

    await _fetchAndInitializePlayer();
    await _loadUserAndFollowStatus();
    _commentsController.fetchLatestComment();
  }

  Future<void> _loadUserAndFollowStatus() async {
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
    } catch (e) {
      setState(() {
        _isFollowing = wasFollowing;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to ${wasFollowing ? 'unfollow' : 'follow'}: ${e.toString()}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSignInRequiredDialog() {
    _pauseVideo();
    showDialog(
      context: context,
      builder: (BuildContext context) {
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _resumeVideo();
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _pauseVideo();
                VideoPlayerPage.cacheVideo(_video.videoId, _video);
                final currentRoute = '/video/${_video.videoId}';
                if (mounted)
                  context.go(
                    '/login?returnTo=${Uri.encodeComponent(currentRoute)}',
                  );
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
              onPressed: () async {
                Navigator.of(context).pop();
                await _pauseVideo();
                VideoPlayerPage.cacheVideo(_video.videoId, _video);
                final currentRoute = '/video/${_video.videoId}';
                if (mounted)
                  context.go(
                    '/signup?returnTo=${Uri.encodeComponent(currentRoute)}',
                  );
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
  }

  @override
  void dispose() {
    debugPrint('VideoPlayerPage: dispose() called - cleaning up resources');
    FullscreenManager.lockToPortrait(); // Lock back to portrait when leaving
    WidgetsBinding.instance.removeObserver(this);
    _pauseVideo();
    _commentsController.dispose();
    super.dispose();
  }

  void _openCommentsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CommentsBottomSheet(controller: _commentsController),
    );
  }

  Future<void> _fetchAndInitializePlayer() async {
    try {
      final videoRepository = context.read<VideoRepository>();
      final videoInfo = await videoRepository.getVideoInfo(_video.videoId);
      if (videoInfo.videoUrl.isEmpty)
        throw Exception('Failed to get video URL from API');
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
          _isNoInternet = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final errorString = e.toString();
        final isNoInternet =
            errorString.contains('SocketException') ||
            errorString.contains('Failed host lookup') ||
            errorString.contains('Network is unreachable');

        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNoInternet = isNoInternet;
        });
      }
    }
  }

  void _handleOrientationChange(Orientation orientation) {
    if (_isAutoRotating ||
        _isLoading ||
        _hasError ||
        _videoUrlFromApi == null) {
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
        final videoWidth = isLandscape ? screenWidth - padding.horizontal : screenWidth;
        final videoHeight = isLandscape
            ? screenHeight - padding.vertical
            : screenWidth * (9 / 16);
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
                    systemOverlayStyle: const SystemUiOverlayStyle(
                      statusBarColor: Colors.transparent,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                    ),
                  ),
            body: SafeArea(
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
                      child: Padding(
                        padding: videoPadding,
                        child: Container(
                          width: videoWidth,
                          height: videoHeight,
                          color: Colors.black,
                          child: _isLoading
                          ? const VideoPlayerShimmer()
                          : _video.status == 'temp'
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.sync,
                                    color: Colors.redAccent,
                                    size: 48,
                                  ),
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
                            )
                          : _hasError
                          ? Center(
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
                                  Text(
                                    _isNoInternet
                                        ? 'No Internet Connection'
                                        : 'Failed to load video',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (_isNoInternet) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Please check your network and try again.',
                                      style: TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: () {
                                      setState(() {
                                        _isLoading = true;
                                        _hasError = false;
                                        _isNoInternet = false;
                                      });
                                      _fetchAndInitializePlayer();
                                    },
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _videoUrlFromApi != null
                          ? HlsVideoPlayer(
                              key: _playerKey,
                              video: _video,
                              videoId: _video.videoId,
                              baseVideoUrl: _videoUrlFromApi!,
                              autoPlay:
                                  !_isNavigatingAway && !_isReturningFromAuth,
                              onVideoEnded: _onVideoEnded,
                            )
                          : const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                  if (!isLandscape) ...[
                    // Re-integrating the original rich components
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _video.videoTitle,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  '${_formatCount(_video.videoViews)} views',
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B6B),
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF6B6B6B),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _formatDate(_video.createdAt),
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B6B),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _VideoActionButton(
                                    icon: _isUpvoted
                                        ? Icons.thumb_up
                                        : Icons.thumb_up_outlined,
                                    label: _formatCount(_upvoteCount),
                                    isActive: _isUpvoted,
                                    onTap: () async {
                                      final authRepository = context
                                          .read<AuthRepository>();
                                      if (authRepository.currentUser == null) {
                                        _showSignInRequiredDialog();
                                        return;
                                      }
                                      final wasUpvoted = _isUpvoted;
                                      final previousUpvoteCount = _upvoteCount;
                                      final wasDownvoted = _isDownvoted;
                                      final previousDownvoteCount =
                                          _downvoteCount;
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
                                        await context
                                            .read<VideoRepository>()
                                            .upvoteVideo(_video.videoId);
                                      } catch (e) {
                                        if (mounted)
                                          setState(() {
                                            _isUpvoted = wasUpvoted;
                                            _upvoteCount = previousUpvoteCount;
                                            _isDownvoted = wasDownvoted;
                                            _downvoteCount =
                                                previousDownvoteCount;
                                          });
                                      }
                                    },
                                  ),
                                  Container(
                                    width: 1,
                                    height: 20,
                                    color: Colors.grey[300],
                                  ),
                                  _VideoActionButton(
                                    icon: _isDownvoted
                                        ? Icons.thumb_down
                                        : Icons.thumb_down_outlined,
                                    label: '',
                                    isActive: _isDownvoted,
                                    onTap: () async {
                                      final authRepository = context
                                          .read<AuthRepository>();
                                      if (authRepository.currentUser == null) {
                                        _showSignInRequiredDialog();
                                        return;
                                      }
                                      final wasDownvoted = _isDownvoted;
                                      final previousDownvoteCount =
                                          _downvoteCount;
                                      final wasUpvoted = _isUpvoted;
                                      final previousUpvoteCount = _upvoteCount;
                                      setState(() {
                                        if (_isDownvoted) {
                                          _isDownvoted = false;
                                          _downvoteCount--;
                                        } else {
                                          if (_isUpvoted) {
                                            _isUpvoted = false;
                                            _upvoteCount--;
                                          }
                                          _isDownvoted = true;
                                          _downvoteCount++;
                                        }
                                      });
                                      try {
                                        await context
                                            .read<VideoRepository>()
                                            .downvoteVideo(_video.videoId);
                                      } catch (e) {
                                        if (mounted)
                                          setState(() {
                                            _isDownvoted = wasDownvoted;
                                            _downvoteCount =
                                                previousDownvoteCount;
                                            _isUpvoted = wasUpvoted;
                                            _upvoteCount = previousUpvoteCount;
                                          });
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                if (_video.userUsername.isNotEmpty) {
                                  _pauseVideo();
                                  context.push('/users/${_video.userUsername}');
                                }
                              },
                              child: HiffiAvatar(
                                imageUrl: _video.profilePicture,
                                size: 40,
                                fallbackText: _video.userUsername,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  if (_video.userUsername.isNotEmpty) {
                                    _pauseVideo();
                                    context.push(
                                      '/users/${_video.userUsername}',
                                    );
                                  }
                                },
                                child: Text(
                                  _video.userUsername.isNotEmpty
                                      ? _video.userUsername
                                      : 'Unknown User',
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            if (_video.userUsername.isNotEmpty &&
                                (_currentUser == null ||
                                    _currentUser!.username !=
                                        _video.userUsername))
                              _isLoadingFollowStatus
                                  ? const InlineShimmer(width: 16, height: 16)
                                  : ElevatedButton(
                                      onPressed: _handleFollowUnfollow,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: _isFollowing
                                            ? const Color(0xFFF5F5F5)
                                            : const Color(0xFFED1C2F),
                                        foregroundColor: _isFollowing
                                            ? Colors.black87
                                            : Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(0, 36),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: Text(
                                        _isFollowing ? 'Following' : 'Follow',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                          ],
                        ),
                      ),
                    ),
                    if (_video.videoDescription.isNotEmpty ||
                        _video.videoTags.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Container(
                          color: Colors.white,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_video.videoDescription.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _video.videoDescription,
                                      style: const TextStyle(
                                        color: Color(0xFF1A1A1A),
                                        fontSize: 14,
                                        height: 1.5,
                                      ),
                                      maxLines: _isDescriptionExpanded
                                          ? null
                                          : 2,
                                      overflow: _isDescriptionExpanded
                                          ? null
                                          : TextOverflow.ellipsis,
                                    ),
                                    if (_video.videoDescription.length > 100)
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _isDescriptionExpanded =
                                              !_isDescriptionExpanded,
                                        ),
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(0, 28),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          _isDescriptionExpanded
                                              ? 'Show less'
                                              : 'Show more',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: Color(0xFFED1C2F),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              if (_video.videoTags.isNotEmpty) ...[
                                if (_video.videoDescription.isNotEmpty)
                                  const SizedBox(height: 12),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: _video.videoTags
                                      .map(
                                        (tag) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(
                                              0xFFED1C2F,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: const Color(
                                                0xFFED1C2F,
                                              ).withOpacity(0.3),
                                            ),
                                          ),
                                          child: Text(
                                            '#$tag',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFED1C2F),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    SliverToBoxAdapter(
                      child: Container(
                        height: 8,
                        color: const Color(0xFFF5F5F5),
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        final authRepository = context.read<AuthRepository>();
                        if (authRepository.currentUser == null) {
                          return SliverToBoxAdapter(
                            child: Container(
                              color: Colors.white,
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const Icon(
                                    Icons.comment_outlined,
                                    size: 48,
                                    color: Color(0xFF6B6B6B),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'Sign in to view and post comments',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: _showSignInRequiredDialog,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: const Color(0xFFED1C2F),
                                    ),
                                    child: const Text('Sign In'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SliverToBoxAdapter(
                          child: Column(
                            children: [
                              InlineCommentEntryBar(
                                controller: _commentsController,
                                onTap: _openCommentsSheet,
                                onSignInRequired: _showSignInRequiredDialog,
                              ),
                              const Divider(
                                height: 1,
                                indent: 16,
                                endIndent: 16,
                              ),
                              LatestCommentPreview(
                                controller: _commentsController,
                                onTap: _openCommentsSheet,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    SliverToBoxAdapter(
                      child: _SuggestedVideosSection(
                        currentVideoId: _video.videoId,
                        onVideoSelected: (video) =>
                            _replaceVideo(video, pushCurrentToHistory: true),
                        onVideosLoaded: (videos) =>
                            setState(() => _suggestedVideos = videos),
                      ),
                    ),
                  ],
                ],
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

  String _formatDate(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}

class _VideoActionButton extends StatelessWidget {
  const _VideoActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? const Color(0xFFED1C2F)
                    : const Color(0xFF1A1A1A),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isActive
                        ? const Color(0xFFED1C2F)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedVideosSection extends StatefulWidget {
  final String currentVideoId;
  final Function(VideoModel) onVideoSelected;
  final Function(List<VideoModel>)? onVideosLoaded;
  const _SuggestedVideosSection({
    required this.currentVideoId,
    required this.onVideoSelected,
    this.onVideosLoaded,
  });
  @override
  State<_SuggestedVideosSection> createState() =>
      _SuggestedVideosSectionState();
}

class _SuggestedVideosSectionState extends State<_SuggestedVideosSection> {
  List<VideoModel> _suggestedVideos = [];
  bool _isLoading = false;
  bool _hasError = false;
  bool _isNoInternet = false;
  String? _seed;
  String _generateNewSeed() {
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

  Future<void> _loadSuggestedVideos({bool useNewSeed = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isNoInternet = false;
    });
    try {
      if (useNewSeed || _seed == null) _seed = _generateNewSeed();
      final videos = await context.read<VideoRepository>().getVideos(
        page: 1,
        limit: 10,
        seed: _seed,
      );
      if (mounted) {
        setState(() {
          _suggestedVideos = videos
              .where((video) => video.videoId != widget.currentVideoId)
              .take(6)
              .toList();
          _isLoading = false;
          _hasError = false;
          _isNoInternet = false;
        });
        widget.onVideosLoaded?.call(_suggestedVideos);
      }
    } catch (e) {
      if (mounted) {
        final errorString = e.toString();
        final isNoInternet =
            errorString.contains('SocketException') ||
            errorString.contains('Failed host lookup') ||
            errorString.contains('Network is unreachable');

        setState(() {
          _isLoading = false;
          _hasError = true;
          _isNoInternet = isNoInternet;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSuggestedVideos();
  }

  @override
  void didUpdateWidget(_SuggestedVideosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentVideoId != widget.currentVideoId)
      _loadSuggestedVideos(useNewSeed: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFED1C2F)),
        ),
      );

    if (_hasError) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            Icon(
              _isNoInternet ? Icons.wifi_off_rounded : Icons.error_outline,
              color: const Color(0xFF6B6B6B),
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              _isNoInternet
                  ? 'No Internet Connection'
                  : 'Failed to load suggested videos',
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => _loadSuggestedVideos(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFED1C2F),
              ),
            ),
          ],
        ),
      );
    }

    if (_suggestedVideos.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Suggested Videos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _suggestedVideos.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index == _suggestedVideos.length - 1 ? 0 : 12,
                ),
                child: _SuggestedVideoCard(
                  video: _suggestedVideos[index],
                  onTap: widget.onVideoSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedVideoCard extends StatelessWidget {
  final VideoModel video;
  final Function(VideoModel) onTap;
  const _SuggestedVideoCard({required this.video, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final thumbnailUrl = ImageUtils.getVideoThumbnailUrl(video.videoThumbnail);
    return InkWell(
      onTap: () => onTap(video),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: thumbnailUrl == null || thumbnailUrl.isEmpty
                    ? Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.video_library,
                          color: Color(0xFF6B6B6B),
                        ),
                      )
                    : Image.network(
                        thumbnailUrl,
                        headers: ImageUtils.getVideoThumbnailHeaders(),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.videoTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                HiffiAvatar(
                  imageUrl: video.profilePicture,
                  size: 16,
                  fallbackText: video.userUsername,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    video.userUsername,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6B6B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
