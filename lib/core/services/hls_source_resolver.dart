/// Service responsible for resolving video IDs, storage paths, or Workers URLs
/// to HLS master.m3u8 URLs.
///
/// Follows the exact HLS resolution logic:
/// - Accepts video ID, storage path, or Workers URL
/// - Normalizes the path
/// - Appends /hls/master.m3u8
/// - Never falls back to MP4
class HlsSourceResolver {
  static const String hlsSuffix = '/hls/master.m3u8';

  /// Resolves a base video URL to its HLS master manifest URL.
  ///
  /// [baseVideoUrl] is the Workers base URL from GET /videos/{videoId}:
  /// Example: "https://black-paper-83cf.hiffi.workers.dev/videos/{videoId}"
  ///
  /// Returns the master.m3u8 URL: {baseVideoUrl}/hls/master.m3u8
  ///
  /// This matches the exact HLS resolution logic requirement.
  String resolveHlsUrl(String baseVideoUrl) {
    // Normalize the URL (remove trailing slash)
    final cleanUrl = baseVideoUrl.endsWith('/')
        ? baseVideoUrl.substring(0, baseVideoUrl.length - 1)
        : baseVideoUrl;

    // Ensure we don't already have /hls/master.m3u8 in the URL
    if (cleanUrl.endsWith(hlsSuffix)) {
      return cleanUrl;
    }

    // Append /hls/master.m3u8
    return '$cleanUrl$hlsSuffix';
  }

  /// Resolves the profiles.json URL for manual quality selection.
  ///
  /// [baseVideoUrl] is the Workers base URL from GET /videos/{videoId}
  ///
  /// Returns the profiles.json URL: {baseVideoUrl}/profiles.json
  String? resolveProfilesUrl(String baseVideoUrl) {
    final cleanUrl = baseVideoUrl.endsWith('/')
        ? baseVideoUrl.substring(0, baseVideoUrl.length - 1)
        : baseVideoUrl;

    // Remove /hls/master.m3u8 if present
    final base = cleanUrl.replaceAll(hlsSuffix, '');

    return '$base/profiles.json';
  }
}
