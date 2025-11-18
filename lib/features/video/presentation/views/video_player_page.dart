import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/comment_model.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import '../../../user/data/user_repository.dart';
import '../../../user/domain/models/user_model.dart';

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({super.key, required this.video});

  final VideoModel video;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isBuffering = false;
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
  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  List<CommentModel> _comments = [];
  bool _isLoadingComments = false;
  bool _isPostingComment = false;
  int _currentCommentPage = 1;
  static const int _commentPageLimit = 20;
  final Map<String, bool> _expandedReplies =
      {}; // Track which comments have expanded replies
  final Map<String, List<ReplyModel>> _commentReplies =
      {}; // Cache replies per comment
  final Map<String, bool> _loadingReplies =
      {}; // Track which comments are loading replies

  @override
  void initState() {
    super.initState();
    _upvoteCount = widget.video.videoUpvotes;
    _downvoteCount = widget.video.videoDownvotes;

    // Initialize vote status based on user's current vote
    if (widget.video.userVoteStatus != null) {
      if (widget.video.userVoteStatus == 'upvoted') {
        _isUpvoted = true;
        _isDownvoted = false;
      } else if (widget.video.userVoteStatus == 'downvoted') {
        _isUpvoted = false;
        _isDownvoted = true;
      }
    }

    _fetchAndInitializePlayer();
    _loadComments();
    _loadUserAndFollowStatus();
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
      if (widget.video.userUsername.isNotEmpty &&
          _currentUser?.username != widget.video.userUsername) {
        setState(() {
          _isLoadingFollowStatus = true;
        });

        try {
          _videoOwner = await userRepository.getUser(widget.video.userUsername);
          setState(() {
            _isFollowing = _videoOwner?.isFollowing ?? false;
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
    if (widget.video.userUsername.isEmpty) return;
    if (_currentUser?.username == widget.video.userUsername)
      return; // Can't follow yourself

    final wasFollowing = _isFollowing;

    // Optimistic update
    setState(() {
      _isFollowing = !_isFollowing;
    });

    try {
      final userRepository = context.read<UserRepository>();

      if (wasFollowing) {
        await userRepository.unfollowUser(widget.video.userUsername);
      } else {
        await userRepository.followUser(widget.video.userUsername);
      }

      // Reload user to get updated follow status
      _videoOwner = await userRepository.getUser(widget.video.userUsername);
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

  void _videoPlayerListener() {
    if (!mounted) return;
    final controller = _videoPlayerController;
    if (controller == null) return;

    final isBuffering = controller.value.isBuffering;
    if (_isBuffering != isBuffering) {
      setState(() {
        _isBuffering = isBuffering;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.removeListener(_videoPlayerListener);
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    _replyControllers.clear();
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  Future<void> _fetchAndInitializePlayer() async {
    try {
      // Fetch the video URL from the API
      final videoRepository = context.read<VideoRepository>();
      _videoUrlFromApi = await videoRepository.getVideoUrl(
        widget.video.videoUrl,
      );

      if (_videoUrlFromApi == null || _videoUrlFromApi!.isEmpty) {
        throw Exception('Failed to get video URL from API');
      }

      // Fetch vote status if not already in the video model
      if (widget.video.userVoteStatus == null) {
        try {
          final voteStatus = await videoRepository.getUserVoteStatus(
            widget.video.videoId,
          );
          if (mounted && voteStatus != null) {
            setState(() {
              if (voteStatus == 'upvoted') {
                _isUpvoted = true;
                _isDownvoted = false;
              } else if (voteStatus == 'downvoted') {
                _isUpvoted = false;
                _isDownvoted = true;
              }
            });
          }
        } catch (e) {
          // Silently fail - vote status is optional
          debugPrint('Failed to fetch vote status: $e');
        }
      }

      await _initializePlayer();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  Future<void> _initializePlayer() async {
    if (_videoUrlFromApi == null) return;

    try {
      // Configure video player for progressive download/streaming
      // This allows the video to start playing as soon as enough data is buffered
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_videoUrlFromApi!),
        httpHeaders: {
          // Accept video content types for better streaming support
          'Accept': 'video/*',
        },
        // Configure for progressive playback
        videoPlayerOptions: VideoPlayerOptions(
          // Don't mix with other audio sources
          mixWithOthers: false,
          // Don't allow background playback
          allowBackgroundPlayback: false,
        ),
      );

      // Initialize the controller
      // This returns as soon as metadata is available, not when full video is loaded
      await _videoPlayerController!.initialize();

      // Add listener to track buffering state
      _videoPlayerController!.addListener(_videoPlayerListener);

      // Start playing immediately after initialization
      // The video will buffer progressively while playing
      // This is the key: we don't wait for full buffering before starting playback
      await _videoPlayerController!.play();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
        // Configure for better buffering experience
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: const Color(0xFF9146FF),
          handleColor: const Color(0xFF9146FF),
          backgroundColor: Colors.grey.withOpacity(0.3),
          bufferedColor: Colors.grey.withOpacity(0.5),
        ),
        placeholder: Container(
          color: Colors.black,
          child: Center(
            child: CircularProgressIndicator(color: const Color(0xFF9146FF)),
          ),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading video',
                  style: TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
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

  Future<void> _loadComments() async {
    if (_isLoadingComments) return;

    setState(() {
      _isLoadingComments = true;
    });

    try {
      final videoRepository = context.read<VideoRepository>();
      final comments = await videoRepository.getComments(
        widget.video.videoId,
        page: _currentCommentPage,
        limit: _commentPageLimit,
      );

      if (mounted) {
        setState(() {
          if (_currentCommentPage == 1) {
            _comments = comments;
          } else {
            _comments.addAll(comments);
          }
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load comments: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _postComment() async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty || _isPostingComment) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      final videoRepository = context.read<VideoRepository>();
      await videoRepository.postComment(widget.video.videoId, commentText);

      // Clear the input
      _commentController.clear();

      // Reload comments to show the new one
      _currentCommentPage = 1;
      await _loadComments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Comment posted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post comment: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPostingComment = false;
        });
      }
    }
  }

  Future<void> _loadReplies(
    String commentId, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _commentReplies.containsKey(commentId)) {
      // Already loaded, skip unless forcing refresh
      return;
    }

    if (_loadingReplies[commentId] == true) {
      // Already loading, skip
      return;
    }

    setState(() {
      _loadingReplies[commentId] = true;
    });

    try {
      final videoRepository = context.read<VideoRepository>();
      final replies = await videoRepository.getReplies(
        commentId,
        page: 1,
        limit: 50, // Load all replies for now
      );

      if (mounted) {
        setState(() {
          _commentReplies[commentId] = replies;
          _loadingReplies[commentId] = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to load replies: $e');
      if (mounted) {
        setState(() {
          _loadingReplies[commentId] = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load replies: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _postReply(String commentId) async {
    final replyController = _replyControllers[commentId];
    if (replyController == null) return;

    final replyText = replyController.text.trim();
    if (replyText.isEmpty) return;

    try {
      final videoRepository = context.read<VideoRepository>();
      await videoRepository.postReply(commentId, replyText);

      // Clear the input
      replyController.clear();

      // Force reload replies to show the new one
      await _loadReplies(commentId, forceRefresh: true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reply posted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post reply: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleReplies(String commentId) {
    setState(() {
      if (_expandedReplies[commentId] == true) {
        _expandedReplies[commentId] = false;
      } else {
        _expandedReplies[commentId] = true;
        // Load replies if not already loaded
        if (!_commentReplies.containsKey(commentId)) {
          _loadReplies(commentId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
          style: IconButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.5),
            padding: const EdgeInsets.all(8),
          ),
        ),
        systemOverlayStyle: Theme.of(context).appBarTheme.systemOverlayStyle,
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Video Player Section
            SliverToBoxAdapter(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _isLoading
                    ? Container(
                        color: Colors.black,
                        child: Center(
                          child: CircularProgressIndicator(
                            color: const Color(0xFFFF6B35),
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
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Chewie(controller: _chewieController!),
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
                      widget.video.videoTitle,
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
                          '${_formatCount(widget.video.videoViews)} views',
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
                          _formatDate(widget.video.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Action Buttons Row
                    Row(
                      children: [
                        Expanded(
                          child: _VideoActionButton(
                            icon: _isUpvoted
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            label: _formatCount(_upvoteCount),
                            isActive: _isUpvoted,
                            onTap: () async {
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
                                  widget.video.videoId,
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VideoActionButton(
                            icon: _isDownvoted
                                ? Icons.thumb_down
                                : Icons.thumb_down_outlined,
                            label: _formatCount(_downvoteCount),
                            isActive: _isDownvoted,
                            onTap: () async {
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
                                  widget.video.videoId,
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
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _VideoActionButton(
                            icon: Icons.share_outlined,
                            label: 'Share',
                            onTap: () {
                              _showShareDialog(context);
                            },
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF6B6B6B),
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onPressed: () {
                            // TODO: Show more options
                          },
                        ),
                      ],
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
                        if (widget.video.userUsername.isNotEmpty) {
                          context.push('/users/${widget.video.userUsername}');
                        }
                      },
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFFFF6B35),
                        child: Text(
                          widget.video.userUsername.isNotEmpty
                              ? widget.video.userUsername[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          if (widget.video.userUsername.isNotEmpty) {
                            context.push('/users/${widget.video.userUsername}');
                          }
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.video.userUsername.isNotEmpty
                                  ? widget.video.userUsername
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
                    // Show follow button only if not own video and username is available
                    if (_currentUser != null &&
                        _currentUser!.username != widget.video.userUsername &&
                        widget.video.userUsername.isNotEmpty)
                      _isLoadingFollowStatus
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : ElevatedButton(
                              onPressed: _handleFollowUnfollow,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isFollowing
                                    ? Colors.grey[300]
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                _isFollowing ? 'Unfollow' : 'Follow',
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
            if (widget.video.videoDescription.isNotEmpty ||
                widget.video.videoTags.isNotEmpty)
              SliverToBoxAdapter(
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      if (widget.video.videoDescription.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.video.videoDescription,
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
                            if (widget.video.videoDescription.length > 100)
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
                      if (widget.video.videoTags.isNotEmpty) ...[
                        if (widget.video.videoDescription.isNotEmpty)
                          const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: widget.video.videoTags.map((tag) {
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
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Comment Count Header
                    Row(
                      children: [
                        Text(
                          '${_formatCount(widget.video.videoComments)} Comments',
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Sort comments
                          },
                          icon: const Icon(
                            Icons.sort,
                            size: 16,
                            color: Color(0xFF6B6B6B),
                          ),
                          label: const Text(
                            'Sort',
                            style: TextStyle(
                              color: Color(0xFF6B6B6B),
                              fontSize: 13,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Comment Input
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFFF6B35),
                          child: const Icon(
                            Icons.person,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _commentController,
                            decoration: InputDecoration(
                              hintText: 'Add a comment...',
                              filled: true,
                              fillColor: const Color(0xFFFAFAFA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24),
                                borderSide: const BorderSide(
                                  color: Color(0xFFFF6B35),
                                  width: 1.5,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              hintStyle: const TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: 14,
                              ),
                              suffixIcon: _commentController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(
                                        Icons.send,
                                        color: Color(0xFFFF6B35),
                                        size: 20,
                                      ),
                                      onPressed: _isPostingComment
                                          ? null
                                          : _postComment,
                                      padding: const EdgeInsets.only(right: 8),
                                    )
                                  : null,
                            ),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 14,
                            ),
                            maxLines: null,
                            minLines: 1,
                            textInputAction: TextInputAction.send,
                            onChanged: (value) {
                              setState(() {});
                            },
                            onSubmitted: (value) {
                              if (value.trim().isNotEmpty &&
                                  !_isPostingComment) {
                                _postComment();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Comments List
                    if (_isLoadingComments && _comments.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFFFF6B35),
                          ),
                        ),
                      )
                    else if (_comments.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
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
                                'No comments yet',
                                style: TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Start the conversation.',
                                style: TextStyle(
                                  color: Color(0xFF6B6B6B),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ..._comments.map(
                        (comment) => _buildCommentWidget(comment),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentWidget(CommentModel comment) {
    // Initialize reply controller if not exists
    if (!_replyControllers.containsKey(comment.commentId)) {
      _replyControllers[comment.commentId] = TextEditingController();
    }

    final replies = _commentReplies[comment.commentId] ?? [];
    final isRepliesExpanded = _expandedReplies[comment.commentId] ?? false;
    final isLoadingReplies = _loadingReplies[comment.commentId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFFF6B35),
                child: Text(
                  (comment.commentByUsername ?? comment.commentedBy).isNotEmpty
                      ? (comment.commentByUsername ?? comment.commentedBy)[0]
                            .toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            comment.commentByUsername ?? comment.commentedBy,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          _formatDate(comment.commentedAt),
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment.comment,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Reply button
                    TextButton.icon(
                      onPressed: () => _toggleReplies(comment.commentId),
                      icon: const Icon(
                        Icons.reply,
                        size: 16,
                        color: Color(0xFF6B6B6B),
                      ),
                      label: Text(
                        comment.totalReplies > 0
                            ? '${comment.totalReplies} ${comment.totalReplies == 1 ? 'reply' : 'replies'}'
                            : 'Reply',
                        style: const TextStyle(
                          color: Color(0xFF6B6B6B),
                          fontSize: 12,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Replies section
          if (isRepliesExpanded) ...[
            const SizedBox(height: 12),
            // Loading indicator
            if (isLoadingReplies)
              Container(
                margin: const EdgeInsets.only(left: 42, bottom: 12),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            // Replies list
            else if (replies.isNotEmpty)
              ...replies.map(
                (reply) => Container(
                  margin: const EdgeInsets.only(left: 42, bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        backgroundColor: const Color(
                          0xFFFF6B35,
                        ).withOpacity(0.2),
                        child: Text(
                          reply.repliedBy.isNotEmpty
                              ? reply.repliedBy[0].toUpperCase()
                              : 'U',
                          style: const TextStyle(
                            color: Color(0xFFFF6B35),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    reply.repliedBy,
                                    style: const TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatDate(reply.repliedAt),
                                  style: const TextStyle(
                                    color: Color(0xFF6B6B6B),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reply.reply,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Reply input
            Container(
              margin: const EdgeInsets.only(left: 42, top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyControllers[comment.commentId],
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        filled: true,
                        fillColor: const Color(0xFFFAFAFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF6B35),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        hintStyle: const TextStyle(
                          color: Color(0xFF6B6B6B),
                          fontSize: 13,
                        ),
                        suffixIcon:
                            _replyControllers[comment.commentId]
                                    ?.text
                                    .isNotEmpty ==
                                true
                            ? IconButton(
                                icon: const Icon(
                                  Icons.send,
                                  color: Color(0xFFFF6B35),
                                  size: 18,
                                ),
                                onPressed: () => _postReply(comment.commentId),
                                padding: const EdgeInsets.only(right: 8),
                              )
                            : null,
                      ),
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 13,
                      ),
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onChanged: (value) {
                        setState(() {});
                      },
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _postReply(comment.commentId);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showShareDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Share Video',
          style: TextStyle(color: Color(0xFF1A1A1A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.link, color: Color(0xFFFF6B35)),
              title: const Text(
                'Copy Link',
                style: TextStyle(color: Color(0xFF1A1A1A)),
              ),
              onTap: () {
                // TODO: Copy video link to clipboard
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Color(0xFFFF6B35)),
              title: const Text(
                'Share via...',
                style: TextStyle(color: Color(0xFF1A1A1A)),
              ),
              onTap: () {
                // TODO: Open native share dialog
                Navigator.pop(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF6B6B6B)),
            ),
          ),
        ],
      ),
    );
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF6B35).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF6B6B6B),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? const Color(0xFFFF6B35)
                        : const Color(0xFF6B6B6B),
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
