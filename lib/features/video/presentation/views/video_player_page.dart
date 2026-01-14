import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:hiffi/core/services/pip_service.dart';

import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/data/user_repository.dart';
import '../../../user/domain/models/user_model.dart';
import 'package:hiffi/features/video/presentation/controllers/video_comments_controller.dart';
import 'package:hiffi/features/video/presentation/widgets/video_comments_section.dart';
import '../../../../core/utils/image_utils.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

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
      _replaceVideo(nextVideo);
    } else {
      debugPrint('VideoPlayerPage: Could not find a suitable next video');
    }
  }

  void _playPreviousVideo() {
    // For now, previous just restarts the current video if no history is tracked
    debugPrint('VideoPlayerPage: Previous - restarting current video');
    HlsVideoPlayer.playPlayer(_video.videoId);
  }

  void _onVideoEnded() {
    debugPrint('VideoPlayerPage: Video ended - triggering autoplay');
    _playNextVideo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Note: We removed the pause logic here because it was incorrectly
    // pausing the video when modal bottom sheets (like comments) are shown.
    // Video pausing is already handled in:
    // - didChangeAppLifecycleState (app goes to background)
    // - dispose() (page is being disposed)
    // - Navigation callbacks (when explicitly navigating away)
    // Modal overlays like bottom sheets should not pause the video.
  }

  @override
  void deactivate() {
    debugPrint(
      'VideoPlayerPage: deactivate() called - widget being removed from tree',
    );
    // Widget is being removed from tree - ensure video is paused and position saved
    // This happens when navigating away (e.g., to auth pages)
    // Note: _pauseVideo() is async, but deactivate can't be async
    // Position will be saved when controller is disposed
    _pauseVideo();
    super.deactivate();
  }

  AppLifecycleState? _lastState;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.paused) {
      debugPrint(
        'VideoPlayerPage: App paused - switching to background audio if needed',
      );
      // Only switch to background audio if we're not in PiP
      MediaSyncService().switchToBackground();
    } else if (state == AppLifecycleState.inactive) {
      // 💡 FIX: Only trigger PiP if we are moving FROM resumed TO inactive
      // This prevents triggering PiP while the app is opening/resuming
      if (_lastState == AppLifecycleState.resumed) {
        debugPrint(
          'VideoPlayerPage: App moving to background - triggering PiP',
        );
        PipService.enterPiP();
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('VideoPlayerPage: App resumed - returning to foreground');
      MediaSyncService().switchToForeground();
    }

    _lastState = state;
  }

  Future<void> _pauseVideo() async {
    // Pause video when navigating away or app goes to background
    // Actually pause the player controller immediately and save position
    if (_videoUrlFromApi != null) {
      debugPrint(
        'VideoPlayerPage: _pauseVideo() called - pausing player and saving position',
      );
      await HlsVideoPlayer.pausePlayer(_video.videoId);
    }

    // Set flag to prevent autoplay on rebuild
    if (!_isNavigatingAway) {
      setState(() {
        _isNavigatingAway = true;
      });
    }
  }

  /// Resumes video playback (e.g., when canceling a dialog)
  Future<void> _resumeVideo() async {
    if (_videoUrlFromApi != null) {
      debugPrint('VideoPlayerPage: _resumeVideo() called - resuming player');
      await HlsVideoPlayer.playPlayer(_video.videoId);

      // Reset navigation flag to allow normal playback
      if (_isNavigatingAway) {
        setState(() {
          _isNavigatingAway = false;
        });
      }
    }
  }

  /// Handles back navigation - ensures video is paused and navigates appropriately
  void _handleBackNavigation() {
    debugPrint('VideoPlayerPage: Back button pressed');

    // Ensure video is paused before navigating
    _pauseVideo();

    // Navigate back or to home if there's nothing to pop
    if (context.canPop()) {
      context.pop();
    } else {
      // If there's nothing to pop, navigate to home
      context.go('/home');
    }
  }

  /// Replaces the current video with a new one.
  /// This properly disposes the old player and creates a new one.
  Future<void> _replaceVideo(VideoModel newVideo) async {
    debugPrint(
      'VideoPlayerPage: Replacing video ${_video.videoId} with ${newVideo.videoId}',
    );

    // Clear saved position for the new video so it starts from beginning
    // This ensures new videos (from suggested list) always start at 0:00
    await HlsPlayerController.clearPlaybackPosition(newVideo.videoId);

    // Reset navigation flags for new video
    _isNavigatingAway = false;
    _isReturningFromAuth = false;

    // Update player key to force disposal of old player
    setState(() {
      _playerKey = ValueKey('player_${newVideo.videoId}');
      _video = newVideo;
      _isLoading = true;
      _hasError = false;
      _isDescriptionExpanded = false;
      _videoUrlFromApi = null;

      // Reset vote state
      _upvoteCount = newVideo.videoUpvotes;
      _downvoteCount = newVideo.videoDownvotes;
      _isUpvoted = false;
      _isDownvoted = false;
      if (newVideo.userVoteStatus == 'upvoted') {
        _isUpvoted = true;
      } else if (newVideo.userVoteStatus == 'downvoted') {
        _isDownvoted = true;
      }

      // Update comments controller for new video
      _commentsController.dispose();
      _commentsController = VideoCommentsController(
        repository: context.read<VideoRepository>(),
        videoId: newVideo.videoId,
        userRepository: context.read<UserRepository>(),
      );
    });

    // Fetch new video info and initialize player
    await _fetchAndInitializePlayer();
    await _loadUserAndFollowStatus();
    _commentsController.fetchLatestComment();

    // Note: Suggested videos will be reloaded automatically via didUpdateWidget
    // in _SuggestedVideosSection, which will update _suggestedVideos via onVideosLoaded
  }

  Future<void> _loadUserAndFollowStatus() async {
    try {
      final userRepository = context.read<UserRepository>();

      // Load current user first
      try {
        _currentUser = await userRepository.getCurrentUser();
        setState(() {}); // Update UI to reflect current user
      } catch (e) {
        debugPrint('Failed to load current user: $e');
      }

      // Only load follow status if it's not the current user's video
      if (_video.userUsername.isNotEmpty &&
          _currentUser?.username != _video.userUsername) {
        setState(() {
          _isLoadingFollowStatus = true;
        });

        try {
          _videoOwner = await userRepository.getUser(_video.userUsername);
          setState(() {
            // Following status is already set from getVideoInfo response
            // We just load the user profile for display purposes
            // Don't overwrite _isFollowing here as it's already set from video info
            _isLoadingFollowStatus = false;
          });
        } catch (e) {
          debugPrint('Failed to load user: $e');
          setState(() {
            _isLoadingFollowStatus = false;
          });
        }
      } else {
        // It's the current user's video, no need to load follow status
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

    // Check if user is signed in
    if (_currentUser == null) {
      // Show sign in/sign up dialog
      _showSignInRequiredDialog();
      return;
    }

    // Can't follow yourself
    if (_currentUser!.username == _video.userUsername) {
      return;
    }

    final wasFollowing = _isFollowing;

    // Optimistic update
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

      // Reload user to get updated follow status
      _videoOwner = await userRepository.getUser(_video.userUsername);
      setState(() {
        _isFollowing = _videoOwner?.isFollowing ?? false;
      });
    } catch (e) {
      // Revert on error
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

  /// Shows a dialog prompting the user to sign in or sign up
  void _showSignInRequiredDialog() {
    // Pause video immediately when dialog is shown (position will be saved)
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
                // Resume video playback when cancel is pressed
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
                // Pause video and save position before navigating to auth page
                await _pauseVideo();
                // Store current video in cache for restoration after auth
                VideoPlayerPage.cacheVideo(_video.videoId, _video);
                // Get current route and pass it as return route
                final currentRoute = '/video/${_video.videoId}';
                // Use context.go instead of push to replace current route
                // This ensures the video page is properly disposed
                if (mounted) {
                  context.go(
                    '/login?returnTo=${Uri.encodeComponent(currentRoute)}',
                  );
                }
              },
              child: const Text(
                'Sign In',
                style: TextStyle(
                  color: Color(0xFFFF6B35),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                // Pause video and save position before navigating to auth page
                await _pauseVideo();
                // Store current video in cache for restoration after auth
                VideoPlayerPage.cacheVideo(_video.videoId, _video);
                // Get current route and pass it as return route
                final currentRoute = '/video/${_video.videoId}';
                // Use context.go instead of push to replace current route
                // This ensures the video page is properly disposed
                if (mounted) {
                  context.go(
                    '/signup?returnTo=${Uri.encodeComponent(currentRoute)}',
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
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

    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Ensure video is paused before disposing
    _pauseVideo();

    // Dispose comments controller
    _commentsController.dispose();

    // The HlsVideoPlayer widget will be disposed automatically when removed from tree
    // The key change ensures proper disposal when video is replaced
    // This guarantees no memory leaks or background audio
    super.dispose();

    debugPrint(
      'VideoPlayerPage: dispose() complete - all resources cleaned up',
    );
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
      // Fetch the video info from the API (includes URL, upvoted, downvoted, following status)
      final videoRepository = context.read<VideoRepository>();
      final videoInfo = await videoRepository.getVideoInfo(_video.videoId);

      if (videoInfo.videoUrl.isEmpty) {
        throw Exception('Failed to get video URL from API');
      }

      _videoUrlFromApi = videoInfo.videoUrl;

      // Update UI state with the video info (upvoted, downvoted, following)
      if (mounted) {
        setState(() {
          if (videoInfo.video != null) {
            _video = videoInfo.video!;
            _upvoteCount = _video.videoUpvotes;
            _downvoteCount = _video.videoDownvotes;
          }
          // Update profile picture if available from VideoInfo
          // This ensures we use the most up-to-date profile picture from the API
          if (videoInfo.profilePicture != null &&
              videoInfo.profilePicture!.isNotEmpty) {
            _video = _video.copyWith(profilePicture: videoInfo.profilePicture);
          }
          _isUpvoted = videoInfo.upvoted;
          _isDownvoted = videoInfo.downvoted;
          _isFollowing = videoInfo.following;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Handle navigation manually
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Back was pressed but navigation was prevented
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              _handleBackNavigation();
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.black.withOpacity(0.5),
              padding: const EdgeInsets.all(8),
            ),
          ),
          // Ensure system UI (status bar, nav bar) uses light icons for visibility on dark video
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: Brightness.light,
            systemNavigationBarDividerColor: Colors.transparent,
          ),
        ),
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Video Player Section
              SliverToBoxAdapter(
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _isLoading
                      ? const VideoPlayerShimmer()
                      : _video.status == 'temp'
                      ? Container(
                          color: Colors.black,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.sync,
                                  color: Colors.orangeAccent,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Video is processing...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'We\'re encoding your video for the best quality.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _hasError
                      ? Container(
                          color: Colors.black,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Failed to load video',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _isLoading = true;
                                      _hasError = false;
                                    });
                                    _fetchAndInitializePlayer();
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6B35),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: const Text(
                                    'Retry',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _videoUrlFromApi != null
                      ? HlsVideoPlayer(
                          key: _playerKey, // Key forces disposal when changed
                          video: _video,
                          videoId: _video.videoId,
                          baseVideoUrl: _videoUrlFromApi!,
                          autoPlay:
                              !_isNavigatingAway &&
                              !_isReturningFromAuth, // Don't autoplay if navigating away or returning from auth
                          initialMuted: false,
                          onVideoEnded: _onVideoEnded,
                        )
                      : const SizedBox.shrink(),
                ),
              ),
              // Video Info Section
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
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
                      // Stats Row (Views and Date)
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
                      // Action Buttons Row
                      // Interaction Buttons (Like, Dislike)
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

                                // Optimistic update
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

                                // Call API
                                try {
                                  final videoRepository = context
                                      .read<VideoRepository>();
                                  await videoRepository.upvoteVideo(
                                    _video.videoId,
                                  );
                                } catch (e) {
                                  // Revert on error
                                  if (mounted) {
                                    setState(() {
                                      _isUpvoted = wasUpvoted;
                                      _upvoteCount = previousUpvoteCount;
                                      _isDownvoted = wasDownvoted;
                                      _downvoteCount = previousDownvoteCount;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to upvote: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
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
                              label: '', // Dislike usually doesn't show count
                              isActive: _isDownvoted,
                              onTap: () async {
                                final authRepository = context
                                    .read<AuthRepository>();
                                if (authRepository.currentUser == null) {
                                  _showSignInRequiredDialog();
                                  return;
                                }

                                // Optimistic update
                                final wasDownvoted = _isDownvoted;
                                final previousDownvoteCount = _downvoteCount;
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

                                // Call API
                                try {
                                  final videoRepository = context
                                      .read<VideoRepository>();
                                  await videoRepository.downvoteVideo(
                                    _video.videoId,
                                  );
                                } catch (e) {
                                  // Revert on error
                                  if (mounted) {
                                    setState(() {
                                      _isDownvoted = wasDownvoted;
                                      _downvoteCount = previousDownvoteCount;
                                      _isUpvoted = wasUpvoted;
                                      _upvoteCount = previousUpvoteCount;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to downvote: ${e.toString()}',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
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
              // Channel Section
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
                              context.push('/users/${_video.userUsername}');
                            }
                          },
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _video.userUsername.isNotEmpty
                                    ? _video.userUsername
                                    : 'Unknown User',
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Show follow button if not own video and username is available
                      // Show button even when user is signed out
                      if (_video.userUsername.isNotEmpty &&
                          (_currentUser == null ||
                              _currentUser!.username != _video.userUsername))
                        _isLoadingFollowStatus
                            ? const InlineShimmer(width: 16, height: 16)
                            : ElevatedButton(
                                onPressed: _handleFollowUnfollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isFollowing
                                      ? const Color(0xFFF5F5F5)
                                      : const Color(0xFFFF6B35),
                                  foregroundColor: _isFollowing
                                      ? Colors.black87
                                      : Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  minimumSize: const Size(0, 36),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
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
              // Description Section (Collapsible)
              if (_video.videoDescription.isNotEmpty ||
                  _video.videoTags.isNotEmpty)
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description
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
                                maxLines: _isDescriptionExpanded ? null : 2,
                                overflow: _isDescriptionExpanded
                                    ? null
                                    : TextOverflow.ellipsis,
                              ),
                              if (_video.videoDescription.length > 100)
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _isDescriptionExpanded =
                                          !_isDescriptionExpanded;
                                    });
                                  },
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
                                      color: Color(0xFFFF6B35),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        // Tags
                        if (_video.videoTags.isNotEmpty) ...[
                          if (_video.videoDescription.isNotEmpty)
                            const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: _video.videoTags.map((tag) {
                              return InkWell(
                                onTap: () {
                                  // TODO: Navigate to tag search
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF6B35,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFFF6B35,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '#$tag',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFFFF6B35),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              // Divider
              SliverToBoxAdapter(
                child: Container(height: 8, color: const Color(0xFFF5F5F5)),
              ),
              // Comments Section
              Builder(
                builder: (context) {
                  final authRepository = context.read<AuthRepository>();
                  final isAuthenticated = authRepository.currentUser != null;

                  if (!isAuthenticated) {
                    // Show sign-in prompt for unauthenticated users
                    return SliverToBoxAdapter(
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAFAFA),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.comment_outlined,
                                size: 48,
                                color: Color(0xFF6B6B6B),
                              ),
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
                            const SizedBox(height: 8),
                            const Text(
                              'Join the conversation by signing in.',
                              style: TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton(
                              onPressed: () {
                                _showSignInRequiredDialog();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFFF6B35),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Sign In'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // 1️⃣ Inline Comment Experience
                  return SliverToBoxAdapter(
                    child: Column(
                      children: [
                        // zero-friction entry bar
                        InlineCommentEntryBar(
                          controller: _commentsController,
                          onTap: _openCommentsSheet,
                          onSignInRequired: _showSignInRequiredDialog,
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        // latest comment preview
                        LatestCommentPreview(
                          controller: _commentsController,
                          onTap: _openCommentsSheet,
                        ),
                      ],
                    ),
                  );
                },
              ),
              // Suggested Videos Section
              SliverToBoxAdapter(
                child: _SuggestedVideosSection(
                  currentVideoId: _video.videoId,
                  onVideoSelected: _replaceVideo,
                  onVideosLoaded: (videos) {
                    setState(() {
                      _suggestedVideos = videos;
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
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
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF6B35).withOpacity(0.05)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? const Color(0xFFFF6B35)
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
                        ? const Color(0xFFFF6B35)
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

/// Suggested Videos Section
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
  String? _seed;

  @override
  void initState() {
    super.initState();
    _loadSuggestedVideos();
  }

  @override
  void didUpdateWidget(_SuggestedVideosSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the current video changed, reload suggested videos with a new seed
    if (oldWidget.currentVideoId != widget.currentVideoId) {
      _loadSuggestedVideos(useNewSeed: true);
    }
  }

  /// Generates a new random seed for video pagination
  String _generateNewSeed() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        32, // 32 character seed
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }

  Future<void> _loadSuggestedVideos({bool useNewSeed = false}) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Generate a new seed if requested or if we don't have one yet
      if (useNewSeed || _seed == null) {
        _seed = _generateNewSeed();
        debugPrint(
          'SuggestedVideosSection: Generated new seed: $_seed (useNewSeed: $useNewSeed)',
        );
      }

      final videoRepository = context.read<VideoRepository>();
      final videos = await videoRepository.getVideos(
        page: 1,
        limit: 10,
        seed: _seed,
      );

      // Filter out the current video
      final filtered = videos
          .where((video) => video.videoId != widget.currentVideoId)
          .take(6) // Show up to 6 suggested videos
          .toList();

      if (mounted) {
        setState(() {
          _suggestedVideos = filtered;
          _isLoading = false;
        });
        // Notify parent about loaded videos for autoplay
        widget.onVideosLoaded?.call(_suggestedVideos);
      }
    } catch (e) {
      debugPrint('Error loading suggested videos: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFFF6B35)),
        ),
      );
    }

    if (_hasError || _suggestedVideos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(
                    right: index == _suggestedVideos.length - 1 ? 0 : 12,
                  ),
                  child: _SuggestedVideoCard(
                    video: _suggestedVideos[index],
                    onTap: widget.onVideoSelected,
                  ),
                );
              },
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

  String? get _thumbnailUrl {
    return ImageUtils.getVideoThumbnailUrl(video.videoThumbnail);
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = 160.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Replace current video instead of navigating to new route
          onTap(video);
        },
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _thumbnailUrl == null || _thumbnailUrl!.isEmpty
                          ? Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.video_library,
                                  size: 32,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            )
                          : Image.network(
                              _thumbnailUrl!,
                              headers: ImageUtils.getVideoThumbnailHeaders(),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Center(
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 32,
                                      color: Color(0xFF6B6B6B),
                                    ),
                                  ),
                                );
                              },
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[200],
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xFFFF6B35),
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    );
                                  },
                            ),
                      // View count overlay
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.visibility,
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                _formatCount(video.videoViews),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Title
              Text(
                video.videoTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              // Uploader
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
                      video.userUsername.isNotEmpty
                          ? video.userUsername
                          : 'Unknown',
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
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}
