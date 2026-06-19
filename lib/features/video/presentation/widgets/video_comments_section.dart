import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hiffi/features/video/domain/models/comment_model.dart';
import 'package:hiffi/features/video/presentation/controllers/video_comments_controller.dart';
import 'package:provider/provider.dart';
import 'package:hiffi/features/auth/data/auth_repository.dart';
import 'package:hiffi/features/user/presentation/viewmodels/user_view_model.dart';
import 'package:hiffi/core/widgets/hiffi_image.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../../../../core/analytics/first_party_analytics_service.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../flags/presentation/widgets/report_flag_sheet.dart';

/// Username for a new comment/reply: [AuthRepository] can lag behind [UserViewModel].
String resolvedCommentPosterUsername(
  AuthRepository auth,
  UserViewModel userVm,
) {
  final fromAuth = auth.currentUser?.username?.trim();
  if (fromAuth != null && fromAuth.isNotEmpty) return fromAuth;
  final profile = userVm.currentUser;
  final fromProfile = profile?.username.trim();
  if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
  return auth.currentUser?.username ?? 'Anonymous';
}

/// 1️⃣ Inline Comment Entry Bar (The zero-friction entry point)
class InlineCommentEntryBar extends StatelessWidget {
  final VideoCommentsController controller;
  final VoidCallback onTap;
  final VoidCallback? onSignInRequired;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const InlineCommentEntryBar({
    super.key,
    required this.controller,
    required this.onTap,
    this.onSignInRequired,
    this.backgroundColor = Colors.white,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 12),
  });

  @override
  Widget build(BuildContext context) {
    final authRepository = context.watch<AuthRepository>();
    final userViewModel = context.watch<UserViewModel>();
    final authUser = authRepository.currentUser;
    final userProfile = userViewModel.currentUser;
    final isLoggedIn = authUser != null;

    return GestureDetector(
      onTap: () {
        if (!isLoggedIn) {
          if (onSignInRequired != null) {
            onSignInRequired!();
          } else {
            context.push('/login');
          }
        } else {
          controller.setShouldFocus(true);
          onTap();
        }
      },
      child: Container(
        padding: padding,
        color: backgroundColor,
        child: Row(
          children: [
            HiffiAvatar(
              imageUrl: userProfile?.profilePicture ?? authUser?.profilePicture,
              size: 32,
              fallbackText: userProfile?.username ?? authUser?.username,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFFED1C2F).withOpacity(0.3),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isLoggedIn ? 'Add a comment...' : 'Sign in to comment...',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: () {
                if (!isLoggedIn) {
                  if (onSignInRequired != null) {
                    onSignInRequired!();
                  } else {
                    context.push('/login');
                  }
                } else {
                  controller.setShouldFocus(true);
                  onTap();
                }
              },
              icon: const Icon(
                Icons.send_rounded,
                color: Color(0xFFED1C2F),
                size: 20,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

/// 2️⃣ Latest Comment Preview (Collapsed State)
class LatestCommentPreview extends StatelessWidget {
  final VideoCommentsController controller;
  final VoidCallback onTap;
  final bool showHeaderRow;
  final bool absorbTap;
  final EdgeInsetsGeometry padding;
  final Color backgroundColor;

  const LatestCommentPreview({
    super.key,
    required this.controller,
    required this.onTap,
    this.showHeaderRow = true,
    this.absorbTap = true,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasComment = controller.latestComment != null;
        final commentCount = controller.totalCommentsCount;

        final content = Container(
          padding: padding,
          color: backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeaderRow && commentCount > 0) ...[
                Row(
                  children: [
                    Text(
                      '$commentCount Comments',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Color(0xFF6B6B6B),
                    ),
                  ],
                ),
              ],
              if (hasComment && commentCount > 0) ...[
                if (showHeaderRow) const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HiffiAvatar(
                      imageUrl: controller.latestComment!.profilePicture,
                      size: 32,
                      fallbackText: controller.latestComment!.commentByUsername,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                controller.latestComment!.commentByUsername ??
                                    'Anonymous',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(
                                  controller.latestComment!.commentedAt,
                                ),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            controller.latestComment!.comment,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (commentCount > 1) ...[
                  const SizedBox(height: 12),
                  Text(
                    'View all $commentCount comments',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFED1C2F),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );

        if (!absorbTap) {
          return content;
        }
        return GestureDetector(onTap: onTap, child: content);
      },
    );
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    return 'Just now';
  }
}

/// Grouped comments block for the video player scroll (discoverable section).
class VideoPlayerCommentsPanel extends StatelessWidget {
  const VideoPlayerCommentsPanel({
    super.key,
    required this.controller,
    required this.onOpenSheet,
    this.onSignInRequired,
  });

  final VideoCommentsController controller;
  final VoidCallback onOpenSheet;
  final VoidCallback? onSignInRequired;

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final count = controller.totalCommentsCount;
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 20 + bottomSafe),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1A1A1A).withValues(alpha: 0.06),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 22,
                        color: const Color(0xFFED1C2F).withValues(alpha: 0.95),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (count > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(
                                0xFF1A1A1A,
                              ).withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ),
                      const Spacer(),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            unawaited(
                              context
                                  .read<FirstPartyAnalyticsService>()
                                  .capture(
                                    r'$click',
                                    elementUiName: 'opened-comments',
                                    screenName: 'watch',
                                    videoId: controller.videoId,
                                    properties: {
                                      'source': 'watch',
                                      'source_path':
                                          '/watch/${controller.videoId}',
                                      'path': '/watch/${controller.videoId}',
                                      'video_id': controller.videoId,
                                    },
                                  ),
                            );
                            onOpenSheet();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: Color(0xFF6B6B6B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (count > 0) ...[
                    const SizedBox(height: 4),
                    const Text(
                      'Preview below. Tap to read the full thread.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B6B6B),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () {
                          unawaited(
                            context.read<FirstPartyAnalyticsService>().capture(
                              r'$click',
                              elementUiName: 'opened-comments',
                              screenName: 'watch',
                              videoId: controller.videoId,
                              properties: {
                                'source': 'watch',
                                'source_path': '/watch/${controller.videoId}',
                                'path': '/watch/${controller.videoId}',
                                'video_id': controller.videoId,
                              },
                            ),
                          );
                          onOpenSheet();
                        },
                        child: LatestCommentPreview(
                          controller: controller,
                          onTap: onOpenSheet,
                          showHeaderRow: false,
                          absorbTap: false,
                          padding: const EdgeInsets.all(12),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else
                    const SizedBox(height: 12),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF1A1A1A).withValues(alpha: 0.06),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: InlineCommentEntryBar(
                        controller: controller,
                        onTap: onOpenSheet,
                        onSignInRequired: onSignInRequired,
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 3️⃣ Primary Bottom Sheet
class CommentsBottomSheet extends StatefulWidget {
  final VideoCommentsController controller;
  final VoidCallback? onSignInRequired;

  const CommentsBottomSheet({
    super.key,
    required this.controller,
    this.onSignInRequired,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.fetchAllComments();
      if (widget.controller.shouldFocusInput) {
        _focusNode.requestFocus();
        widget.controller.setShouldFocus(false);
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // 🔹 Sticky Header
              _buildHeader(context),
              const Divider(height: 1),

              // 🔹 Comment List
              Expanded(
                child: ListenableBuilder(
                  listenable: widget.controller,
                  builder: (context, _) {
                    if (widget.controller.state == CommentsState.loading &&
                        widget.controller.comments.isEmpty) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFED1C2F),
                        ),
                      );
                    }

                    if (widget.controller.state == CommentsState.error) {
                      final message =
                          widget.controller.errorMessage ??
                          'Failed to load comments. Please try again.';
                      final isOffline = isOfflineErrorMessage(message);
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isOffline
                                    ? Icons.wifi_off_rounded
                                    : Icons.error_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                message,
                                style: const TextStyle(
                                  color: Color(0xFF6B6B6B),
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (widget.controller.comments.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: widget.controller.comments.length,
                      itemBuilder: (context, index) {
                        return CommentTile(
                          comment: widget.controller.comments[index],
                          controller: widget.controller,
                          onSignInRequired: widget.onSignInRequired,
                        );
                      },
                    );
                  },
                ),
              ),

              // 5️⃣ Sticky Comment Composer
              CommentComposer(
                controller: widget.controller,
                focusNode: _focusNode,
                onSignInRequired: widget.onSignInRequired,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) {
              final count = widget.controller.totalCommentsCount;
              return Text(
                count > 0 ? '$count Comments' : 'Comments',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

/// 4️⃣ Comment Tile & Replies
class CommentTile extends StatefulWidget {
  final CommentModel comment;
  final VideoCommentsController controller;
  final VoidCallback? onSignInRequired;

  const CommentTile({
    super.key,
    required this.comment,
    required this.controller,
    this.onSignInRequired,
  });

  @override
  State<CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<CommentTile> {
  bool _showReplies = false;
  final TextEditingController _replyController = TextEditingController();
  final FocusNode _replyFocusNode = FocusNode();
  bool _isReplying = false;

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthRepository>().currentUser;
    final userProfile = context.watch<UserViewModel>().currentUser;

    // Check by UID first (most reliable), fallback to username
    final isOwnComment =
        (user != null &&
            (user.uid == widget.comment.commentedBy ||
                (user.username != null &&
                    user.username == widget.comment.commentByUsername))) ||
        (userProfile != null &&
            (userProfile.uid == widget.comment.commentedBy ||
                userProfile.username == widget.comment.commentByUsername));

    if (user != null || userProfile != null) {
      debugPrint(
        'CommentTile Debug [${widget.comment.commentByUsername}]: '
        'isOwnComment: $isOwnComment, '
        'authUserUID: ${user?.uid}, authUsername: ${user?.username}, '
        'profileUID: ${userProfile?.uid}, profileUsername: ${userProfile?.username}, '
        'commentedBy: ${widget.comment.commentedBy}, commentUsername: ${widget.comment.commentByUsername}',
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main Comment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  // Debug logging
                  debugPrint(
                    'CommentTile: Rendering avatar for ${widget.comment.commentByUsername} - profilePicture: "${widget.comment.profilePicture}"',
                  );
                  return HiffiAvatar(
                    imageUrl: widget.comment.profilePicture,
                    size: 36,
                    fallbackText: widget.comment.commentByUsername,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Text(
                                widget.comment.commentByUsername ?? 'Anonymous',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _formatTime(widget.comment.commentedAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF6B6B6B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwnComment)
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Color(0xFF6B6B6B),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              unawaited(
                                context.read<FirstPartyAnalyticsService>().capture(
                                  r'$click',
                                  elementUiName:
                                      'video-comment-delete-prompt-button',
                                  screenName: 'comments',
                                  videoId: widget.controller.videoId,
                                  properties: {
                                    'source': 'watch',
                                    'source_path':
                                        '/watch/${widget.controller.videoId}',
                                    'path':
                                        '/watch/${widget.controller.videoId}',
                                    'video_id': widget.controller.videoId,
                                    'comment_id': widget.comment.commentId,
                                  },
                                ),
                              );
                              _showDeleteConfirmation(context);
                            },
                          )
                        else
                          PopupMenuButton<String>(
                            icon: const Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: Color(0xFF6B6B6B),
                            ),
                            onSelected: (value) {
                              if (value == 'report') {
                                _reportComment(context);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, size: 18),
                                    SizedBox(width: 8),
                                    Text('Report comment'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.comment.comment,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        final auth = context.read<AuthRepository>();
                        if (auth.currentUser == null) {
                          if (widget.onSignInRequired != null) {
                            widget.onSignInRequired!();
                          } else {
                            context.push('/login');
                          }
                          return;
                        }
                        unawaited(
                          context.read<FirstPartyAnalyticsService>().capture(
                            r'$click',
                            elementUiName: 'video-comment-reply-toggle-button',
                            screenName: 'comments',
                            videoId: widget.controller.videoId,
                            properties: {
                              'source': 'watch',
                              'source_path':
                                  '/watch/${widget.controller.videoId}',
                              'path': '/watch/${widget.controller.videoId}',
                              'video_id': widget.controller.videoId,
                              'comment_id': widget.comment.commentId,
                            },
                          ),
                        );
                        setState(() {
                          _isReplying = true;
                        });
                        _replyFocusNode.requestFocus();
                      },
                      child: const Text(
                        'Reply',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Replies Toggle
          if (widget.comment.totalReplies > 0)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 8),
              child: GestureDetector(
                onTap: () {
                  unawaited(
                    context.read<FirstPartyAnalyticsService>().capture(
                      r'$click',
                      elementUiName: _showReplies
                          ? 'video-comment-hide-replies-button'
                          : 'video-comment-show-replies-button',
                      screenName: 'comments',
                      videoId: widget.controller.videoId,
                      properties: {
                        'source': 'watch',
                        'source_path': '/watch/${widget.controller.videoId}',
                        'path': '/watch/${widget.controller.videoId}',
                        'video_id': widget.controller.videoId,
                        'comment_id': widget.comment.commentId,
                      },
                    ),
                  );
                  setState(() => _showReplies = !_showReplies);
                  if (_showReplies && widget.comment.replies.isEmpty) {
                    widget.controller.fetchReplies(widget.comment.commentId);
                  }
                },
                child: Row(
                  children: [
                    Icon(
                      _showReplies
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: const Color(0xFFED1C2F),
                      size: 20,
                    ),
                    Text(
                      _showReplies
                          ? 'Hide ${widget.comment.totalReplies} replies'
                          : '${widget.comment.totalReplies} reply${widget.comment.totalReplies == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFED1C2F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Lazy-loaded Replies (1 level only)
          if (_showReplies)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 12),
              child: Column(
                children: [
                  ...widget.comment.replies.map((reply) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Vertical line for reply indentation
                          Container(
                            width: 2,
                            height: 40,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          HiffiAvatar(
                            imageUrl: reply.profilePicture,
                            size: 28,
                            fallbackText: reply.replyByUsername,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Text(
                                            reply.replyByUsername ?? 'User',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: Color(0xFF1A1A1A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _formatTime(reply.repliedAt),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6B6B6B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if ((user != null &&
                                            (user.uid == reply.repliedBy ||
                                                (user.username != null &&
                                                    user.username ==
                                                        reply
                                                            .replyByUsername))) ||
                                        (userProfile != null &&
                                            (userProfile.uid ==
                                                    reply.repliedBy ||
                                                userProfile.username ==
                                                    reply.replyByUsername)))
                                      IconButton(
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          size: 16,
                                          color: Color(0xFF6B6B6B),
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () =>
                                            _showDeleteReplyConfirmation(
                                              context,
                                              reply.replyId,
                                            ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  reply.reply,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  // Reply Input Field (shown when _isReplying is true)
                  if (_isReplying)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 2,
                            height: 40,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                          HiffiAvatar(
                            imageUrl:
                                context
                                    .watch<UserViewModel>()
                                    .currentUser
                                    ?.profilePicture ??
                                context
                                    .watch<AuthRepository>()
                                    .currentUser
                                    ?.profilePicture,
                            size: 28,
                            fallbackText:
                                context
                                    .watch<UserViewModel>()
                                    .currentUser
                                    ?.username ??
                                context
                                    .watch<AuthRepository>()
                                    .currentUser
                                    ?.username,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              focusNode: _replyFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Write a reply...',
                                hintStyle: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF6B6B6B),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: const Color(
                                      0xFFED1C2F,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: const Color(
                                      0xFFED1C2F,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFED1C2F),
                                    width: 1.5,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                              ),
                              maxLines: null,
                              style: const TextStyle(fontSize: 13),
                              onSubmitted: (text) {
                                if (text.trim().isNotEmpty) {
                                  _postReply(text.trim());
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(
                              Icons.send_rounded,
                              color: Color(0xFFED1C2F),
                              size: 20,
                            ),
                            onPressed: () {
                              if (_replyController.text.trim().isNotEmpty) {
                                unawaited(
                                  context.read<FirstPartyAnalyticsService>().capture(
                                    r'$click',
                                    elementUiName:
                                        'video-comment-reply-submit-button',
                                    screenName: 'comments',
                                    videoId: widget.controller.videoId,
                                    properties: {
                                      'source': 'watch',
                                      'source_path':
                                          '/watch/${widget.controller.videoId}',
                                      'path':
                                          '/watch/${widget.controller.videoId}',
                                      'video_id': widget.controller.videoId,
                                      'comment_id': widget.comment.commentId,
                                    },
                                  ),
                                );
                                _postReply(_replyController.text.trim());
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.close,
                              size: 18,
                              color: Color(0xFF6B6B6B),
                            ),
                            onPressed: () {
                              unawaited(
                                context.read<FirstPartyAnalyticsService>().capture(
                                  r'$click',
                                  elementUiName:
                                      'video-comment-reply-cancel-button',
                                  screenName: 'comments',
                                  videoId: widget.controller.videoId,
                                  properties: {
                                    'source': 'watch',
                                    'source_path':
                                        '/watch/${widget.controller.videoId}',
                                    'path':
                                        '/watch/${widget.controller.videoId}',
                                    'video_id': widget.controller.videoId,
                                    'comment_id': widget.comment.commentId,
                                  },
                                ),
                              );
                              setState(() {
                                _isReplying = false;
                                _replyController.clear();
                              });
                              _replyFocusNode.unfocus();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

          // Reply Input Field (shown when _isReplying is true and replies are not expanded)
          if (_isReplying && !_showReplies)
            Padding(
              padding: const EdgeInsets.only(left: 48, top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HiffiAvatar(
                    imageUrl:
                        context
                            .watch<UserViewModel>()
                            .currentUser
                            ?.profilePicture ??
                        context
                            .watch<AuthRepository>()
                            .currentUser
                            ?.profilePicture,
                    size: 28,
                    fallbackText:
                        context.watch<UserViewModel>().currentUser?.username ??
                        context.watch<AuthRepository>().currentUser?.username,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      focusNode: _replyFocusNode,
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B6B6B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: const Color(0xFFED1C2F).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: const Color(0xFFED1C2F).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFFED1C2F),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      maxLines: null,
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (text) {
                        if (text.trim().isNotEmpty) {
                          _postReply(text.trim());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFFED1C2F),
                      size: 20,
                    ),
                    onPressed: () {
                      if (_replyController.text.trim().isNotEmpty) {
                        unawaited(
                          context.read<FirstPartyAnalyticsService>().capture(
                            r'$click',
                            elementUiName: 'video-comment-reply-submit-button',
                            screenName: 'comments',
                            videoId: widget.controller.videoId,
                            properties: {
                              'source': 'watch',
                              'source_path':
                                  '/watch/${widget.controller.videoId}',
                              'path': '/watch/${widget.controller.videoId}',
                              'video_id': widget.controller.videoId,
                              'comment_id': widget.comment.commentId,
                            },
                          ),
                        );
                        _postReply(_replyController.text.trim());
                      }
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF6B6B6B),
                    ),
                    onPressed: () {
                      unawaited(
                        context.read<FirstPartyAnalyticsService>().capture(
                          r'$click',
                          elementUiName: 'video-comment-reply-cancel-button',
                          screenName: 'comments',
                          videoId: widget.controller.videoId,
                          properties: {
                            'source': 'watch',
                            'source_path':
                                '/watch/${widget.controller.videoId}',
                            'path': '/watch/${widget.controller.videoId}',
                            'video_id': widget.controller.videoId,
                            'comment_id': widget.comment.commentId,
                          },
                        ),
                      );
                      setState(() {
                        _isReplying = false;
                        _replyController.clear();
                      });
                      _replyFocusNode.unfocus();
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _postReply(String text) async {
    final auth = context.read<AuthRepository>();
    final user = auth.currentUser;
    final userVm = context.read<UserViewModel>();
    try {
      await widget.controller.postReply(
        commentId: widget.comment.commentId,
        text: text,
        username: resolvedCommentPosterUsername(auth, userVm),
        uid: user?.uid ?? 'me',
        profilePicture:
            user?.profilePicture ?? userVm.currentUser?.profilePicture,
      );
      _replyController.clear();
      setState(() {
        _isReplying = false;
        if (!_showReplies) {
          _showReplies = true;
        }
      });
      _replyFocusNode.unfocus();
      // Fetch replies to update the list
      widget.controller.fetchReplies(widget.comment.commentId);
    } catch (e) {
      // Error handling is done in the controller
    }
  }

  Future<void> _reportComment(BuildContext context) async {
    final auth = context.read<AuthRepository>();
    if (auth.currentUser == null) {
      context.push('/login');
      return;
    }
    await ReportFlagSheet.show(
      context,
      title: 'comment',
      reportType: 'comment',
      targetId: widget.comment.commentId,
      targetType: 'comment',
      metadata: {
        'message_text': widget.comment.comment,
        'video_id': widget.controller.videoId,
        'username': widget.comment.commentByUsername,
      },
    );
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        unawaited(
          context.read<FirstPartyAnalyticsService>().capture(
            r'$click',
            elementUiName: 'video-comment-delete-confirm-button',
            screenName: 'comments',
            videoId: widget.controller.videoId,
            properties: {
              'source': 'watch',
              'source_path': '/watch/${widget.controller.videoId}',
              'path': '/watch/${widget.controller.videoId}',
              'video_id': widget.controller.videoId,
              'comment_id': widget.comment.commentId,
            },
          ),
        );
        await widget.controller.deleteComment(widget.comment.commentId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete comment: $e')),
          );
        }
      }
    }
  }

  Future<void> _showDeleteReplyConfirmation(
    BuildContext context,
    String replyId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Reply'),
        content: const Text('Are you sure you want to delete this reply?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        unawaited(
          context.read<FirstPartyAnalyticsService>().capture(
            r'$click',
            elementUiName: 'video-comment-delete-confirm-button',
            screenName: 'comments',
            videoId: widget.controller.videoId,
            properties: {
              'source': 'watch',
              'source_path': '/watch/${widget.controller.videoId}',
              'path': '/watch/${widget.controller.videoId}',
              'video_id': widget.controller.videoId,
              'comment_id': widget.comment.commentId,
              'reply_id': replyId,
            },
          ),
        );
        await widget.controller.deleteReply(widget.comment.commentId, replyId);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete reply: $e')));
        }
      }
    }
  }

  String _formatTime(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return '${diff.inDays} days ago';
    if (diff.inHours > 0) return '${diff.inHours} hours ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
    if (diff.inSeconds > 30) return '${diff.inSeconds} seconds ago';
    return 'Just now';
  }
}

/// 5️⃣ Refined Sticky Comment Composer
class CommentComposer extends StatefulWidget {
  final VideoCommentsController controller;
  final FocusNode focusNode;
  final VoidCallback? onSignInRequired;

  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSignInRequired,
  });

  @override
  State<CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<CommentComposer> {
  final TextEditingController _textController = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      final canSend = _textController.text.trim().isNotEmpty;
      if (canSend != _canSend) {
        setState(() => _canSend = canSend);
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authRepository = context.watch<AuthRepository>();
    final isLoggedIn = authRepository.currentUser != null;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final replyTarget = widget.controller.replyTarget;
        final isReplying = replyTarget != null;

        final bottomPadding =
            8.0 +
            math.max(
              MediaQuery.of(context).viewInsets.bottom,
              MediaQuery.of(context).padding.bottom,
            );

        if (!isLoggedIn) {
          return Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: bottomPadding,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () {
                if (widget.onSignInRequired != null) {
                  widget.onSignInRequired!();
                } else {
                  context.push('/login');
                }
              },
              child: Row(
                children: [
                  const HiffiAvatar(imageUrl: null, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFED1C2F).withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Sign in to comment...',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: bottomPadding,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReplying)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Replying to ${replyTarget.commentByUsername}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B6B6B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          unawaited(
                            context.read<FirstPartyAnalyticsService>().capture(
                              r'$click',
                              elementUiName:
                                  'video-comment-reply-cancel-button',
                              screenName: 'comments',
                              videoId: widget.controller.videoId,
                              properties: {
                                'source': 'watch',
                                'source_path':
                                    '/watch/${widget.controller.videoId}',
                                'path': '/watch/${widget.controller.videoId}',
                                'video_id': widget.controller.videoId,
                                'comment_id': replyTarget.commentId,
                              },
                            ),
                          );
                          widget.controller.setReplyTarget(null);
                        },
                        child: const Icon(
                          Icons.close,
                          size: 18,
                          color: Color(0xFF6B6B6B),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  HiffiAvatar(
                    imageUrl:
                        context
                            .watch<UserViewModel>()
                            .currentUser
                            ?.profilePicture ??
                        context
                            .watch<AuthRepository>()
                            .currentUser
                            ?.profilePicture,
                    size: 32,
                    fallbackText:
                        context.watch<UserViewModel>().currentUser?.username ??
                        context.watch<AuthRepository>().currentUser?.username,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _textController.text.trim().isNotEmpty
                              ? const Color(0xFFED1C2F).withOpacity(0.5)
                              : Colors.grey[300]!,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _textController,
                        focusNode: widget.focusNode,
                        decoration: InputDecoration(
                          hintText: isReplying
                              ? 'Write a reply...'
                              : 'Add a comment...',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          hintStyle: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B6B6B),
                          ),
                        ),
                        maxLines: 5,
                        minLines: 1,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: _canSend
                          ? const Color(0xFFED1C2F)
                          : Colors.grey[300],
                      size: 20,
                    ),
                    onPressed: _canSend
                        ? () {
                            final auth = context.read<AuthRepository>();
                            final user = auth.currentUser;
                            final text = _textController.text.trim();
                            if (text.isEmpty) return;

                            final userVm = context.read<UserViewModel>();
                            final posterName = resolvedCommentPosterUsername(
                              auth,
                              userVm,
                            );
                            final profilePic =
                                user?.profilePicture ??
                                userVm.currentUser?.profilePicture;

                            if (isReplying) {
                              unawaited(
                                context.read<FirstPartyAnalyticsService>().capture(
                                  r'$click',
                                  elementUiName:
                                      'video-comment-reply-submit-button',
                                  screenName: 'comments',
                                  videoId: widget.controller.videoId,
                                  properties: {
                                    'source': 'watch',
                                    'source_path':
                                        '/watch/${widget.controller.videoId}',
                                    'path':
                                        '/watch/${widget.controller.videoId}',
                                    'video_id': widget.controller.videoId,
                                    'comment_id': replyTarget.commentId,
                                  },
                                ),
                              );
                              widget.controller.postReply(
                                commentId: replyTarget.commentId,
                                text: text,
                                username: posterName,
                                uid: user?.uid ?? 'me',
                                profilePicture: profilePic,
                              );
                            } else {
                              unawaited(
                                context.read<FirstPartyAnalyticsService>().capture(
                                  r'$click',
                                  elementUiName: 'video-comment-submit-button',
                                  screenName: 'comments',
                                  videoId: widget.controller.videoId,
                                  properties: {
                                    'source': 'watch',
                                    'source_path':
                                        '/watch/${widget.controller.videoId}',
                                    'path':
                                        '/watch/${widget.controller.videoId}',
                                    'video_id': widget.controller.videoId,
                                  },
                                ),
                              );
                              widget.controller.postComment(
                                text: text,
                                username: posterName,
                                uid: user?.uid ?? 'me',
                                profilePicture: profilePic,
                              );
                            }
                            _textController.clear();
                            widget.focusNode.unfocus();
                            widget.controller.setReplyTarget(null);
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
