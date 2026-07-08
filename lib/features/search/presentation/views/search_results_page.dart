import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../../core/widgets/network_page_shell.dart';
import '../../../../core/widgets/offline_empty_state.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
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
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final ScrollController _allScrollController;
  late final ScrollController _videosScrollController;
  late final ScrollController _usersScrollController;

  String get _query => widget.query.trim();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController = TextEditingController(text: widget.query);
    _searchFocusNode = FocusNode();
    _allScrollController = ScrollController()..addListener(_onAllScroll);
    _videosScrollController = ScrollController()..addListener(_onVideosScroll);
    _usersScrollController = ScrollController()..addListener(_onUsersScroll);

    if (_query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SearchViewModel>().search(_query);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(SearchResultsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _searchController.text = widget.query;
      if (_query.isNotEmpty) {
        context.read<SearchViewModel>().search(_query);
      } else {
        context.read<SearchViewModel>().clear();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _allScrollController.removeListener(_onAllScroll);
    _videosScrollController.removeListener(_onVideosScroll);
    _usersScrollController.removeListener(_onUsersScroll);
    _allScrollController.dispose();
    _videosScrollController.dispose();
    _usersScrollController.dispose();
    super.dispose();
  }

  void _submitSearch([String? value]) {
    final trimmed = (value ?? _searchController.text).trim();
    if (trimmed.isEmpty) return;
    _searchFocusNode.unfocus();
    if (trimmed == _query) {
      context.read<SearchViewModel>().search(trimmed);
      return;
    }
    context.go('/search?q=${Uri.encodeComponent(trimmed)}');
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
    final hasQuery = _query.isNotEmpty;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: _submitSearch,
          decoration: InputDecoration(
            hintText: 'Search videos and creators',
            border: InputBorder.none,
            isDense: true,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                      if (hasQuery) {
                        context.go('/search');
                      } else {
                        _searchFocusNode.requestFocus();
                      }
                    },
                    tooltip: 'Clear',
                  )
                : null,
          ),
          style: theme.textTheme.bodyLarge,
          onChanged: (_) => setState(() {}),
        ),
        bottom: hasQuery
            ? PreferredSize(
                preferredSize: const Size.fromHeight(96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!searchViewModel.isLoading &&
                        searchViewModel.error == null &&
                        searchViewModel.hasResults)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Text(
                          _resultSummary(searchViewModel),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: _SearchTabBar(
                        controller: _tabController,
                        videoCount: searchViewModel.videoCount,
                        userCount: searchViewModel.userCount,
                      ),
                    ),
                  ],
                ),
              )
            : null,
      ),
      body: NetworkPageShell(
        hasCachedContent: searchViewModel.hasResults,
        isLoading: searchViewModel.isLoading && !searchViewModel.hasResults,
        emptyDescription:
            'Connect to the internet and try again to search on Hiffi.',
        onRetry: () async {
          if (_query.isNotEmpty) await searchViewModel.search(_query);
        },
        child: !hasQuery
            ? _SearchLanding(onSubmit: _submitSearch)
            : searchViewModel.isLoading && !searchViewModel.hasResults
            ? const VideoListShimmer(itemCount: 8)
            : searchViewModel.error != null && !searchViewModel.hasResults
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

  String _resultSummary(SearchViewModel vm) {
    final total = vm.videoCount + vm.userCount;
    if (total <= 0) return 'Results for "$_query"';
    final label = total == 1 ? '1 result' : '$total results';
    return '$label for "$_query"';
  }

  Widget _buildErrorState(SearchViewModel viewModel) {
    final error = viewModel.error ?? '';
    final isNoInternet = isOfflineErrorMessage(error);

    return OfflineEmptyState(
      title: isNoInternet ? "You're offline" : 'Search unavailable',
      description: isNoInternet
          ? 'Check your connection and try searching again.'
          : error,
      onTryAgain: () => viewModel.search(_query),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 16),
            Text(
              'No results for "$_query"',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try different keywords, a creator name, or a shorter phrase.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.8,
                ),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required VoidCallback? onSeeAll,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }

  Widget _buildAllResults(SearchViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: () => viewModel.search(_query),
      child: CustomScrollView(
        controller: _allScrollController,
        slivers: [
          if (viewModel.videoResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                title: 'Videos (${viewModel.videoCount})',
                onSeeAll: () => _tabController.animateTo(1),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 8.h),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: responsiveGridColumns(context),
                  mainAxisSpacing: 12.h,
                  crossAxisSpacing: 12.w,
                  childAspectRatio: _calculateAspectRatio(context),
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return _GridVideoCard(video: viewModel.videoResults[index]);
                }, childCount: viewModel.videoResults.length),
              ),
            ),
          ],
          if (viewModel.userResults.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                title: 'Creators (${viewModel.userCount})',
                onSeeAll: () => _tabController.animateTo(2),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final user = viewModel.userResults[index];
                return _UserCard(
                  user: user,
                  showDivider: index < viewModel.userResults.length - 1,
                );
              }, childCount: viewModel.userResults.length),
            ),
          ],
          SliverToBoxAdapter(
            child: _buildBottomLoader(
              show: viewModel.isLoadingMoreUsers || viewModel.isLoadingMoreVideos,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }

  Widget _buildVideoResults(SearchViewModel viewModel) {
    if (viewModel.videoResults.isEmpty) {
      return _buildTabEmptyState(
        icon: Icons.play_circle_outline_rounded,
        message: 'No videos for "$_query"',
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.searchVideos(_query),
      child: CustomScrollView(
        controller: _videosScrollController,
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12.w, 12.h, 12.w, 16.h),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: responsiveGridColumns(context),
                mainAxisSpacing: 12.h,
                crossAxisSpacing: 12.w,
                childAspectRatio: _calculateAspectRatio(context),
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                return _GridVideoCard(video: viewModel.videoResults[index]);
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
      return _buildTabEmptyState(
        icon: Icons.person_search_rounded,
        message: 'No creators for "$_query"',
      );
    }

    return RefreshIndicator(
      onRefresh: () => viewModel.searchUsers(_query),
      child: CustomScrollView(
        controller: _usersScrollController,
        slivers: [
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final user = viewModel.userResults[index];
              return _UserCard(
                user: user,
                showDivider: index < viewModel.userResults.length - 1,
              );
            }, childCount: viewModel.userResults.length),
          ),
          SliverToBoxAdapter(
            child: _buildBottomLoader(show: viewModel.isLoadingMoreUsers),
          ),
        ],
      ),
    );
  }

  Widget _buildTabEmptyState({
    required IconData icon,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomLoader({required bool show}) {
    if (!show) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
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

class _SearchLanding extends StatelessWidget {
  const _SearchLanding({required this.onSubmit});

  final void Function(String value) onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Icon(
          Icons.search_rounded,
          size: 48,
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 16),
        Text(
          'Search Hiffi',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Find videos, creators, and channels across the platform.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
            height: 1.45,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'Try searching for',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final term in const [
              'music',
              'comedy',
              'gaming',
              'podcast',
              'live',
            ])
              ActionChip(
                label: Text(term),
                onPressed: () => onSubmit(term),
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.65,
                ),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SearchTabBar extends StatelessWidget {
  const _SearchTabBar({
    required this.controller,
    required this.videoCount,
    required this.userCount,
  });

  final TabController controller;
  final int videoCount;
  final int userCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: controller,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: EdgeInsets.zero,
        indicator: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        labelColor: theme.colorScheme.onSurface,
        unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        tabs: [
          const Tab(text: 'All'),
          Tab(text: videoCount > 0 ? 'Videos ($videoCount)' : 'Videos'),
          Tab(text: userCount > 0 ? 'Creators ($userCount)' : 'Creators'),
        ],
      ),
    );
  }
}

class _GridVideoCard extends StatelessWidget {
  const _GridVideoCard({required this.video});

  final VideoModel video;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          unawaited(
            AnalyticsCapture.videoOpened(
              context,
              openUiName: AnalyticsTags.openedVideoFromSearch,
              screenName: 'search',
              videoId: video.videoId,
              videoTitle: video.videoTitle,
              source: 'search',
            ),
          );
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    HiffiVideoThumbnail(
                      thumbnailPath: video.videoThumbnail,
                      fit: BoxFit.cover,
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
                            color: Colors.black.withValues(alpha: 0.7),
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
              height: responsiveGridTextSectionHeight(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant
                                .withValues(alpha: 0.7),
                            fontSize: responsiveGridSubtitleFontSize(context),
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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, this.showDivider = true});

  final UserModel user;
  final bool showDivider;

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    }
    if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cacheBust =
        user.updatedAt?.millisecondsSinceEpoch ??
        DateTime.now().millisecondsSinceEpoch;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/users/${user.username}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  HiffiAvatar(
                    imageUrl: user.profilePicture ?? user.avatarUrl,
                    size: 48,
                    fallbackText: user.name,
                    cacheBust: cacheBust,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${user.username.toLowerCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            user.bio!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.72),
                            ),
                          ),
                        ],
                        if (user.followers > 0 || user.totalVideos > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (user.followers > 0)
                                '${_formatCount(user.followers)} followers',
                              if (user.totalVideos > 0)
                                '${_formatCount(user.totalVideos)} videos',
                            ].join(' · '),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.65),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.45,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 76,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
      ],
    );
  }
}
