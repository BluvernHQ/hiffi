import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/offline_info_state.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../video/domain/models/liked_video_item.dart';
import '../../../video/domain/models/video_model.dart';
import '../viewmodels/liked_videos_view_model.dart';

class LikedVideosPage extends StatefulWidget {
  const LikedVideosPage({super.key});

  @override
  State<LikedVideosPage> createState() => _LikedVideosPageState();
}

class _LikedVideosPageState extends State<LikedVideosPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LikedVideosViewModel>().loadVideos(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final likedVm = context.watch<LikedVideosViewModel>();

    if (likedVm.unauthorized) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final likedViewModel = context.read<LikedVideosViewModel>();
        final authRepository = context.read<AuthRepository>();
        final authViewModel = context.read<AuthViewModel>();
        final router = GoRouter.of(context);
        likedViewModel.clearUnauthorizedFlag();
        await authRepository.signOut();
        if (!mounted) return;
        authViewModel.reset();
        if (!mounted) return;
        router.go('/login?returnTo=/liked');
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        context.go('/home');
      },
      child: MainScaffold(
        appBar: AppBar(
          toolbarHeight: 72,
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
          title: const Text('Liked videos'),
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: () async {
              await context.read<LikedVideosViewModel>().refresh();
            },
            child: CustomScrollView(
              slivers: [
                if (likedVm.isLoading && likedVm.items.isEmpty)
                  SliverFillRemaining(child: VideoListShimmer(itemCount: 6))
                else if (likedVm.errorMessage != null && likedVm.items.isEmpty)
                  SliverFillRemaining(
                    child: isOfflineErrorMessage(likedVm.errorMessage)
                        ? OfflineInfoState(
                            message:
                                'Connect to the internet to view your liked videos.',
                            actionLabel: 'Try Again',
                            onAction: () => likedVm.refresh(),
                          )
                        : Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(height: 32),
                                  Text(
                                    'Oops! Something went wrong',
                                    style: Theme.of(context).textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    likedVm.errorMessage!,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 40),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      likedVm.refresh();
                                    },
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  )
                else if (likedVm.items.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.thumb_up_off_alt_rounded,
                              size: 64,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              'No liked videos yet',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Videos you upvote will show up here',
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
                              onPressed: () => context.go('/home'),
                              icon: const Icon(Icons.explore_rounded),
                              label: const Text('Discover videos'),
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
                        crossAxisCount: responsiveGridColumns(context),
                        mainAxisSpacing: 12.h,
                        crossAxisSpacing: 12.w,
                        childAspectRatio: _likedCardAspectRatio(context),
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= likedVm.items.length) {
                            if (likedVm.hasMore && !likedVm.isLoading) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                likedVm.loadVideos();
                              });
                            }
                            return likedVm.isLoading
                                ? const Center(
                                    child: InlineShimmer(width: 40, height: 40),
                                  )
                                : const SizedBox.shrink();
                          }
                          final item = likedVm.items[index];
                          return _LikedGridVideoCard(
                            item: item,
                            likedLabel: _relativeTime(item.upvotedAt),
                          );
                        },
                        childCount:
                            likedVm.items.length + (likedVm.hasMore ? 1 : 0),
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

double _likedCardAspectRatio(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final columns = responsiveGridColumns(context).toDouble();
  final horizontalPadding = 12.w * 2;
  final spacing = 12.w;
  final cardWidth =
      (screenWidth - horizontalPadding - spacing * (columns - 1)) / columns;

  final thumbnailHeight = cardWidth * (9 / 16);
  // Extra vertical room for the added "Liked <date>" row so title rendering
  // remains clean and uses proper ellipsis instead of hard clipping.
  final textSectionHeight =
      responsiveGridTextSectionHeight(context) + 8.h + 22.h;
  final totalHeight = thumbnailHeight + textSectionHeight;

  return cardWidth / totalHeight;
}

class _LikedGridVideoCard extends StatelessWidget {
  const _LikedGridVideoCard({required this.item, required this.likedLabel});

  final LikedVideoItem item;
  final String likedLabel;

  VideoModel get video => item.video;

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
                                child: Icon(
                                  Icons.broken_image,
                                  size: 32,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
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
                                  ),
                                ),
                              );
                            },
                          ),
                          if (video.status == 'temp')
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
                                child: const Text(
                                  'processing',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 8.h),
            SizedBox(
              height: responsiveGridTextSectionHeight(context) + 22.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        video.videoTitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                          fontSize: responsiveGridTitleFontSize(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    likedLabel,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurfaceVariant.withOpacity(0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      HiffiAvatar(
                        imageUrl: video.profilePicture,
                        size: responsiveGridAvatarSize(context),
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
                                fontSize: responsiveGridSubtitleFontSize(
                                  context,
                                ),
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
}

String _relativeTime(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) {
    final value = diff.inMinutes;
    return '$value minute${value == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final value = diff.inHours;
    return '$value hour${value == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 7) {
    final value = diff.inDays;
    return '$value day${value == 1 ? '' : 's'} ago';
  }
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) {
    return '$weeks week${weeks == 1 ? '' : 's'} ago';
  }
  final months = (diff.inDays / 30).floor();
  if (months < 12) {
    return '$months month${months == 1 ? '' : 's'} ago';
  }
  final years = (diff.inDays / 365).floor();
  return '$years year${years == 1 ? '' : 's'} ago';
}
