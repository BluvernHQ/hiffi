import '../../../playlist/domain/models/playlist_models.dart';
import '../../domain/models/video_history_entry.dart';
import '../../domain/models/video_model.dart';

/// Owns in-session navigation history for the video player (back stack).
class VideoPlayerCoordinator {
  final List<VideoHistoryEntry> _history = [];

  bool get hasPrevious => _history.isNotEmpty;

  int get historyLength => _history.length;

  List<VideoHistoryEntry> get history => List.unmodifiable(_history);

  void pushCurrent({
    required VideoModel video,
    PlaylistSession? playlistSession,
  }) {
    _history.add(
      VideoHistoryEntry(
        video: video,
        playlistSession: playlistSession,
      ),
    );
  }

  VideoHistoryEntry? popPrevious() {
    if (_history.isEmpty) return null;
    return _history.removeLast();
  }

  void clearHistory() => _history.clear();
}
