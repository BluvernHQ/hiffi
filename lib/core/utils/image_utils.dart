/// Utility functions for handling image URLs, especially profile pictures
class ImageUtils {
  // Base URL for profile images
  static const String profileImageBaseUrl =
      'https://black-paper-83cf.hiffi.workers.dev';

  // API key for profile image requests (should be stored securely in production)
  // TODO: Move this to environment variables or secure storage
  static const String profileImageApiKey = 'SECRET_KEY';

  /// Constructs a profile image URL from a profile picture path
  ///
  /// The profile_picture field from the API contains a path like:
  /// "ProfileProto/users/1f830e01fe7a2cae69d1fa07a7ec7443.jpg"
  ///
  /// This function constructs the full URL:
  /// https://black-paper-83cf.hiffi.workers.dev/ProfileProto/users/...
  static String? getProfileImageUrl(String? profilePicture) {
    if (profilePicture == null || profilePicture.isEmpty) {
      return null;
    }

    // Ensure path starts with / if it doesn't already
    final path = profilePicture.startsWith('/')
        ? profilePicture
        : '/$profilePicture';

    return '$profileImageBaseUrl$path';
  }

  /// Gets headers required for profile image requests
  static Map<String, String> getProfileImageHeaders() {
    return {'x-api-key': profileImageApiKey};
  }

  /// Constructs a video URL for accessing videos via Cloudflare Workers
  ///
  /// The video URL from the API is already a full Workers URL:
  /// "https://black-paper-83cf.hiffi.workers.dev/videos/{videoID}"
  ///
  /// This function just returns the URL as-is (for consistency and potential future processing)
  static String getVideoUrl(String videoUrl) {
    return videoUrl;
  }

  /// Gets headers required for video requests (Workers URL)
  ///
  /// When requesting video from Workers URL, include x-api-key header
  static Map<String, String> getVideoHeaders() {
    return {'x-api-key': profileImageApiKey};
  }

  /// Constructs a video thumbnail URL from a thumbnail path
  ///
  /// The video_thumbnail field from the API contains a path like:
  /// "thumbnails/videos/1794c70a2ea7d6ac3fb152e0515608b5477875b355674e7638f0cf24570cc97e.jpg"
  ///
  /// This function constructs the full URL:
  /// https://black-paper-83cf.hiffi.workers.dev/thumbnails/videos/...
  static String? getVideoThumbnailUrl(String? videoThumbnail) {
    if (videoThumbnail == null || videoThumbnail.isEmpty) {
      return null;
    }

    // Ensure path starts with / if it doesn't already
    final path = videoThumbnail.startsWith('/')
        ? videoThumbnail
        : '/$videoThumbnail';

    return '$profileImageBaseUrl$path';
  }

  /// Gets headers required for video thumbnail requests
  ///
  /// Video thumbnails use the same API key as profile images
  static Map<String, String> getVideoThumbnailHeaders() {
    return {'x-api-key': profileImageApiKey};
  }
}
