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
  });

  final String commentId;
  final String commentedBy;
  final String commentedTo;
  final DateTime commentedAt;
  final String comment;
  final int totalReplies;
  final List<ReplyModel> replies;
  final String? commentByUsername;

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    return CommentModel(
      commentId: json['comment_id'] as String,
      commentedBy: json['commented_by'] as String,
      commentedTo: json['commented_to'] as String,
      commentedAt: DateTime.parse(json['commented_at'] as String),
      comment: json['comment'] as String,
      totalReplies: json['total_replies'] as int? ?? 0,
      replies: const [], // Will be loaded separately
      commentByUsername: json['comment_by_username'] as String?,
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
    );
  }
}

class ReplyModel {
  ReplyModel({
    required this.replyId,
    required this.repliedBy,
    required this.repliedTo,
    required this.repliedAt,
    required this.reply,
  });

  final String replyId;
  final String repliedBy;
  final String repliedTo;
  final DateTime repliedAt;
  final String reply;

  factory ReplyModel.fromJson(Map<String, dynamic> json) {
    return ReplyModel(
      replyId: json['reply_id'] as String,
      repliedBy: json['replied_by'] as String,
      repliedTo: json['replied_to'] as String,
      repliedAt: DateTime.parse(json['replied_at'] as String),
      reply: json['reply'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reply_id': replyId,
      'replied_by': repliedBy,
      'replied_to': repliedTo,
      'replied_at': repliedAt.toIso8601String(),
      'reply': reply,
    };
  }
}
