import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    final homeViewModel = context.watch<HomeViewModel>();
    final userViewModel = context.watch<UserViewModel>();
    final videoViewModel = context.watch<VideoViewModel>();
    final user = userViewModel.currentUser;

    return Scaffold(
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
                  if (videoViewModel.isLoading && videoViewModel.videos.isEmpty)
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
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 0.75,
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

// Grid video card for feed layout
class _GridVideoCard extends StatelessWidget {
  const _GridVideoCard({required this.video});

  final VideoModel video;

  String get _thumbnailUrl =>
      'https://blr1.digitaloceanspaces.com/dev.hiffi/${video.videoThumbnail}';

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
          children: [
            // Thumbnail
            Expanded(
              flex: 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
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
                          child: Icon(
                            Icons.video_library,
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
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
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
            const SizedBox(height: 8),
            // Title and User (minimal)
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    video.videoTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        child: Text(
                          video.userUsername.isNotEmpty
                              ? video.userUsername[0].toUpperCase()
                              : 'U',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          video.userUsername.isNotEmpty
                              ? video.userUsername
                              : 'Unknown',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.8),
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
