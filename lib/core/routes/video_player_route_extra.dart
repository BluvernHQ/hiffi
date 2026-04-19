import 'package:hiffi/features/video/domain/models/video_model.dart';

/// Optional [go_router] `extra` for `/video/:id` when more than [VideoModel] is needed.
class VideoPlayerRouteExtra {
  const VideoPlayerRouteExtra({
    required this.video,
    this.initialResumePosition,
  });

  final VideoModel video;
  final Duration? initialResumePosition;
}
