import '../../features/playlist/domain/models/playlist_models.dart';
import '../../features/video/domain/models/video_model.dart';

/// Optional [go_router] `extra` for `/watch/:videoId`.
class WatchRouteExtra {
  const WatchRouteExtra({
    required this.video,
    this.playlistSession,
  });

  final VideoModel video;
  final PlaylistSession? playlistSession;
}
