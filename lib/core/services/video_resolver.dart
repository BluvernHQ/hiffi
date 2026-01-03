import 'package:flutter/foundation.dart';

/// Service responsible for resolving video IDs to HLS URLs and managing profiles.
/// Follows parity with Next.js architecture for secure media delivery.
class VideoResolver {
  static const String hlsSuffix = '/hls/master.m3u8';
  static const String profilesSuffix = '/profiles.json';

  // In-memory cache for resolved master manifest URLs
  final Map<String, String> _manifestCache = {};

  // In-memory cache for base URLs
  final Map<String, String> _baseUrlCache = {};

  /// Resolves a videoId and base video_url to its HLS master manifest URL.
  ///
  /// Example: video_url -> video_url/hls/master.m3u8
  String resolveHlsUrl(String videoId, String baseUrl) {
    if (_manifestCache.containsKey(videoId)) return _manifestCache[videoId]!;

    // Parity with Next.js flow: base_url + /hls/master.m3u8
    // Ensure baseUrl doesn't end with / before appending
    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final resolvedUrl = '$cleanBaseUrl$hlsSuffix';

    _manifestCache[videoId] = resolvedUrl;
    _baseUrlCache[videoId] = cleanBaseUrl;

    return resolvedUrl;
  }

  /// Resolves the profiles.json URL for manual quality mapping.
  String? resolveProfilesUrl(String videoId) {
    final baseUrl = _baseUrlCache[videoId];
    if (baseUrl == null) return null;
    return '$baseUrl$profilesSuffix';
  }

  /// Gets the base URL for a resolved video (useful for resolving variant playlists).
  String? getBaseUrl(String videoId) => _baseUrlCache[videoId];

  void clearCache() {
    _manifestCache.clear();
    _baseUrlCache.clear();
  }
}
