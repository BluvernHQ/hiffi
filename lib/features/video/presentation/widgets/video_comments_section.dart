import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hiffi/features/video/domain/models/comment_model.dart';
import 'package:hiffi/features/video/presentation/controllers/video_comments_controller.dart';
import 'package:provider/provider.dart';
import 'package:hiffi/features/auth/data/auth_repository.dart';
import 'package:hiffi/core/utils/image_utils.dart';
import 'package:hiffi/core/widgets/hiffi_image.dart';
import 'package:go_router/go_router.dart';

/// 1️⃣ Inline Comment Entry Bar (The zero-friction entry point)
class InlineCommentEntryBar extends StatelessWidget {
  final VideoCommentsController controller;
  final VoidCallback onTap;
  final VoidCallback? onSignInRequired;

  const InlineCommentEntryBar({
    super.key,
    required this.controller,
    required this.onTap,
    this.onSignInRequired,
  });

  @override
  Widget build(BuildContext context) {
    final authRepository = context.watch<AuthRepository>();
    final user = authRepository.currentUser;
    final isLoggedIn = user != null;

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: Colors.white,
        child: Row(
          children: [
            HiffiAvatar(
              imageUrl: user?.profilePicture,
              size: 32,
              fallbackText: user?.username,
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
                    color: const Color(0xFFFF6B35).withOpacity(0.3),
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
                color: Color(0xFFFF6B35),
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

  const LatestCommentPreview({
    super.key,
    required this.controller,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final hasComment = controller.latestComment != null;
        final commentCount = controller.totalCommentsCount;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                if (hasComment && commentCount > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HiffiAvatar(
                        imageUrl: controller.latestComment!.profilePicture,
                        size: 32,
                        fallbackText:
                            controller.latestComment!.commentByUsername,
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
                        color: Color(0xFFFF6B35),
                      ),
                    ),
                  ],
                ] else ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Be the first to comment!',
                    style: TextStyle(fontSize: 14, color: Color(0xFF6B6B6B)),
                  ),
                ],
              ],
            ),
          ),
        );
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

/// 3️⃣ Primary Bottom Sheet
class CommentsBottomSheet extends StatefulWidget {
  final VideoCommentsController controller;

  const CommentsBottomSheet({super.key, required this.controller});

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
                          color: Color(0xFFFF6B35),
                        ),
                      );
                    }

                    if (widget.controller.state == CommentsState.error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.controller.errorMessage ??
                                    'Failed to load comments',
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
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No comments yet',
                              style: TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Be the first to comment!',
                              style: TextStyle(
                                color: Color(0xFF6B6B6B),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: widget.controller.comments.length,
                      itemBuilder: (context, index) {
                        return CommentTile(
                          comment: widget.controller.comments[index],
                          controller: widget.controller,
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
            builder: (context, _) => Text(
              '${widget.controller.totalCommentsCount} Comments',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
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

  const CommentTile({
    super.key,
    required this.comment,
    required this.controller,
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
                      color: const Color(0xFFFF6B35),
                      size: 20,
                    ),
                    Text(
                      _showReplies
                          ? 'Hide ${widget.comment.totalReplies} replies'
                          : '${widget.comment.totalReplies} reply${widget.comment.totalReplies == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFFF6B35),
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
                            imageUrl: context
                                .watch<AuthRepository>()
                                .currentUser
                                ?.profilePicture,
                            size: 28,
                            fallbackText: context
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
                                      0xFFFF6B35,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: const Color(
                                      0xFFFF6B35,
                                    ).withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFFF6B35),
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
                              color: Color(0xFFFF6B35),
                              size: 20,
                            ),
                            onPressed: () {
                              if (_replyController.text.trim().isNotEmpty) {
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
                    imageUrl: ImageUtils.getProfileImageUrl(
                      context
                          .watch<AuthRepository>()
                          .currentUser
                          ?.profilePicture,
                    ),
                    size: 28,
                    fallbackText: context
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
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: const Color(0xFFFF6B35).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: const BorderSide(
                            color: Color(0xFFFF6B35),
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
                      color: Color(0xFFFF6B35),
                      size: 20,
                    ),
                    onPressed: () {
                      if (_replyController.text.trim().isNotEmpty) {
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
    final user = context.read<AuthRepository>().currentUser;
    try {
      await widget.controller.postReply(
        widget.comment.commentId,
        text,
        user?.username ?? 'Anonymous',
        user?.profilePicture,
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

  const CommentComposer({
    super.key,
    required this.controller,
    required this.focusNode,
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
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final replyTarget = widget.controller.replyTarget;
        final isReplying = replyTarget != null;

        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom:
                8 +
                math.max(
                  MediaQuery.of(context).viewInsets.bottom,
                  MediaQuery.of(context).padding.bottom,
                ),
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
                        onTap: () => widget.controller.setReplyTarget(null),
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
                    imageUrl: context
                        .watch<AuthRepository>()
                        .currentUser
                        ?.profilePicture,
                    size: 32,
                    fallbackText: context
                        .watch<AuthRepository>()
                        .currentUser
                        ?.username,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _textController.text.trim().isNotEmpty
                              ? const Color(0xFFFF6B35).withOpacity(0.5)
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
                          ? const Color(0xFFFF6B35)
                          : Colors.grey[300],
                      size: 20,
                    ),
                    onPressed: _canSend
                        ? () {
                            final user = context
                                .read<AuthRepository>()
                                .currentUser;
                            final text = _textController.text.trim();
                            if (text.isEmpty) return;

                            if (isReplying) {
                              widget.controller.postReply(
                                replyTarget.commentId,
                                text,
                                user?.username ?? 'Anonymous',
                                user?.profilePicture,
                              );
                            } else {
                              widget.controller.postComment(
                                text,
                                user?.username ?? 'Anonymous',
                                user?.profilePicture,
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
