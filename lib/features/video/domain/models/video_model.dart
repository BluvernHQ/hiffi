class VideoModel {
  VideoModel({
    required this.videoId,
    required this.videoUrl,
    required this.videoThumbnail,
    required this.videoTitle,
    required this.videoDescription,
    required this.videoTags,
    required this.videoViews,
    required this.videoUpvotes,
    required this.videoDownvotes,
    required this.videoComments,
    required this.userUid,
    required this.userUsername,
    required this.createdAt,
    required this.updatedAt,
    this.userVoteStatus,
    this.profilePicture,
  });

  final String videoId;
  final String videoUrl;
  final String videoThumbnail;
  final String videoTitle;
  final String videoDescription;
  final List<String> videoTags;
  final int videoViews;
  final int videoUpvotes;
  final int videoDownvotes;
  final int videoComments;
  final String userUid;
  final String userUsername;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? userVoteStatus; // 'upvoted', 'downvoted', or null
  final String? profilePicture; // Profile picture URL path from API

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      videoId: json['video_id'] as String,
      videoUrl: json['video_url'] as String,
      videoThumbnail: json['video_thumbnail'] as String,
      videoTitle: json['video_title'] as String,
      videoDescription: json['video_description'] as String,
      videoTags:
          (json['video_tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videoViews: json['video_views'] as int? ?? 0,
      videoUpvotes: json['video_upvotes'] as int? ?? 0,
      videoDownvotes: json['video_downvotes'] as int? ?? 0,
      videoComments: json['video_comments'] as int? ?? 0,
      userUid: json['user_uid'] as String,
      userUsername: json['user_username'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userVoteStatus: json['user_vote_status'] as String?,
      profilePicture: json['profile_picture'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'video_id': videoId,
      'video_url': videoUrl,
      'video_thumbnail': videoThumbnail,
      'video_title': videoTitle,
      'video_description': videoDescription,
      'video_tags': videoTags,
      'video_views': videoViews,
      'video_upvotes': videoUpvotes,
      'video_downvotes': videoDownvotes,
      'video_comments': videoComments,
      'user_uid': userUid,
      'user_username': userUsername,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (userVoteStatus != null) 'user_vote_status': userVoteStatus,
      if (profilePicture != null) 'profile_picture': profilePicture,
    };
  }
}
