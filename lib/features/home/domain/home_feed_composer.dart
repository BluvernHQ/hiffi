import 'dart:math';

import '../../playlist/presentation/viewmodels/playlist_view_model.dart';
import '../../video/domain/models/video_model.dart';

List<VideoModel> buildPrioritizedFeed({
  required List<VideoModel> source,
  required PlaylistViewModel playlistViewModel,
  required int curatedShuffleSeed,
}) {
  if (source.isEmpty) return const [];

  final curatedIds = <String>{};
  for (final curated in playlistViewModel.curatedPlaylists) {
    final detail = playlistViewModel.curatedDetail(curated.playlistId);
    if (detail == null) continue;
    for (final item in detail.items) {
      if (item.videoId.isNotEmpty) curatedIds.add(item.videoId);
    }
  }
  if (curatedIds.isEmpty) return source;

  final curatedVideos = <VideoModel>[];
  final nonCuratedVideos = <VideoModel>[];
  for (final video in source) {
    if (curatedIds.contains(video.videoId)) {
      curatedVideos.add(video);
    } else {
      nonCuratedVideos.add(video);
    }
  }

  final rng = Random(curatedShuffleSeed);
  curatedVideos.shuffle(rng);
  return [...curatedVideos, ...nonCuratedVideos];
}
