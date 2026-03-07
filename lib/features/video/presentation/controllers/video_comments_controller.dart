import 'package:flutter/material.dart';
import 'package:hiffi/features/video/domain/models/comment_model.dart';
import 'package:hiffi/features/video/domain/repositories/video_repository.dart';
import 'package:hiffi/features/user/data/user_repository.dart';

/// State of the comments section.
enum CommentsState { initial, loading, loaded, error }

/// Controller to handle comments logic independently of the video player.
class VideoCommentsController extends ChangeNotifier {
  final VideoRepository _repository;
  final String videoId;
  final UserRepository? _userRepository;

  VideoCommentsController({
    required VideoRepository repository,
    required this.videoId,
    UserRepository? userRepository,
  }) : _repository = repository,
       _userRepository = userRepository;

  List<CommentModel> _comments = [];
  int _totalCommentsCount = 0;
  CommentsState _state = CommentsState.initial;
  String? _errorMessage;
  bool _shouldFocusInput = false;
  CommentModel? _replyTarget;

  List<CommentModel> get comments => _comments;
  int get totalCommentsCount => _totalCommentsCount;
  CommentsState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get shouldFocusInput => _shouldFocusInput;
  CommentModel? get replyTarget => _replyTarget;

  CommentModel? get latestComment =>
      _comments.isNotEmpty ? _comments.first : null;

  /// Sets whether the input should be focused when the sheet opens.
  void setShouldFocus(bool value) {
    _shouldFocusInput = value;
    notifyListeners();
  }

  /// Sets the comment to which the user is replying.
  void setReplyTarget(CommentModel? comment) {
    _replyTarget = comment;
    notifyListeners();
  }

