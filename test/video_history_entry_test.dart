import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/features/playlist/domain/models/playlist_models.dart';
import 'package:hiffi/features/video/domain/models/video_history_entry.dart';
import 'package:hiffi/features/video/domain/models/video_model.dart';
import 'package:hiffi/features/video/presentation/coordinators/video_player_coordinator.dart';

void main() {
  group('VideoHistoryEntry', () {
    test('stores video and optional playlist session', () {
      final video = VideoModel.preview(videoId: 'v1', title: 'Test');
      const session = PlaylistSession(
        playlistId: 'pl-1',
        videoIds: ['v1', 'v2'],
        currentIndex: 0,
        title: 'Mix',
        autoplay: true,
      );

      final entry = VideoHistoryEntry(
        video: video,
        playlistSession: session,
      );

      expect(entry.video.videoId, 'v1');
      expect(entry.playlistSession?.playlistId, 'pl-1');
    });
  });

  group('VideoPlayerCoordinator', () {
    test('push and pop history entries in LIFO order', () {
      final coordinator = VideoPlayerCoordinator();
      final first = VideoModel.preview(videoId: 'a');
      final second = VideoModel.preview(videoId: 'b');

      coordinator.pushCurrent(video: first);
      coordinator.pushCurrent(video: second);

      expect(coordinator.hasPrevious, isTrue);
      expect(coordinator.historyLength, 2);

      final popped = coordinator.popPrevious();
      expect(popped?.video.videoId, 'b');

      final next = coordinator.popPrevious();
      expect(next?.video.videoId, 'a');
      expect(coordinator.hasPrevious, isFalse);
    });
  });
}
