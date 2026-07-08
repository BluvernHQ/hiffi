import 'package:flutter/material.dart';

import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../../core/widgets/offline_empty_state.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../domain/models/video_model.dart';

const double kSuggestedStripHeight = 168;

class VideoSuggestedSection extends StatelessWidget {
  const VideoSuggestedSection({
    required this.videos,
    required this.isLoading,
    required this.hasError,
    required this.isNoInternet,
    required this.onRetry,
    required this.onVideoSelected,
  });

  final List<VideoModel> videos;
  final bool isLoading;
  final bool hasError;
  final bool isNoInternet;
  final VoidCallback onRetry;
  final void Function(VideoModel) onVideoSelected;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [SuggestedVideosStripShimmer()],
        ),
      );
    }

    if (hasError) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: OfflineEmptyState(
          variant: OfflineEmptyVariant.section,
          title: isNoInternet ? "You're Offline" : 'Could not load suggestions',
          description: isNoInternet
              ? 'Connect to the internet to see suggested videos.'
              : 'Please try again.',
          actionLabel: 'Try Again',
          onTryAgain: onRetry,
        ),
      );
    }

    if (videos.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Suggested Videos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: kSuggestedStripHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              itemBuilder: (context, index) => Padding(
                padding: EdgeInsets.only(
                  right: index == videos.length - 1 ? 0 : 12,
                ),
                child: VideoSuggestedVideoCard(
                  video: videos[index],
                  onTap: onVideoSelected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VideoSuggestedVideoCard extends StatelessWidget {
  final VideoModel video;
  final void Function(VideoModel) onTap;
  const VideoSuggestedVideoCard({required this.video, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(video),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 160,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: HiffiVideoThumbnail(
                  thumbnailPath: video.videoThumbnail,
                  fit: BoxFit.cover,
                  backgroundColor: Colors.grey[200],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              video.videoTitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                HiffiAvatar(
                  imageUrl: video.profilePicture,
                  size: 16,
                  fallbackText: video.userUsername,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    video.userUsername,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B6B6B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
