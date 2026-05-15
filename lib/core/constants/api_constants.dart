class ApiConstants {
  static const String baseUrl = 'https://api.dev.hiffi.com';
//   static const String baseUrl = 'https://api.hiffi.com';
  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authVerify = '/auth/verify';
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

  // Search endpoints
  static String searchUsers(String query, {int page = 1, int limit = 50}) =>
      '/search/users/${Uri.encodeComponent(query)}?page=$page&limit=$limit';
  static String searchVideos(String query, {int page = 1, int limit = 100}) =>
      '/search/videos/${Uri.encodeComponent(query)}?page=$page&limit=$limit';

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
}
