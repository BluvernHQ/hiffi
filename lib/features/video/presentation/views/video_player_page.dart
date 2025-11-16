import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../domain/models/video_model.dart';

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
  bool _isDescriptionExpanded = false;
  bool _isUpvoted = false;
  bool _isDownvoted = false;
  int _upvoteCount = 0;
  int _downvoteCount = 0;

  String get _videoUrl =>
      'https://blr1.digitaloceanspaces.com/dev.hiffi/${widget.video.videoUrl}';

  @override
  void initState() {
    super.initState();
    _upvoteCount = widget.video.videoUpvotes;
    _downvoteCount = widget.video.videoDownvotes;
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(
        Uri.parse(_videoUrl),
      );
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: true,
        looping: false,
        aspectRatio: _videoPlayerController!.value.aspectRatio,
        showControls: true,
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

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
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
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
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
                                  _initializePlayer();
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      widget.video.videoTitle,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Stats Row (Views and Date)
                    Row(
                      children: [
                        Text(
                          '${_formatCount(widget.video.videoViews)} views',
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Color(0xFF6B6B6B),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _formatDate(widget.video.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF6B6B6B),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Action Buttons Row
                    Row(
                      children: [
                        _VideoActionButton(
                          icon: _isUpvoted
                              ? Icons.thumb_up
                              : Icons.thumb_up_outlined,
                          label: _formatCount(_upvoteCount),
                          isActive: _isUpvoted,
                          onTap: () {
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
                            // TODO: Implement API call for upvote
                          },
                        ),
                        const SizedBox(width: 12),
                        _VideoActionButton(
                          icon: _isDownvoted
                              ? Icons.thumb_down
                              : Icons.thumb_down_outlined,
                          label: _formatCount(_downvoteCount),
                          isActive: _isDownvoted,
                          onTap: () {
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
                            // TODO: Implement API call for downvote
                          },
                        ),
                        const SizedBox(width: 12),
                        _VideoActionButton(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () {
                            _showShareDialog(context);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Color(0xFF6B6B6B),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFFF6B35),
                      child: Text(
                        widget.video.userUsername.isNotEmpty
                            ? widget.video.userUsername[0].toUpperCase()
                            : 'U',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.video.userUsername.isNotEmpty
                                ? widget.video.userUsername
                                : 'Unknown User',
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Implement subscribe/follow
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6B35),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      onLongPress: () {
                        // TODO: Show follow options
                      },
                      child: const Text(
                        'Follow',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
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
                                fontSize: 15,
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
                                  minimumSize: const Size(0, 32),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  _isDescriptionExpanded
                                      ? 'Show less'
                                      : 'Show more',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFFF6B35),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      // Tags
                      if (widget.video.videoTags.isNotEmpty) ...[
                        if (widget.video.videoDescription.isNotEmpty)
                          const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: widget.video.videoTags.map((tag) {
                            return InkWell(
                              onTap: () {
                                // TODO: Navigate to tag search
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFFF6B35,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
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
                                    fontSize: 13,
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
              child: Container(height: 1, color: const Color(0xFFE0E0E0)),
            ),
            // Comments Section
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
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
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () {
                            // TODO: Sort comments
                          },
                          icon: const Icon(
                            Icons.sort,
                            size: 18,
                            color: Color(0xFF6B6B6B),
                          ),
                          label: const Text(
                            'Sort by',
                            style: TextStyle(color: Color(0xFF6B6B6B)),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 36),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Comment Input
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFFFF6B35),
                          child: const Icon(
                            Icons.person,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextField(
                                decoration: InputDecoration(
                                  hintText: 'Add a comment...',
                                  filled: true,
                                  fillColor: const Color(0xFFFAFAFA),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE0E0E0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFFF6B35),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF6B6B6B),
                                  ),
                                ),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 15,
                                ),
                                maxLines: null,
                                minLines: 1,
                                onSubmitted: (value) {
                                  if (value.trim().isNotEmpty) {
                                    // TODO: Implement comment submission
                                  }
                                },
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton(
                                    onPressed: () {
                                      // TODO: Cancel comment
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Color(0xFF6B6B6B),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton(
                                    onPressed: () {
                                      // TODO: Submit comment
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFF6B35),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: const Text(
                                      'Comment',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Comments List (Placeholder)
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFFF6B35).withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: isActive
                    ? const Color(0xFFFF6B35)
                    : const Color(0xFF6B6B6B),
              ),
              if (label.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
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
