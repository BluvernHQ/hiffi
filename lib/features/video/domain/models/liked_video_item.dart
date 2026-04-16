import 'video_model.dart';

/// One row from GET /videos/list/liked: nested [video], optional creator avatar path, like timestamp.
class LikedVideoItem {
  LikedVideoItem({
    required this.video,
    required this.upvotedAt,
  });

  final VideoModel video;
  final DateTime upvotedAt;
}

/// Paginated liked list payload (maps `data.count`, `data.limit`, `data.offset`, `data.videos`).
class LikedVideosResult {
  LikedVideosResult({
    required this.count,
    required this.limit,
    required this.offset,
    required this.videos,
  });

  final int count;
  final int limit;
  final int offset;
  final List<LikedVideoItem> videos;
}
