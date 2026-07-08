/// Content type selection for migration requests (mirrors web enums).
enum MigrationContentType {
  musicVideos,
  audioTracks,
  musicVideosAndAudio,
  other,
}

extension MigrationContentTypeLabels on MigrationContentType {
  String get label => switch (this) {
    MigrationContentType.musicVideos => 'Music Videos',
    MigrationContentType.audioTracks => 'Audio Tracks',
    MigrationContentType.musicVideosAndAudio => 'Music Videos and Audio',
    MigrationContentType.other => 'Other',
  };
}

/// Builds the `note` field sent to `POST /migration-requests`.
String buildMigrationNote(
  MigrationContentType contentType, {
  String? userNote,
}) {
  final base = 'Content type: ${contentType.label}';
  final extra = userNote?.trim();
  if (extra == null || extra.isEmpty) return base;
  return '$base\n\n$extra';
}

/// Parses content type from the first line of a migration `note`.
String extractContentTypeFromNote(String? note) {
  final lines = note?.split('\n') ?? const <String>[];
  final firstLine = lines.isNotEmpty ? lines.first.trim() : '';
  const prefix = 'Content type:';
  if (firstLine.startsWith(prefix)) {
    return firstLine.substring(prefix.length).trim();
  }
  return '—';
}
