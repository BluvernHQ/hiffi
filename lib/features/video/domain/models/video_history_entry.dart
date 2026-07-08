import '../../domain/models/video_model.dart';
import '../../../playlist/domain/models/playlist_models.dart';

class VideoHistoryEntry {
  const VideoHistoryEntry({
    required this.video,
    required this.playlistSession,
  });

  final VideoModel video;
  final PlaylistSession? playlistSession;
}
