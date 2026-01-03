import 'package:flutter/foundation.dart';

/// Utility functions for handling image URLs, especially profile pictures
class ImageUtils {
  // Base URL for profile images
  static const String profileImageBaseUrl =
      'https://black-paper-83cf.hiffi.workers.dev';

  // API key for profile image requests (should be stored securely in production)
  // TODO: Move this to environment variables or secure storage
  static const String profileImageApiKey = 'SECRET_KEY';

  /// Checks if a URL is a valid image URL (not a placeholder)
  static bool isValidImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) {
      debugPrint('ImageUtils.isValidImageUrl: URL is null or empty');
      return false;
    }

    final trimmedUrl = url.trim().toLowerCase();

    // Filter out known placeholder/invalid URLs
    final invalidUrls = [
      'https://example.com/newpic.jpg',
      'http://example.com/newpic.jpg',
      'example.com/newpic.jpg',
    ];

    final isValid = !invalidUrls.contains(trimmedUrl);
    if (!isValid) {
      debugPrint(
        'ImageUtils.isValidImageUrl: URL "$trimmedUrl" is in invalid list',
      );
    }
    return isValid;
  }

  /// Constructs a profile image URL from a profile picture path
  ///
  /// The profile_picture field from the API contains a path like:
  /// "ProfileProto/users/1f830e01fe7a2cae69d1fa07a7ec7443.jpg"
  ///
  /// This function constructs the full URL:
  /// https://black-paper-83cf.hiffi.workers.dev/ProfileProto/users/...
  ///
  /// [cacheBust] - Optional timestamp to bust cache (useful after image updates)
  static String? getProfileImageUrl(String? profilePicture, {int? cacheBust}) {
    if (profilePicture == null || profilePicture.trim().isEmpty) {
      return null;
    }

    final trimmedPicture = profilePicture.trim();

    // Filter out invalid placeholder URLs
    if (!isValidImageUrl(trimmedPicture)) {
      return null;
    }

    // If it's already a full URL (starts with http:// or https://), return as-is
    if (trimmedPicture.startsWith('http://') ||
        trimmedPicture.startsWith('https://')) {
      // Add cache-busting parameter if provided
      if (cacheBust != null) {
        final separator = trimmedPicture.contains('?') ? '&' : '?';
        return '$trimmedPicture$separator v=$cacheBust';
      }
      return trimmedPicture;
    }

    // Ensure path starts with / if it doesn't already
    final path = trimmedPicture.startsWith('/')
        ? trimmedPicture
        : '/$trimmedPicture';

    final baseUrl = '$profileImageBaseUrl$path';

    // Add cache-busting parameter if provided (for iOS cache issues)
    if (cacheBust != null) {
      return '$baseUrl?v=$cacheBust';
    }

    return baseUrl;
  }

  /// Gets headers required for profile image requests
  ///
  /// Headers are needed for all Hiffi profile images, whether they're:
  /// - Paths (e.g., "ProfileProto/users/...")
  /// - Full URLs from the Hiffi Workers domain
  static Map<String, String>? getProfileImageHeaders(String? url) {
    if (url == null || url.isEmpty) {
      return null;
    }

    // Check if URL is from Hiffi Workers domain (full URL)
    if (url.contains(profileImageBaseUrl) ||
        url.contains('hiffi.workers.dev')) {
      return {'x-api-key': profileImageApiKey};
    }

    // Check if URL is a path (starts with ProfileProto or thumbnails)
    // These paths will be processed by getProfileImageUrl and need headers
    final trimmedUrl = url.trim();
    if (trimmedUrl.startsWith('ProfileProto/') ||
        trimmedUrl.startsWith('/ProfileProto/') ||
        trimmedUrl.startsWith('thumbnails/') ||
        trimmedUrl.startsWith('/thumbnails/')) {
      return {'x-api-key': profileImageApiKey};
    }

    // For any other URLs (external domains), don't add headers
    return null;
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

    // If it's already a full URL (starts with http:// or https://), return as-is
    if (videoThumbnail.startsWith('http://') ||
        videoThumbnail.startsWith('https://')) {
      return videoThumbnail;
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
