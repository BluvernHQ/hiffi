import 'package:flutter/material.dart';

import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../video/domain/models/video_model.dart';
import 'profile_video_grid_item.dart';

const _profileRed = Color(0xFFED1C2F);

class ProfileVideoSection extends StatelessWidget {
  const ProfileVideoSection({
    super.key,
    required this.isOwnProfile,
    required this.sectionTitle,
    required this.videos,
    required this.isLoading,
    required this.hasAttemptedLoad,
    required this.errorMessage,
    required this.onRetry,
    required this.onVideoTap,
    this.onDelete,
    this.onUpload,
  });

  final bool isOwnProfile;
  final String sectionTitle;
  final List<VideoModel> videos;
  final bool isLoading;
  final bool hasAttemptedLoad;
  final String? errorMessage;
  final VoidCallback onRetry;
  final void Function(VideoModel video) onVideoTap;
  final void Function(VideoModel video)? onDelete;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          _VideoListShimmer()
        else if (errorMessage != null)
          _VideoErrorState(message: errorMessage!, onRetry: onRetry)
        else if (videos.isEmpty && hasAttemptedLoad)
          _VideosEmptyState(isOwnProfile: isOwnProfile, onUpload: onUpload)
        else if (videos.isEmpty && !hasAttemptedLoad)
          const SizedBox.shrink()
        else
          _VideoList(
            videos: videos,
            isOwnProfile: isOwnProfile,
            onVideoTap: onVideoTap,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class ProfileVideosOfflinePlaceholder extends StatelessWidget {
  const ProfileVideosOfflinePlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Videos',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connect to the internet to load videos.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoErrorState extends StatelessWidget {
  const _VideoErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: isOfflineErrorMessage(message)
          ? Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            )
          : Column(
              children: [
                Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                TextButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
    );
  }
}

class _VideosEmptyState extends StatelessWidget {
  const _VideosEmptyState({required this.isOwnProfile, this.onUpload});

  final bool isOwnProfile;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _profileRed.withValues(alpha: 0.35),
          width: 1.5,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: _profileRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.videocam_off_outlined,
              size: 26,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'No Videos Yet',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOwnProfile
                ? 'Upload your first video and start building your profile.'
                : 'This creator has not uploaded any videos yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF8A8A8A),
              height: 1.35,
            ),
          ),
          if (isOwnProfile && onUpload != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.add, size: 18, color: Colors.white),
              label: Text(
                'Upload Video',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _profileRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VideoListShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (!isTabletOrLarger(context)) {
      const itemWidth = 200.0;
      const itemHeight = 112.5;
      return SizedBox(
        height: itemHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const InlineShimmer(width: itemWidth, height: itemHeight),
            );
          },
        ),
      );
    }

    final crossAxisCount = responsiveGridColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemCount: crossAxisCount * 2,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const InlineShimmer(width: double.infinity, height: 110),
        );
      },
    );
  }
}

class _VideoList extends StatelessWidget {
  const _VideoList({
    required this.videos,
    required this.isOwnProfile,
    required this.onVideoTap,
    this.onDelete,
  });

  final List<VideoModel> videos;
  final bool isOwnProfile;
  final void Function(VideoModel video) onVideoTap;
  final void Function(VideoModel video)? onDelete;

  @override
  Widget build(BuildContext context) {
    if (!isTabletOrLarger(context)) {
      const itemWidth = 200.0;
      const itemHeight = 112.5;

      return SizedBox(
        height: itemHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return Container(
              width: itemWidth,
              height: itemHeight,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: ProfileVideoGridItem(
                video: video,
                onTap: () => onVideoTap(video),
                onDelete: isOwnProfile && onDelete != null
                    ? () => onDelete!(video)
                    : null,
              ),
            );
          },
        ),
      );
    }

    final crossAxisCount = responsiveGridColumns(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return ProfileVideoGridItem(
          video: video,
          onTap: () => onVideoTap(video),
          onDelete: isOwnProfile && onDelete != null
              ? () => onDelete!(video)
              : null,
        );
      },
    );
  }
}
