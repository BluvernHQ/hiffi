import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../user/domain/models/user_model.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../viewmodels/home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load current user data when page loads
      context.read<UserViewModel>().loadCurrentUser();
      // Load videos feed
      context.read<VideoViewModel>().loadVideos(refresh: true);
    });
  }

  Future<bool> _onWillPop() async {
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App'),
        content: const Text('Are you sure you want to close the app?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Exit'),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = context.watch<HomeViewModel>();
    final userViewModel = context.watch<UserViewModel>();
    final videoViewModel = context.watch<VideoViewModel>();
    final user = userViewModel.currentUser;

    return PopScope(
      canPop: context.canPop(),
      onPopInvoked: (didPop) async {
        if (!didPop && !context.canPop()) {
          // Only show exit dialog if we're at the root route
          final shouldPop = await _onWillPop();
          if (shouldPop) {
            // Exit the app
            SystemNavigator.pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Home'),
          actions: [
            IconButton(
              onPressed: () {
                homeViewModel.signOut();
              },
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: userViewModel.isLoading && user == null
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await context.read<UserViewModel>().loadCurrentUser();
                  await context.read<VideoViewModel>().refresh();
                },
                child: CustomScrollView(
                  slivers: [
                    // Compact Profile Section
                    if (user != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: _CompactProfileSection(
                            user: user,
                            onProfileTap: () {
                              context.push('/users/${user.username}');
                            },
                            onUploadTap: () {
                              context.push('/upload/video');
                            },
                          ),
                        ),
                      ),
                    // Video Feed
                    if (videoViewModel.isLoading &&
                        videoViewModel.videos.isEmpty)
                      const SliverFillRemaining(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (videoViewModel.errorMessage != null &&
                        videoViewModel.videos.isEmpty)
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
                                videoViewModel.errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  videoViewModel.refresh();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (videoViewModel.videos.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.video_library_outlined,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No videos yet',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.6),
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
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
                            // Calculate aspect ratio based on screen size
                            // Thumbnail (16:9) + spacing + text section (60h)
                            childAspectRatio: _calculateAspectRatio(context),
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              if (index >= videoViewModel.videos.length) {
                                // Load more if available
                                if (videoViewModel.hasMore &&
                                    !videoViewModel.isLoading) {
                                  videoViewModel.loadVideos();
                                }
                                return videoViewModel.isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : const SizedBox.shrink();
                              }
                              final video = videoViewModel.videos[index];
                              return _GridVideoCard(video: video);
                            },
                            childCount:
                                videoViewModel.videos.length +
                                (videoViewModel.hasMore ? 1 : 0),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CompactProfileSection extends StatelessWidget {
  const _CompactProfileSection({
    required this.user,
    required this.onProfileTap,
    required this.onUploadTap,
  });

  final UserModel user;
  final VoidCallback onProfileTap;
  final VoidCallback onUploadTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Profile Avatar - Compact
        GestureDetector(
          onTap: onProfileTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage:
                    (user.profilePicture != null &&
                        user.profilePicture!.isNotEmpty)
                    ? NetworkImage(user.profilePicture!)
                    : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty)
                    ? NetworkImage(user.avatarUrl!)
                    : null,
                child:
                    (user.profilePicture == null ||
                            user.profilePicture!.isEmpty) &&
                        (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              if (user.status?.isLive == true)
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).colorScheme.surface,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.circle,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // User Info - Compact
        Expanded(
          child: GestureDetector(
            onTap: onProfileTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        user.name.isNotEmpty ? user.name : user.username,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (user.status?.isLive == true) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 6),
                            SizedBox(width: 3),
                            Text(
                              'LIVE',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Upload Button - Compact FAB
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onUploadTap,
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.add, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ],
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

  String get _thumbnailUrl {
    if (video.videoThumbnail.isEmpty) {
      return '';
    }
    return 'https://blr1.digitaloceanspaces.com/dev.hiffi/${video.videoThumbnail}';
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
                child: _thumbnailUrl.isEmpty
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
                            _thumbnailUrl,
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
                          // View count overlay (top right)
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
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
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
                      CircleAvatar(
                        radius: 10.r,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          video.userUsername.isNotEmpty
                              ? video.userUsername[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Flexible(
                        child: Text(
                          video.userUsername.isNotEmpty
                              ? video.userUsername
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
