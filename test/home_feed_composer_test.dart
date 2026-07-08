import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/features/home/domain/home_feed_composer.dart';
import 'package:hiffi/features/playlist/data/playlist_repository.dart';
import 'package:hiffi/features/playlist/domain/models/playlist_models.dart';
import 'package:hiffi/features/playlist/presentation/viewmodels/playlist_view_model.dart';
import 'package:hiffi/features/video/domain/models/video_model.dart';
import 'package:hiffi/features/video/domain/repositories/video_repository.dart';

void main() {
  group('buildPrioritizedFeed', () {
    late _FakePlaylistRepository playlistRepository;
    late PlaylistViewModel playlistViewModel;

    setUp(() {
      playlistRepository = _FakePlaylistRepository();
      playlistViewModel = PlaylistViewModel(
        playlistRepository: playlistRepository,
        videoRepository: _ThrowingVideoRepository(),
      );
    });

    test('returns source unchanged when empty', () {
      expect(
        buildPrioritizedFeed(
          source: const [],
          playlistViewModel: playlistViewModel,
          curatedShuffleSeed: 42,
        ),
        isEmpty,
      );
    });

    test('returns source unchanged when no curated playlists', () async {
      final source = [
        VideoModel.preview(videoId: 'a'),
        VideoModel.preview(videoId: 'b'),
      ];

      final result = buildPrioritizedFeed(
        source: source,
        playlistViewModel: playlistViewModel,
        curatedShuffleSeed: 1,
      );

      expect(result.map((v) => v.videoId), ['a', 'b']);
    });

    test('places curated videos first and preserves non-curated order', () async {
      playlistRepository.curated = [
        const PlaylistSummary(playlistId: 'pl-1', title: 'Curated'),
      ];
      playlistRepository.details['pl-1'] = const PlaylistDetail(
        playlistId: 'pl-1',
        title: 'Curated',
        items: [
          PlaylistItem(videoId: 'curated-1', position: 0),
          PlaylistItem(videoId: 'curated-2', position: 1),
        ],
      );

      await playlistViewModel.loadCuratedPlaylists(force: true);
      await playlistViewModel.loadCuratedPlaylistDetail('pl-1');

      final source = [
        VideoModel.preview(videoId: 'other-1'),
        VideoModel.preview(videoId: 'curated-2'),
        VideoModel.preview(videoId: 'curated-1'),
        VideoModel.preview(videoId: 'other-2'),
      ];

      final result = buildPrioritizedFeed(
        source: source,
        playlistViewModel: playlistViewModel,
        curatedShuffleSeed: 99,
      );

      expect(result.map((v) => v.videoId), [
        'curated-1',
        'curated-2',
        'other-1',
        'other-2',
      ]);
    });

    test('same shuffle seed produces deterministic curated order', () async {
      playlistRepository.curated = [
        const PlaylistSummary(playlistId: 'pl-1', title: 'Curated'),
      ];
      playlistRepository.details['pl-1'] = const PlaylistDetail(
        playlistId: 'pl-1',
        title: 'Curated',
        items: [
          PlaylistItem(videoId: 'c1', position: 0),
          PlaylistItem(videoId: 'c2', position: 1),
          PlaylistItem(videoId: 'c3', position: 2),
        ],
      );

      await playlistViewModel.loadCuratedPlaylists(force: true);
      await playlistViewModel.loadCuratedPlaylistDetail('pl-1');

      final source = [
        VideoModel.preview(videoId: 'c1'),
        VideoModel.preview(videoId: 'c2'),
        VideoModel.preview(videoId: 'c3'),
        VideoModel.preview(videoId: 'x'),
      ];

      final first = buildPrioritizedFeed(
        source: source,
        playlistViewModel: playlistViewModel,
        curatedShuffleSeed: 42,
      );
      final second = buildPrioritizedFeed(
        source: source,
        playlistViewModel: playlistViewModel,
        curatedShuffleSeed: 42,
      );

      expect(first.map((v) => v.videoId), second.map((v) => v.videoId));
      expect(first.take(3).map((v) => v.videoId).toSet(), {'c1', 'c2', 'c3'});
      expect(first.last.videoId, 'x');
    });
  });
}

class _FakePlaylistRepository implements PlaylistRepository {
  List<PlaylistSummary> curated = [];
  final Map<String, PlaylistDetail> details = {};

  @override
  Future<List<PlaylistSummary>> getCuratedPlaylists() async => curated;

  @override
  Future<PlaylistDetail> getCuratedPlaylist(String playlistId) async {
    final detail = details[playlistId];
    if (detail == null) {
      throw StateError('Missing curated detail for $playlistId');
    }
    return detail;
  }

  @override
  Future<void> addItem(String playlistId, String videoId) =>
      throw UnimplementedError();

  @override
  Future<PlaylistDetail> createPlaylist({
    required String title,
    String? description,
    required String videoId,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> deletePlaylist(String playlistId) => throw UnimplementedError();

  @override
  Future<PlaylistDetail> getPlaylist(String playlistId) =>
      throw UnimplementedError();

  @override
  Future<List<PlaylistSummary>> getSelfPlaylists() => throw UnimplementedError();

  @override
  Future<void> removeItem(String playlistId, String videoId) =>
      throw UnimplementedError();

  @override
  Future<void> reorderItems(String playlistId, List<String> videoIdsInOrder) =>
      throw UnimplementedError();

  @override
  Future<void> updatePlaylist(
    String playlistId, {
    String? title,
    String? description,
  }) =>
      throw UnimplementedError();
}

class _ThrowingVideoRepository implements VideoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
