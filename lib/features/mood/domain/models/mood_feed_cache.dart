import '../../../video/domain/models/video_model.dart';

class MoodFeedCache {
  MoodFeedCache({
    required this.videos,
    required this.offset,
    required this.hasMore,
    this.moodEmpty = false,
  });

  final List<VideoModel> videos;
  final int offset;
  final bool hasMore;
  final bool moodEmpty;

  MoodFeedCache copyWith({
    List<VideoModel>? videos,
    int? offset,
    bool? hasMore,
    bool? moodEmpty,
  }) {
    return MoodFeedCache(
      videos: videos ?? this.videos,
      offset: offset ?? this.offset,
      hasMore: hasMore ?? this.hasMore,
      moodEmpty: moodEmpty ?? this.moodEmpty,
    );
  }
}
