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
  final int followers;
  final int following;
  final int totalStreams;
  final int totalVideos;
  final UserStatus? status;

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
    this.followers = 0,
    this.following = 0,
    this.totalStreams = 0,
    this.totalVideos = 0,
    this.status,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle nested response structure: {"success": true, "user": {...}}
    final userData = json['user'] as Map<String, dynamic>? ?? json;

    // Parse status if present
    UserStatus? status;
    if (userData['status'] != null) {
      final statusData = userData['status'] as Map<String, dynamic>;
      status = UserStatus(
        isLive: statusData['is_live'] as bool? ?? false,
        sessionId: statusData['session_id'] as String? ?? '',
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

    return UserModel(
      username: userData['username'] as String? ?? '',
      name: userData['name'] as String? ?? '',
      email: userData['email'] as String?,
      bio: userData['bio'] as String?,
      // Support both avatarUrl and profile_picture
      avatarUrl:
          userData['avatarUrl'] as String? ??
          userData['profile_picture'] as String?,
      profilePicture: userData['profile_picture'] as String?,
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
    int? followers,
    int? following,
    int? totalStreams,
    int? totalVideos,
    UserStatus? status,
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
      followers: followers ?? this.followers,
      following: following ?? this.following,
      totalStreams: totalStreams ?? this.totalStreams,
      totalVideos: totalVideos ?? this.totalVideos,
      status: status ?? this.status,
    );
  }
}

class UserStatus {
  final bool isLive;
  final String sessionId;

  UserStatus({required this.isLive, required this.sessionId});
}
