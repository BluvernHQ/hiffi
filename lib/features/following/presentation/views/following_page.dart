import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../video/domain/models/video_model.dart';
import '../viewmodels/following_view_model.dart';

class FollowingPage extends StatefulWidget {
  const FollowingPage({super.key});

  @override
  State<FollowingPage> createState() => _FollowingPageState();
}

class _FollowingPageState extends State<FollowingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FollowingViewModel>().loadVideos(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final followingViewModel = context.watch<FollowingViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        context.go('/home');
      },
      child: MainScaffold(
        appBar: AppBar(
          leadingWidth: 56,
          titleSpacing: 0,
          leading: Builder(
            builder: (context) {
              final sidebar = AppSidebar.of(context);
              if (sidebar == null) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: sidebar.toggleSidebar,
                tooltip: 'Menu',
              );
            },
          ),
          title: const Text('Following'),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<FollowingViewModel>().refresh();
            },
            child: CustomScrollView(
              slivers: [
                // Video Feed
                if (followingViewModel.isLoading &&
                    followingViewModel.videos.isEmpty)
                  SliverFillRemaining(child: VideoListShimmer(itemCount: 6))
                else if (followingViewModel.errorMessage != null &&
                    followingViewModel.videos.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            followingViewModel.errorMessage!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              followingViewModel.refresh();
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (followingViewModel.videos.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite_border_rounded,
                                size: 64,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No videos from followed creators yet',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Videos from creators you follow will appear here',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withOpacity(0.7),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            FilledButton.icon(
                              onPressed: () {
                                context.go('/home');
                              },
                              icon: const Icon(Icons.explore_rounded),
                              label: const Text('Discover Videos'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                    sliver: SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12.h,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: _calculateAspectRatio(context),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= followingViewModel.videos.length) {
                            // Load more if available
                            if (followingViewModel.hasMore &&
                                !followingViewModel.isLoading) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                followingViewModel.loadVideos();
                              });
                            }
                            return followingViewModel.isLoading
                                ? const Center(
                                    child: InlineShimmer(width: 40, height: 40),
                                  )
                                : const SizedBox.shrink();
                          }
                          final video = followingViewModel.videos[index];
                          return _GridVideoCard(video: video);
                        },
                        childCount:
                            followingViewModel.videos.length +
                            (followingViewModel.hasMore ? 1 : 0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Calculate aspect ratio based on screen width and content height
double _calculateAspectRatio(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  // Calculate card width: (screen width - left padding - right padding - spacing) / 2
  final horizontalPadding = 12.w * 2; // Left + right padding
  final spacing = 12.w; // Space between cards
  final cardWidth = (screenWidth - horizontalPadding - spacing) / 2;

  // Thumbnail maintains 16:9 aspect ratio
  final thumbnailHeight = cardWidth * (9 / 16);

  // Text section height (responsive)
  final textSectionHeight = 60.h + 8.h; // Text section + spacing

  // Total card height
  final totalHeight = thumbnailHeight + textSectionHeight;

  // Return aspect ratio (width / height)
  return cardWidth / totalHeight;
}

// Grid video card for feed layout
class _GridVideoCard extends StatelessWidget {
  const _GridVideoCard({required this.video});

  final VideoModel video;

  String? get _thumbnailUrl {
    return ImageUtils.getVideoThumbnailUrl(video.videoThumbnail);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          context.push('/video/${video.videoId}', extra: video);
        },
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _thumbnailUrl == null || _thumbnailUrl!.isEmpty
                    ? Container(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Center(
                          child: Icon(
                            Icons.video_library,
                            size: 48,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                          ),
                        ),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _thumbnailUrl!,
                            headers: ImageUtils.getVideoThumbnailHeaders(),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image,
                                        size: 32,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Failed to load thumbnail',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                              );
                            },
                          ),
                          // Processing indicator or View count overlay (top right)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: video.status == 'temp'
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'processing',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.visibility,
                                          size: 12,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _formatCount(video.videoViews),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          // Processing Overlay
                          if (video.status == 'temp')
                            IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Center(
                                  child: Icon(
                                    Icons.sync,
                                    color: Colors.white70,
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 8.h),
            // Title and User section - Responsive height
            SizedBox(
              height: 60.h, // Responsive height to ensure visibility
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      video.videoTitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                        fontSize: 13.sp,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      HiffiAvatar(
                        imageUrl: video.profilePicture,
                        size: 20.r,
                        fallbackText: video.userUsername,
                        cacheBust: video.updatedAt.millisecondsSinceEpoch,
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          video.userUsername.isNotEmpty
                              ? video.userUsername.toLowerCase()
                              : 'Unknown',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.8),
                                fontSize: 11.sp,
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
          ],
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }
}
