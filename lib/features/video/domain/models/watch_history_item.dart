import 'video_model.dart';

/// One row from GET /videos/list/history: nested [video], optional creator avatar, watch time.
class WatchHistoryItem {
  WatchHistoryItem({
    required this.video,
    required this.viewedAt,
  });

  final VideoModel video;
  final DateTime viewedAt;
}

/// Paginated watch history (`data.count`, `data.limit`, `data.offset`, `data.videos`).
class WatchHistoryResult {
  WatchHistoryResult({
    required this.count,
    required this.limit,
    required this.offset,
    required this.videos,
  });

  final int count;
  final int limit;
  final int offset;
  final List<WatchHistoryItem> videos;
}
