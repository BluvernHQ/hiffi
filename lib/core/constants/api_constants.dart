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
}