  /// Fetches the latest comment only for the inline preview.
  /// This is "lightweight data" fetching.
  Future<void> fetchLatestComment() async {
    try {
      final response = await _repository.getComments(
        videoId,
        page: 1,
        limit: 1,
      );
      debugPrint(
        'VideoCommentsController: Received latest comment preview from backend',
      );
      _comments = response.comments;
      _totalCommentsCount = response.count;

      // Enrich with profile picture if available
      if (_userRepository != null && _comments.isNotEmpty) {
        final comment = _comments.first;
        final username = comment.commentByUsername;
        if (username != null &&
            username.isNotEmpty &&
            (comment.profilePicture == null ||
                comment.profilePicture!.isEmpty)) {
          try {
            final user = await _userRepository.getUser(username);
            _comments = [comment.copyWith(profilePicture: user.profilePicture)];
          } catch (e) {
            debugPrint('Error fetching profile for latest comment: $e');
          }
        }
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching latest comment: $e');
    }
  }

  /// Fetches all comments for the bottom sheet.
  Future<void> fetchAllComments() async {
    if (_state == CommentsState.loading) return;

    _state = CommentsState.loading;
    notifyListeners();

    try {
      final response = await _repository.getComments(
        videoId,
        page: 1,
        limit: 50,
      );
      debugPrint(
        'VideoCommentsController: Received ${response.comments.length} comments from backend',
      );
      _comments = response.comments;
      _totalCommentsCount = response.count;

      // Enrich comments with profile pictures if userRepository is available
      if (_userRepository != null) {
        await _enrichCommentsWithProfilePictures();
      }

      _state = CommentsState.loaded;
    } catch (e) {
      _state = CommentsState.error;
      _errorMessage = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Enriches comments with profile pictures by fetching user data.
  /// This is done asynchronously and updates the UI incrementally.
  Future<void> _enrichCommentsWithProfilePictures() async {
    if (_userRepository == null) return;

    // Get unique usernames from comments that don't have profile pictures
    final usernamesToFetch = _comments
        .where(
          (c) =>
              c.commentByUsername != null &&
              c.commentByUsername!.isNotEmpty &&
              (c.profilePicture == null || c.profilePicture!.isEmpty),
        )
        .map((c) => c.commentByUsername!)
        .toSet()
        .toList();

    if (usernamesToFetch.isEmpty) return;

    debugPrint(
      'VideoCommentsController: Enriching ${usernamesToFetch.length} comments with profile pictures',
    );

    // Fetch user data for each unique username
    final profilePictureMap = <String, String?>{};
    for (final username in usernamesToFetch) {
      try {
        final user = await _userRepository.getUser(username);
        profilePictureMap[username] = user.profilePicture;
        debugPrint(
          'VideoCommentsController: Fetched profile picture for $username: ${user.profilePicture}',
        );
      } catch (e) {
        debugPrint(
          'VideoCommentsController: Failed to fetch profile for $username: $e',
        );
        profilePictureMap[username] = null;
      }
    }

    // Update comments with profile pictures
    _comments = _comments.map((comment) {
      if (comment.commentByUsername != null &&
          comment.commentByUsername!.isNotEmpty) {
        final profilePic = profilePictureMap[comment.commentByUsername!];
        if (profilePic != null &&
            profilePic.isNotEmpty &&
            (comment.profilePicture == null ||
                comment.profilePicture!.isEmpty)) {
          return comment.copyWith(profilePicture: profilePic);
        }
      }
      return comment;
    }).toList();

    notifyListeners();
  }

  /// Optimistic update for posting a comment.
  Future<void> postComment({
    required String text,
    required String username,
    required String uid,
    String? profilePicture,
  }) async {
    // Trim trailing spaces
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw Exception('Comment cannot be empty');
    }

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final newComment = CommentModel(
      commentId: tempId,
      commentedBy: uid,
      commentedTo: videoId,
      commentedAt: DateTime.now(),
      comment: trimmedText,
      totalReplies: 0,
      commentByUsername: username,
      profilePicture: profilePicture,
    );

    // Optimistic insert
    _comments.insert(0, newComment);
    _totalCommentsCount++;
    notifyListeners();

    try {
      await _repository.postComment(videoId, trimmedText);
      // Refresh to get the real ID and server state
      await fetchAllComments();
    } catch (e) {
      // Rollback on error
      _comments.removeWhere((c) => c.commentId == tempId);
      _totalCommentsCount--;
      notifyListeners();
      rethrow;
    }
  }

  /// Toggle replies for a specific comment.
  /// In a real app, this would fetch replies from the API.
  Future<void> fetchReplies(String commentId) async {
    final index = _comments.indexWhere((c) => c.commentId == commentId);
    if (index == -1) return;

    try {
      final response = await _repository.getReplies(
        commentId,
        page: 1,
        limit: 50,
      );
      debugPrint(
        'VideoCommentsController: Received ${response.replies.length} replies for comment $commentId from backend',
      );

      // Enrich replies with profile pictures if available
      List<ReplyModel> enrichedReplies = response.replies;
      if (_userRepository != null) {
        enrichedReplies = await _enrichRepliesWithProfilePictures(
          response.replies,
        );
      }

      _comments[index] = _comments[index].copyWith(replies: enrichedReplies);
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching replies: $e');
    }
  }

  /// Deletes a comment.
  Future<void> deleteComment(String commentId) async {
    final originalComments = List<CommentModel>.from(_comments);
    final originalCount = _totalCommentsCount;

    // Optimistic remove
    _comments.removeWhere((c) => c.commentId == commentId);
    _totalCommentsCount--;
    notifyListeners();

    try {
      await _repository.deleteComment(commentId);
    } catch (e) {
      // Rollback on error
      _comments = originalComments;
      _totalCommentsCount = originalCount;
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes a reply.
  Future<void> deleteReply(String commentId, String replyId) async {
    final commentIndex = _comments.indexWhere((c) => c.commentId == commentId);
    if (commentIndex == -1) return;

    final comment = _comments[commentIndex];
    final originalReplies = List<ReplyModel>.from(comment.replies);
    final originalTotalReplies = comment.totalReplies;

    // Optimistic remove from local state
    final updatedReplies = comment.replies
        .where((r) => r.replyId != replyId)
        .toList();
    _comments[commentIndex] = comment.copyWith(
      replies: updatedReplies,
      totalReplies: comment.totalReplies - 1,
    );
    notifyListeners();

    try {
      await _repository.deleteReply(replyId);
    } catch (e) {
      // Rollback on error
      _comments[commentIndex] = comment.copyWith(
        replies: originalReplies,
        totalReplies: originalTotalReplies,
      );
      notifyListeners();
      rethrow;
    }
  }

  /// Post a reply to a comment.
  Future<void> postReply({
    required String commentId,
    required String text,
    required String username,
    required String uid,
    String? profilePicture,
  }) async {
    // Trim trailing spaces
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw Exception('Reply cannot be empty');
    }

    final commentIndex = _comments.indexWhere((c) => c.commentId == commentId);
    if (commentIndex == -1) return;

    final tempReplyId = DateTime.now().millisecondsSinceEpoch.toString();
    final newReply = ReplyModel(
      replyId: tempReplyId,
      repliedBy: uid,
      repliedTo: commentId,
      repliedAt: DateTime.now(),
      reply: trimmedText,
      replyByUsername: username,
      profilePicture: profilePicture,
    );

    // Optimistic insert
    final comment = _comments[commentIndex];
    final updatedReplies = [...comment.replies, newReply];
    _comments[commentIndex] = comment.copyWith(
      replies: updatedReplies,
      totalReplies: comment.totalReplies + 1,
    );
    notifyListeners();

    try {
      await _repository.postReply(commentId, trimmedText);
      // Refresh replies to get the real ID and server state
      await fetchReplies(commentId);
    } catch (e) {
      // Rollback on error
      final updatedComment = _comments[commentIndex];
      final rolledBackReplies = updatedComment.replies
          .where((r) => r.replyId != tempReplyId)
          .toList();
      _comments[commentIndex] = updatedComment.copyWith(
        replies: rolledBackReplies,
        totalReplies: updatedComment.totalReplies - 1,
      );
      notifyListeners();
      rethrow;
    }
  }

  /// Enriches replies with profile pictures by fetching user data.
  Future<List<ReplyModel>> _enrichRepliesWithProfilePictures(
    List<ReplyModel> replies,
  ) async {
    if (_userRepository == null) return replies;

    final enrichedReplies = <ReplyModel>[];

    for (final reply in replies) {
      if (reply.replyByUsername != null &&
          reply.replyByUsername!.isNotEmpty &&
          (reply.profilePicture == null || reply.profilePicture!.isEmpty)) {
        try {
          final username = reply.replyByUsername!;
          final user = await _userRepository.getUser(username);
          enrichedReplies.add(
            ReplyModel(
              replyId: reply.replyId,
              repliedBy: reply.repliedBy,
              repliedTo: reply.repliedTo,
              repliedAt: reply.repliedAt,
              reply: reply.reply,
              replyByUsername: reply.replyByUsername,
              profilePicture: user.profilePicture,
            ),
          );
        } catch (e) {
          debugPrint(
            'Error fetching profile for reply by ${reply.replyByUsername}: $e',
          );
          enrichedReplies.add(reply);
        }
      } else {
        enrichedReplies.add(reply);
      }
    }

    return enrichedReplies;
  }
}
