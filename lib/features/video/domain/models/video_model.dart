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
    this.status,
    this.originalProfile,
    this.profiles = const [],
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
  final String? status; // 'temp' for processing videos
  final String? originalProfile; // e.g., '720p'
  final List<String> profiles; // e.g., ['240p', '480p']

  factory VideoModel.fromJson(Map<String, dynamic> json) {
    // Some API endpoints return user info in a nested 'user' object
    final userData = json['user'] as Map<String, dynamic>?;

    return VideoModel(
      videoId: json['video_id'] as String? ?? json['id'] as String? ?? '',
      videoUrl: json['video_url'] as String? ?? json['url'] as String? ?? '',
      videoThumbnail:
          json['video_thumbnail'] as String? ??
          json['thumbnail'] as String? ??
          json['thumbnail_url'] as String? ??
          '',
      videoTitle:
          json['video_title'] as String? ?? json['title'] as String? ?? '',
      videoDescription:
          json['video_description'] as String? ??
          json['description'] as String? ??
          '',
      videoTags:
          (json['video_tags'] as List<dynamic>? ??
                  json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      videoViews: (json['video_views'] as num? ?? json['views'] as num? ?? 0)
          .toInt(),
      videoUpvotes:
          (json['video_upvotes'] as num? ?? json['upvotes'] as num? ?? 0)
              .toInt(),
      videoDownvotes:
          (json['video_downvotes'] as num? ?? json['downvotes'] as num? ?? 0)
              .toInt(),
      videoComments:
          (json['video_comments'] as num? ?? json['comments'] as num? ?? 0)
              .toInt(),
      userUid:
          (json['user_uid'] as String? ??
          json['uid'] as String? ??
          userData?['uid'] as String? ??
          ''),
      userUsername:
          json['user_username'] as String? ??
          json['username'] as String? ??
          userData?['username'] as String? ??
          '',
      createdAt: DateTime.parse(
        json['created_at'] as String? ??
            json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ??
            json['updatedAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
      userVoteStatus: json['user_vote_status'] as String?,
      profilePicture:
          json['profile_picture'] as String? ??
          json['profilePicture'] as String? ??
          json['avatar_url'] as String? ??
          json['avatarUrl'] as String? ??
          userData?['profile_picture'] as String? ??
          userData?['avatar_url'] as String?,
      status: json['status'] as String?,
      originalProfile: json['original_profile'] as String?,
      profiles: (json['profiles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
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
      if (status != null) 'status': status,
      if (originalProfile != null) 'original_profile': originalProfile,
      'profiles': profiles,
    };
  }

  /// Creates a copy of this VideoModel with the given fields replaced with new values
  VideoModel copyWith({
    String? videoId,
    String? videoUrl,
    String? videoThumbnail,
    String? videoTitle,
    String? videoDescription,
    List<String>? videoTags,
    int? videoViews,
    int? videoUpvotes,
    int? videoDownvotes,
    int? videoComments,
    String? userUid,
    String? userUsername,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userVoteStatus,
    String? profilePicture,
    String? status,
    String? originalProfile,
    List<String>? profiles,
  }) {
    return VideoModel(
      videoId: videoId ?? this.videoId,
      videoUrl: videoUrl ?? this.videoUrl,
      videoThumbnail: videoThumbnail ?? this.videoThumbnail,
      videoTitle: videoTitle ?? this.videoTitle,
      videoDescription: videoDescription ?? this.videoDescription,
      videoTags: videoTags ?? this.videoTags,
      videoViews: videoViews ?? this.videoViews,
      videoUpvotes: videoUpvotes ?? this.videoUpvotes,
      videoDownvotes: videoDownvotes ?? this.videoDownvotes,
      videoComments: videoComments ?? this.videoComments,
      userUid: userUid ?? this.userUid,
      userUsername: userUsername ?? this.userUsername,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userVoteStatus: userVoteStatus ?? this.userVoteStatus,
      profilePicture: profilePicture ?? this.profilePicture,
      status: status ?? this.status,
      originalProfile: originalProfile ?? this.originalProfile,
      profiles: profiles ?? this.profiles,
    );
  }
}
