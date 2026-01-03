/// Model representing a quality variant for the HLS player.
/// Mapped from profiles.json in the video storage structure.
class VideoProfile {
  final String name; // e.g., "1080p", "720p", "auto"
  final String? resolution; // e.g., "1920x1080"
  final String playlistUrl; // Full URL to the variant's .m3u8 playlist

  VideoProfile({
    required this.name,
    this.resolution,
    required this.playlistUrl,
  });

  /// Factory to create a profile from profiles.json entries.
  ///
  /// [json] is an entry from the profiles array.
  /// [baseUrl] is the video's base storage URL.
  factory VideoProfile.fromJson(Map<String, dynamic> json, String baseUrl) {
    final name = json['name'] as String;
    return VideoProfile(
      name: name,
      resolution: json['resolution'] as String?,
      // Variant playlists are stored in /hls/{name}.m3u8
      playlistUrl: '$baseUrl/hls/$name.m3u8',
    );
  }

  /// Helper for the "Auto" (ABR) variant which points to the master manifest.
  factory VideoProfile.auto(String masterPlaylistUrl) {
    return VideoProfile(
      name: 'Auto',
      resolution: null,
      playlistUrl: masterPlaylistUrl,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoProfile &&
          runtimeType == other.runtimeType &&
          playlistUrl == other.playlistUrl;

  @override
  int get hashCode => playlistUrl.hashCode;
}
