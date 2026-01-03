class ApiConstants {
  static const String baseUrl = 'https://beta.hiffi.com/api';

  // Auth endpoints
  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';

  // User endpoints
  static const String userAvailability = '/users/availability';
  static const String updateUser =
      '/users/self'; // Update current user (identified by JWT token)
  static const String getCurrentUser =
      '/users/self'; // Deprecated, but still works
  static String getUser(String username) => '/users/$username';
  static String deleteUser(String username) => '/users/$username';
  static const String profilePhotoUpload = '/users/profile-photo/upload';

  // Video endpoints
  static const String uploadVideo = '/videos/upload';
  static String uploadVideoAck(String bridgeId) =>
      '/videos/upload/ack/$bridgeId';
  static const String videoList = '/videos/list';
  static const String videoListSelf = '/videos/list/self';
  static const String videoListFollowing = '/videos/list/following';
  static String getVideo(String videoId) => '/videos/$videoId';
  static String deleteVideo(String videoId) => '/videos/$videoId';
  static String listVideosByUsername(String username) =>
      '/videos/list/$username';

  // Social endpoints
  static String upvoteVideo(String videoId) => '/social/videos/upvote/$videoId';
  static String downvoteVideo(String videoId) =>
      '/social/videos/downvote/$videoId';
  static String postComment(String videoId) =>
      '/social/videos/comment/$videoId';
  static String getComments(String videoId) =>
      '/social/videos/comments/$videoId';
  static String postReply(String commentId) =>
      '/social/videos/reply/$commentId';
  static String getReplies(String commentId) =>
      '/social/videos/replies/$commentId';
  static String followUser(String username) => '/social/users/follow/$username';
  static String unfollowUser(String username) =>
      '/social/users/unfollow/$username';

  // Search endpoints
  static String searchUsers(String query) =>
      '/search/users/${Uri.encodeComponent(query)}';
  static String searchVideos(String query) =>
      '/search/videos/${Uri.encodeComponent(query)}';
}
