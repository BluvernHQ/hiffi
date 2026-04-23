import 'package:flutter_test/flutter_test.dart';
import 'package:hiffi/features/playlist/domain/models/playlist_models.dart';

void main() {
  test('PlaylistDetail sorts items by ascending position', () {
    final detail = PlaylistDetail.fromJson({
      'playlist_id': 'p1',
      'title': 'My List',
      'items': [
        {'video_id': 'v2', 'position': 2},
        {'video_id': 'v1', 'position': 1},
      ],
    });

    expect(detail.items.first.videoId, 'v1');
    expect(detail.items.last.videoId, 'v2');
  });

  test('PlaylistDetail.fromPlaylistGetData reads nested playlist + items', () {
    final detail = PlaylistDetail.fromPlaylistGetData({
      'playlist': {
        'playlist_id': 'uuid-1',
        'title': 'My Favorites',
        'description': 'optional',
        'updated_at': '2026-04-20T10:30:00Z',
      },
      'items': [
        {
          'position': 1,
          'added_at': '2026-04-20T10:00:00Z',
          'video': {
            'video_id': 'video_123',
            'video_title': 'Test title',
            'video_thumbnail': 'thumbnails/videos/video_123.jpg',
          },
        },
      ],
      'limit': 20,
      'offset': 0,
      'count': 1,
    });

    expect(detail.playlistId, 'uuid-1');
    expect(detail.title, 'My Favorites');
    expect(detail.items, hasLength(1));
    expect(detail.items.single.videoId, 'video_123');
    expect(detail.items.single.videoTitle, 'Test title');
    expect(detail.items.single.videoThumbnail, 'thumbnails/videos/video_123.jpg');
    expect(detail.items.single.addedAt, '2026-04-20T10:00:00Z');
  });

  test('PlaylistSession validates required shape', () {
    final valid = PlaylistSession(
      playlistId: 'p1',
      videoIds: const ['a', 'b'],
      currentIndex: 1,
      autoplay: true,
    );
    final invalid = PlaylistSession(
      playlistId: '',
      videoIds: const [],
      currentIndex: 0,
      autoplay: true,
    );
    expect(valid.isValid, isTrue);
    expect(invalid.isValid, isFalse);
  });
}
