class ApiConstants {
  static const String baseUrl = 'https://hiffi.alterwork.in/api';

  // User endpoints
  static const String userAvailability = '/users/availability';
  static const String createUser = '/users/create';
  static const String getCurrentUser = '/users/self';
  static String getUser(String username) => '/users/$username';
  static String updateUser(String username) => '/users/$username';
  static String deleteUser(String username) => '/users/$username';

  // Video endpoints
  static const String uploadVideo = '/videos/upload';
  static String uploadVideoAck(String bridgeId) =>
      '/videos/upload/ack/$bridgeId';
  static const String videoList = '/videos/list';
  static String getVideoUrl(String videoUrl) => '/$videoUrl';

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
}
