import 'video_model.dart';

/// One row from GET /videos/list/history: nested [video], watch metadata, resume point.
class WatchHistoryItem {
  WatchHistoryItem({
    required this.video,
    required this.viewedAt,
    this.positionSeconds,
  });

  final VideoModel video;
  final DateTime viewedAt;

  /// Server-reported playback position (`position_seconds`), when present.
  final double? positionSeconds;
}

/// Paginated watch history (`data.count`, `data.limit`, `data.offset`, `data.videos`).
class WatchHistoryResult {
  WatchHistoryResult({
    required this.count,
    required this.limit,
    required this.offset,
    required this.videos,
    required this.returnedSlotCount,
    this.serverNextOffset,
  });

  final int count;
  final int limit;
  final int offset;
  final List<WatchHistoryItem> videos;

  /// Length of `data.videos` from the API (before parse drops). Use for next `offset`.
  final int returnedSlotCount;

  /// When the API sends an explicit next cursor/offset (`next_offset`, etc.).
  final int? serverNextOffset;
}
