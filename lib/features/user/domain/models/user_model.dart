class UserModel {
  final String username;
  final String name;
  final String? email;
  final String? bio;
  final String? avatarUrl;
  final String? docId;
  final String? uid;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? role;
  final String? profilePicture;
  final String? coverUrl;
  final int followers;
  final int following;
  final int totalStreams;
  final int totalVideos;
  final UserStatus? status;
  final bool? isFollowing; // Whether current user is following this user

  UserModel({
    required this.username,
    required this.name,
    this.email,
    this.bio,
    this.avatarUrl,
    this.docId,
    this.uid,
    this.createdAt,
    this.updatedAt,
    this.role,
    this.profilePicture,
    this.coverUrl,
    this.followers = 0,
    this.following = 0,
    this.totalStreams = 0,
    this.totalVideos = 0,
    this.status,
    this.isFollowing,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle nested response structure: {"success": true, "user": {...}}
    final userData = json['user'] as Map<String, dynamic>? ?? json;

    // Parse live-stream status when API returns an object; ignore account
    // status strings such as "ACTIVE".
    UserStatus? status;
    final rawStatus = userData['status'];
    if (rawStatus is Map<String, dynamic>) {
      status = UserStatus(
        isLive: rawStatus['is_live'] as bool? ?? false,
        sessionId: rawStatus['session_id'] as String? ?? '',
      );
    }

    // Parse dates - handle both formats and invalid dates
    DateTime? parseDate(String? dateStr) {
      if (dateStr == null || dateStr.isEmpty) return null;
      final parsed = DateTime.tryParse(dateStr);
      // Check if date is valid (not the zero date)
      if (parsed != null && parsed.year > 1900) return parsed;
      return null;
    }

    // Helper to filter out invalid placeholder URLs
    String? filterInvalidUrl(String? url) {
      if (url == null || url.isEmpty) return null;
      final invalidUrls = [
        'https://example.com/newpic.jpg',
        'http://example.com/newpic.jpg',
        'example.com/newpic.jpg',
      ];
      if (invalidUrls.contains(url.toLowerCase())) return null;
      return url;
    }

    final rawAvatarUrl =
        userData['avatarUrl'] as String? ??
        userData['profile_picture'] as String?;
    final rawProfilePicture = userData['profile_picture'] as String?;

    return UserModel(
      username: userData['username'] as String? ?? '',
      name: userData['name'] as String? ?? '',
      email: userData['email'] as String?,
      bio: userData['bio'] as String?,
      // Support both avatarUrl and profile_picture, but filter invalid URLs
      avatarUrl: filterInvalidUrl(rawAvatarUrl),
      profilePicture: filterInvalidUrl(rawProfilePicture),
      coverUrl: filterInvalidUrl(
        userData['cover_url'] as String? ??
            userData['coverUrl'] as String? ??
            userData['profile_cover'] as String?,
      ),
      docId: userData['DocID'] as String?,
      // Support both UID and uid
      uid: userData['uid'] as String? ?? userData['UID'] as String?,
      createdAt:
          parseDate(userData['created_at'] as String?) ??
          parseDate(userData['createdAt'] as String?),
      updatedAt:
          parseDate(userData['updated_at'] as String?) ??
          parseDate(userData['updatedAt'] as String?),
      role: userData['role'] as String?,
      followers: (userData['followers'] as num?)?.toInt() ?? 0,
      following: (userData['following'] as num?)?.toInt() ?? 0,
      totalStreams: (userData['total_streams'] as num?)?.toInt() ?? 0,
      totalVideos: (userData['total_videos'] as num?)?.toInt() ?? 0,
      status: status,
      isFollowing: userData['is_following'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'name': name,
      if (email != null) 'email': email,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (profilePicture != null) 'profile_picture': profilePicture,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (docId != null) 'DocID': docId,
      if (uid != null) 'uid': uid,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (role != null) 'role': role,
      'followers': followers,
      'following': following,
      'total_streams': totalStreams,
      'total_videos': totalVideos,
      if (status != null)
        'status': {'is_live': status!.isLive, 'session_id': status!.sessionId},
      if (isFollowing != null) 'is_following': isFollowing,
    };
  }

  UserModel copyWith({
    String? username,
    String? name,
    String? email,
    String? bio,
    String? avatarUrl,
    String? docId,
    String? uid,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? role,
    String? profilePicture,
    String? coverUrl,
    int? followers,
    int? following,
    int? totalStreams,
    int? totalVideos,
    UserStatus? status,
    bool? isFollowing,
  }) {
    return UserModel(
      username: username ?? this.username,
      name: name ?? this.name,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      docId: docId ?? this.docId,
      uid: uid ?? this.uid,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
      profilePicture: profilePicture ?? this.profilePicture,
      coverUrl: coverUrl ?? this.coverUrl,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalStreams: totalStreams ?? this.totalStreams,
      totalVideos: totalVideos ?? this.totalVideos,
      status: status ?? this.status,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class UserStatus {
  final bool isLive;
  final String sessionId;

  UserStatus({required this.isLive, required this.sessionId});
}
