class ApiConstants {
  static const String baseUrl = 'https://api.dev.hiffi.com';
    // static const String baseUrl = 'https://api.hiffi.com';
  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authResetPasswordRequest = '/auth/reset-password/request';
  static const String authResetPasswordVerify = '/auth/reset-password/verify';

  // User endpoints
  static const String userAvailability = '/users/availability';
  static const String updateUser =
      '/users/self'; // Update current user (identified by JWT token)
  static const String getCurrentUser =
      '/users/self'; // Deprecated, but still works
  static String getUser(String username) => '/users/$username';
  static String deleteUser(String username) => '/users/$username';
  static const String profilePhotoUpload = '/users/profile-photo/upload';
  static const String verifyUserUpdate = '/users/self/verify-update';
  static const String requestCreatorUpgrade =
      '/users/self/request-creator-upgrade';
  static const String verifyCreatorUpgrade =
      '/users/self/verify-creator-upgrade';

  // Video endpoints
  static const String uploadVideo = '/videos/upload';
  static String uploadVideoAck(String bridgeId) =>
      '/videos/upload/ack/$bridgeId';
  static const String videoList = '/videos/list';
  static const String videoListSelf = '/videos/list/self';
  static const String videoListFollowing = '/videos/list/following';
  static const String videoListLiked = '/videos/list/liked';
  static const String videoListHistory = '/videos/list/history';
  static String getVideo(String videoId) => '/videos/$videoId';
  static String deleteVideo(String videoId) => '/videos/$videoId';
  static String listVideosByUsername(String username) =>
      '/videos/list/$username';

  // Social endpoints
  static String upvoteVideo(String videoId) => '/videos/upvote/$videoId';
  static String downvoteVideo(String videoId) => '/videos/downvote/$videoId';
  static String upvoteVideoLegacy(String videoId) =>
      '/social/videos/upvote/$videoId';
  static String downvoteVideoLegacy(String videoId) =>
      '/social/videos/downvote/$videoId';
  static String postComment(String videoId) =>
      '/social/videos/comment/$videoId';
  static String deleteComment(String commentId) =>
      '/social/videos/comment/$commentId';
  static String getComments(String videoId) =>
      '/social/videos/comments/$videoId';
  static String postReply(String commentId) =>
      '/social/videos/reply/$commentId';
  static String deleteReply(String replyId) => '/social/videos/reply/$replyId';
  static String getReplies(String commentId) =>
      '/social/videos/replies/$commentId';
  static String followUser(String username) => '/social/users/follow/$username';
  static String unfollowUser(String username) =>
      '/social/users/unfollow/$username';

  // Search endpoints (public, limit/offset pagination)
  static String searchUsers(
    String query, {
    int limit = 20,
    int offset = 0,
  }) {
    final cappedLimit = limit.clamp(1, 100);
    return '/search/users/${Uri.encodeComponent(query)}'
        '?limit=$cappedLimit&offset=$offset';
  }

  static String searchVideos(
    String query, {
    int limit = 20,
    int offset = 0,
  }) {
    final cappedLimit = limit.clamp(1, 100);
    return '/search/videos/${Uri.encodeComponent(query)}'
        '?limit=$cappedLimit&offset=$offset';
  }

  // Flags / moderation endpoints
  static const String flagsConfig = '/flags/config';
  static const String createFlag = '/flags';
  static const String flagsSelf = '/flags/self';
  static String flagByReference(String referenceId) =>
      '/flags/ref/$referenceId';

  /// Watch-time / playback signals (Bearer auth).
  static const String signalsWatchhours = '/signals/watchhours';

  // Playlist endpoints
  static const String playlistCuratedList = '/playlists/curated';
  static String playlistCuratedDetail(String playlistId) =>
      '/playlists/curated/$playlistId';
  static const String playlistListSelf = '/playlists/list/self';
  static const String playlistCreate = '/playlists/create';
  static String playlistDetail(String playlistId) => '/playlists/$playlistId';
  static String playlistAddItem(String playlistId) =>
      '/playlists/$playlistId/items/add';
  static String playlistRemoveItem(String playlistId, String videoId) =>
      '/playlists/$playlistId/items/$videoId';
  static String playlistReorderItems(String playlistId) =>
      '/playlists/$playlistId/items/reorder';

  /// Public mood mix playlists (`GET /playlist/mood/{vibe}`).
  static String moodPlaylist(
    String vibe, {
    int limit = 20,
    int offset = 0,
  }) {
    final cappedLimit = limit.clamp(1, 100);
    return '/playlist/mood/${Uri.encodeComponent(vibe)}'
        '?limit=$cappedLimit&offset=$offset';
  }

  // Migration requests (YouTube content migration)
  static const String migrationRequestsConfig = '/migration-requests/config';
  static const String migrationRequests = '/migration-requests';
  static const String migrationRequestsStatus = '/migration-requests/status';
}
