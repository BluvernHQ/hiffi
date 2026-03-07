import 'package:flutter/foundation.dart';

class CommentModel {
  CommentModel({
    required this.commentId,
    required this.commentedBy,
    required this.commentedTo,
    required this.commentedAt,
    required this.comment,
    required this.totalReplies,
    this.replies = const [],
    this.commentByUsername,
    this.profilePicture,
  });

  final String commentId;
  final String commentedBy;
  final String commentedTo;
  final DateTime commentedAt;
  final String comment;
  final int totalReplies;
  final List<ReplyModel> replies;
  final String? commentByUsername;
  final String? profilePicture;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final id = json['comment_id'] as String;
    debugPrint('CommentModel: Parsed comment_id: $id from backend');

    // Try to get profile picture from various possible fields
    final profilePic =
        json['profile_picture'] as String? ??
        json['profilePicture'] as String? ??
        json['avatar_url'] as String? ??
        json['avatarUrl'] as String?;

    // Debug logging to see what we're getting from API
    final username = json['comment_by_username'] as String?;
    if (username != null) {
      debugPrint(
        'CommentModel.fromJson: Username: $username, ProfilePicture: "$profilePic" (keys: ${json.keys.where((k) => k.toLowerCase().contains('profile') || k.toLowerCase().contains('avatar')).join(", ")})',
      );
    }

    return CommentModel(
      commentId: json['comment_id'] as String,
      commentedBy: json['commented_by'] as String,
      commentedTo: json['commented_to'] as String,
      commentedAt: DateTime.parse(json['commented_at'] as String),
      comment: json['comment'] as String,
      totalReplies: json['total_replies'] as int? ?? 0,
      replies: const [], // Will be loaded separately
      commentByUsername: username,
      profilePicture: profilePic,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'comment_id': commentId,
      'commented_by': commentedBy,
      'commented_to': commentedTo,
      'commented_at': commentedAt.toIso8601String(),
      'comment': comment,
      'total_replies': totalReplies,
      if (commentByUsername != null) 'comment_by_username': commentByUsername,
      if (profilePicture != null) 'profile_picture': profilePicture,
    };
  }

  CommentModel copyWith({
    String? commentId,
    String? commentedBy,
    String? commentedTo,
    DateTime? commentedAt,
    String? comment,
    int? totalReplies,
    List<ReplyModel>? replies,
    String? commentByUsername,
    String? profilePicture,
  }) {
    return CommentModel(
      commentId: commentId ?? this.commentId,
      commentedBy: commentedBy ?? this.commentedBy,
      commentedTo: commentedTo ?? this.commentedTo,
      commentedAt: commentedAt ?? this.commentedAt,
      comment: comment ?? this.comment,
      totalReplies: totalReplies ?? this.totalReplies,
      replies: replies ?? this.replies,
      commentByUsername: commentByUsername ?? this.commentByUsername,
      profilePicture: profilePicture ?? this.profilePicture,
    );
  }
}

class CommentsResponse {
  CommentsResponse({required this.comments, required this.count});

  final List<CommentModel> comments;
  final int count;

  factory CommentsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data != null) {
      final commentsJson = data['comments'] as List<dynamic>? ?? [];
      final comments = commentsJson
          .map(
            (commentJson) =>
                CommentModel.fromJson(commentJson as Map<String, dynamic>),
          )
          .toList();
      final count = data['count'] as int? ?? comments.length;
      return CommentsResponse(comments: comments, count: count);
    }

    // Fallback for old format
    final commentsJson = json['comments'] as List<dynamic>? ?? [];
    final comments = commentsJson
        .map(
          (commentJson) =>
              CommentModel.fromJson(commentJson as Map<String, dynamic>),
        )
        .toList();
    return CommentsResponse(comments: comments, count: comments.length);
  }
}

class RepliesResponse {
  RepliesResponse({required this.replies, required this.count});

  final List<ReplyModel> replies;
  final int count;

  factory RepliesResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    if (data != null) {
      final repliesJson = data['replies'] as List<dynamic>? ?? [];
      final replies = repliesJson
          .map(
            (replyJson) =>
                ReplyModel.fromJson(replyJson as Map<String, dynamic>),
          )
          .toList();
      final count = data['count'] as int? ?? replies.length;
      return RepliesResponse(replies: replies, count: count);
    }

    // Fallback for old format
    final repliesJson = json['replies'] as List<dynamic>? ?? [];
    final replies = repliesJson
        .map(
          (replyJson) => ReplyModel.fromJson(replyJson as Map<String, dynamic>),
        )
        .toList();
    return RepliesResponse(replies: replies, count: replies.length);
  }
}

class ReplyModel {
  ReplyModel({
    required this.replyId,
    required this.repliedBy,
    required this.repliedTo,
    required this.repliedAt,
    required this.reply,
    this.replyByUsername,
    this.profilePicture,
  });

  final String replyId;
  final String repliedBy;
  final String repliedTo;
  final DateTime repliedAt;
  final String reply;
  final String? replyByUsername; // Username of the user who replied
  final String? profilePicture;

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    final id = json['reply_id'] as String;
    debugPrint('ReplyModel: Parsed reply_id: $id from backend');

    return ReplyModel(
      replyId: json['reply_id'] as String,
      repliedBy: json['replied_by'] as String,
      repliedTo: json['replied_to'] as String,
      repliedAt: DateTime.parse(json['replied_at'] as String),
      reply: json['reply'] as String,
      replyByUsername: json['reply_by_username'] as String?,
      profilePicture:
          json['profile_picture'] as String? ??
          json['profilePicture'] as String? ??
          json['avatar_url'] as String? ??
          json['avatarUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reply_id': replyId,
      'replied_by': repliedBy,
      'replied_to': repliedTo,
      'replied_at': repliedAt.toIso8601String(),
      'reply': reply,
      if (replyByUsername != null) 'reply_by_username': replyByUsername,
      if (profilePicture != null) 'profile_picture': profilePicture,
    };
  }
}
