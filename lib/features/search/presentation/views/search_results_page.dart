import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/widgets/network_page_shell.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../../core/utils/responsive.dart';
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
  late final ScrollController _allScrollController;
  late final ScrollController _videosScrollController;
  late final ScrollController _usersScrollController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _allScrollController = ScrollController()..addListener(_onAllScroll);
    _videosScrollController = ScrollController()..addListener(_onVideosScroll);
    _usersScrollController = ScrollController()..addListener(_onUsersScroll);

    // Perform search on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SearchViewModel>().search(widget.query);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _allScrollController.removeListener(_onAllScroll);
    _videosScrollController.removeListener(_onVideosScroll);
    _usersScrollController.removeListener(_onUsersScroll);
    _allScrollController.dispose();
    _videosScrollController.dispose();
    _usersScrollController.dispose();
    super.dispose();
  }

  bool _isNearBottom(ScrollController controller, {double threshold = 320}) {
    if (!controller.hasClients) return false;
    final max = controller.position.maxScrollExtent;
    final current = controller.position.pixels;
    return max - current <= threshold;
  }

  void _onAllScroll() {
    if (!_isNearBottom(_allScrollController)) return;
    final vm = context.read<SearchViewModel>();
    vm.loadMoreVideos();
    vm.loadMoreUsers();
  }

  void _onVideosScroll() {
    if (!_isNearBottom(_videosScrollController)) return;
    context.read<SearchViewModel>().loadMoreVideos();
  }

  void _onUsersScroll() {
    if (!_isNearBottom(_usersScrollController)) return;
    context.read<SearchViewModel>().loadMoreUsers();
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
      body: NetworkPageShell(
        hasCachedContent: searchViewModel.hasResults,
        isLoading: searchViewModel.isLoading && !searchViewModel.hasResults,
        emptyDescription:
            'Connect to the internet and try again to search on Hiffi.',
        onRetry: () => searchViewModel.search(widget.query),
        child: searchViewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : searchViewModel.error != null
            ? _buildErrorState(searchViewModel)
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
      ),
    );
  }

  Widget _buildErrorState(SearchViewModel viewModel) {
    final error = viewModel.error ?? '';
    final isNoInternet = isOfflineErrorMessage(error);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isNoInternet
                    ? Theme.of(
                        context,
                      ).colorScheme.primaryContainer.withOpacity(0.3)
                    : Theme.of(
                        context,
                      ).colorScheme.errorContainer.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNoInternet
                    ? Icons.wifi_off_rounded
                    : Icons.error_outline_rounded,
                size: 64,
                color: isNoInternet
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              isNoInternet
                  ? 'You are offline right now'
                  : 'Oops! Something went wrong',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                isNoInternet
                    ? 'Please check your connection and try again to search on Hiffi.'
                    : 'We encountered an error while searching. Please try again later.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                viewModel.search(widget.query);
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text(
                'Try Again',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
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
        controller: _allScrollController,
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
                  crossAxisCount: responsiveGridColumns(context),
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
          SliverToBoxAdapter(
            child: _buildBottomLoader(
              show: viewModel.isLoadingMoreUsers || viewModel.isLoadingMoreVideos,
            ),
          ),
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
        controller: _videosScrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12.w, 16.h, 12.w, 16.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsiveGridColumns(context),
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
          SliverToBoxAdapter(
            child: _buildBottomLoader(show: viewModel.isLoadingMoreVideos),
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
        controller: _usersScrollController,
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
          SliverToBoxAdapter(
            child: _buildBottomLoader(show: viewModel.isLoadingMoreUsers),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomLoader({required bool show}) {
    if (!show) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CircularProgressIndicator()),
    );
  }

  double _calculateAspectRatio(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final columns = responsiveGridColumns(context).toDouble();
    final cardWidth = (screenWidth - 12.w * 2 - 12.w * (columns - 1)) / columns;
    final thumbnailHeight = cardWidth * 9 / 16;
    final textHeight = responsiveGridTextSectionHeight(context);
    final totalHeight = thumbnailHeight + 8.h + textHeight;
    return cardWidth / totalHeight;
  }
}

// Grid video card (reused from home page pattern)
class _GridVideoCard extends StatelessWidget {
  const _GridVideoCard({required this.video});

  final VideoModel video;

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
                child: Stack(
                        fit: StackFit.expand,
                        children: [
                          HiffiVideoThumbnail(
                            thumbnailPath: video.videoThumbnail,
                            fit: BoxFit.cover,
                          ),
                          // Processing indicator (top right)
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
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '• ',
                                      style: TextStyle(
                                        color: Colors.redAccent,
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
            // Title and User section – responsive for tablet (YouTube-style: 2 lines + ellipsis)
            SizedBox(
              height: responsiveGridTextSectionHeight(context),
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
                      Expanded(
                        child: Text(
                          '@${video.userUsername.toLowerCase()}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
    // Use updatedAt timestamp for cache busting, or current timestamp if not available
    // This ensures we always get the latest profile picture
    final cacheBust =
        user.updatedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

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
              HiffiAvatar(
                imageUrl: user.profilePicture ?? user.avatarUrl,
                size: 64,
                fallbackText: user.name,
                cacheBust: cacheBust,
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
