import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../video/domain/models/video_model.dart';
import '../viewmodels/search_view_model.dart';

class SearchResultsPage extends StatefulWidget {
  const SearchResultsPage({super.key, required this.query});

  final String query;

  @override
  State<SearchResultsPage> createState() => _SearchResultsPageState();
}

class _SearchResultsPageState extends State<SearchResultsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Perform search on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchViewModel>().search(widget.query);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchViewModel = context.watch<SearchViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text('Search: ${widget.query}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Videos'),
            Tab(text: 'Users'),
          ],
        ),
      ),
      body: searchViewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : searchViewModel.hasNoResults
          ? _buildEmptyState()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllResults(searchViewModel),
                _buildVideoResults(searchViewModel),
                _buildUserResults(searchViewModel),
              ],
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllResults(SearchViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: () => viewModel.search(widget.query),
      child: CustomScrollView(
        slivers: [
          // Videos section
          if (viewModel.videoResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Videos (${viewModel.videoCount})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12.h,
                  crossAxisSpacing: 12.w,
                  childAspectRatio: _calculateAspectRatio(context),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final video = viewModel.videoResults[index];
                  return _GridVideoCard(video: video);
                }, childCount: viewModel.videoResults.length),
              ),
            ),
          ],
          // Users section
          if (viewModel.userResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Users (${viewModel.userCount})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final user = viewModel.userResults[index];
                  return _UserCard(user: user);
                }, childCount: viewModel.userResults.length),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVideoResults(SearchViewModel viewModel) {
    if (viewModel.videoResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No videos found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.searchVideos(widget.query),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 16.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: _calculateAspectRatio(context),
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final video = viewModel.videoResults[index];
                return _GridVideoCard(video: video);
              }, childCount: viewModel.videoResults.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserResults(SearchViewModel viewModel) {
    if (viewModel.userResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.searchUsers(widget.query),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final user = viewModel.userResults[index];
                return _UserCard(user: user);
              }, childCount: viewModel.userResults.length),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth =
        (screenWidth - 12.w * 3) / 2; // Account for padding and spacing
    final thumbnailHeight = cardWidth * 9 / 16; // 16:9 aspect ratio
    final textHeight = 60.h;
    final totalHeight = thumbnailHeight + 8.h + textHeight;
    return cardWidth / totalHeight;
  }
}

// Grid video card (reused from home page pattern)
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
                                child: Icon(
                                  Icons.broken_image,
                                  size: 32,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: 8.h),
            // Title and User section
            SizedBox(
              height: 60.h,
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
                        backgroundImage: () {
                          final profileUrl =
                              video.profilePicture != null &&
                                  video.profilePicture!.isNotEmpty
                              ? ImageUtils.getProfileImageUrl(
                                  video.profilePicture!,
                                  cacheBust:
                                      video.updatedAt.millisecondsSinceEpoch,
                                )
                              : null;
                          return profileUrl != null
                              ? NetworkImage(
                                  profileUrl,
                                  headers: ImageUtils.getProfileImageHeaders(
                                    profileUrl,
                                  ),
                                )
                              : null;
                        }(),
                        child:
                            video.profilePicture == null ||
                                video.profilePicture!.isEmpty
                            ? Text(
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
                              )
                            : null,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          '@${video.userUsername.toLowerCase()}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
}

// User card for search results
class _UserCard extends StatelessWidget {
  const _UserCard({required this.user});

  final UserModel user;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final profileUrl = ImageUtils.getProfileImageUrl(
      user.profilePicture ?? user.avatarUrl ?? '',
      cacheBust: user.updatedAt?.millisecondsSinceEpoch,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          context.push('/users/${user.username}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 32,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                backgroundImage: profileUrl != null
                    ? NetworkImage(
                        profileUrl,
                        headers: ImageUtils.getProfileImageHeaders(profileUrl),
                      )
                    : null,
                child:
                    (user.profilePicture == null ||
                            user.profilePicture!.isEmpty) &&
                        (user.avatarUrl == null || user.avatarUrl!.isEmpty)
                    ? Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username.toLowerCase()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    if (user.bio != null && user.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        user.bio!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (user.followers > 0) ...[
                          Icon(
                            Icons.people,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatCount(user.followers)} followers',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                        if (user.totalVideos > 0) ...[
                          if (user.followers > 0) const SizedBox(width: 16),
                          Icon(
                            Icons.video_library,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant.withOpacity(0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${_formatCount(user.totalVideos)} videos',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
