import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../../core/routes/video_player_route_extra.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/network_page_shell.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/models/watch_history_item.dart';
import '../viewmodels/watch_history_view_model.dart';

/// Calendar section label for a watch timestamp (local calendar day).
String watchHistorySectionLabel(DateTime viewedAtUtc, DateTime nowLocal) {
  final local = viewedAtUtc.toLocal();
  final v = DateTime(local.year, local.month, local.day);
  final t = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);
  if (v == t) return 'Today';
  final y = t.subtract(const Duration(days: 1));
  if (v == y) return 'Yesterday';
  return DateFormat.yMMMMd().format(local);
}

List<Object> _buildRows(List<WatchHistoryItem> items) {
  if (items.isEmpty) return [];
  final now = DateTime.now();
  final rows = <Object>[];
  String? lastLabel;
  for (final it in items) {
    final label = watchHistorySectionLabel(it.viewedAt, now);
    if (label != lastLabel) {
      rows.add(label);
      lastLabel = label;
    }
    rows.add(it);
  }
  return rows;
}

/// 16:9 thumbnail width for history list rows: scales with screen, capped for tablets.
double _historyThumbnailWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return (w * 0.40).clamp(132.0, 220.0);
}

class WatchHistoryPage extends StatefulWidget {
  const WatchHistoryPage({super.key});

  @override
  State<WatchHistoryPage> createState() => _WatchHistoryPageState();
}

class _WatchHistoryPageState extends State<WatchHistoryPage> {
  static final _timeFormat = DateFormat.jm();

  late final ScrollController _scrollController;
  bool _shortFillScheduled = false;

  void _onScrollPosition() {
    if (!mounted) return;
    final vm = context.read<WatchHistoryViewModel>();
    if (!vm.hasMore || vm.isLoading) return;
    final connectivity = context.read<NetworkConnectivityService>();
    if (!connectivity.checkConnectivitySync()) return;
    if (!_scrollController.hasClients) return;

    final p = _scrollController.position;
    if (!p.hasViewportDimension) return;

    // Viewport taller than content: chain loads until we can scroll or the API returns a short page.
    if (p.maxScrollExtent <= 24) {
      vm.loadHistory();
      return;
    }

    final threshold = (p.maxScrollExtent * 0.22).clamp(180.0, 560.0);
    if (p.pixels >= p.maxScrollExtent - threshold) {
      vm.loadHistory();
    }
  }

  void _scheduleShortListFillIfNeeded() {
    final vm = context.read<WatchHistoryViewModel>();
    if (vm.items.isEmpty || !vm.hasMore || vm.isLoading || _shortFillScheduled) {
      return;
    }
    _shortFillScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _shortFillScheduled = false;
      if (!mounted) return;
      _onScrollPosition();
    });
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScrollPosition);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WatchHistoryViewModel>().loadHistory(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScrollPosition);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WatchHistoryViewModel>();

    final rows = _buildRows(vm.items);
    _scheduleShortListFillIfNeeded();

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
              if (sidebar == null) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.menu_rounded),
                onPressed: sidebar.toggleSidebar,
                tooltip: 'Menu',
              );
            },
          ),
          title: const Text('History'),
        ),
        child: NetworkPageShell(
          hasCachedContent: vm.items.isNotEmpty,
          isLoading: vm.isLoading && vm.items.isEmpty,
          emptyDescription:
              'Connect to the internet to view your watch history.',
          onRetry: () => vm.refresh(),
          child: SafeArea(
            child: RefreshIndicator(
              onRefresh: () => context.read<WatchHistoryViewModel>().refresh(),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (vm.isLoading && vm.items.isEmpty)
                    const SliverFillRemaining(
                      child: HistoryListShimmer(itemCount: 8),
                    )
                  else if (vm.errorMessage != null && vm.items.isEmpty)
                    SliverFillRemaining(
                      child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline_rounded,
                                    size: 64,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    'Something went wrong',
                                    style: Theme.of(context).textTheme.titleLarge,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    vm.errorMessage!,
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton.icon(
                                    onPressed: () => vm.refresh(),
                                    icon: const Icon(Icons.refresh_rounded),
                                    label: const Text('Try again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  )
                else if (vm.items.isEmpty)
                  SliverFillRemaining(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 64,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withValues(alpha: 0.6),
                            ),
                            SizedBox(height: 24.h),
                            Text(
                              'No watch history yet',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'Videos you open will appear here',
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 32.h),
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
                else ...[
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= rows.length) {
                            if (vm.hasMore && !vm.isLoading) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) vm.loadHistory();
                              });
                            }
                            if (vm.isLoading) {
                              return Padding(
                                padding: EdgeInsets.fromLTRB(
                                  0,
                                  8.h,
                                  0,
                                  32.h,
                                ),
                                child: const HistoryPaginationShimmer(),
                              );
                            }
                            return SizedBox(height: 72.h);
                          }

                          final row = rows[index];
                          if (row is String) {
                            return Padding(
                              padding: EdgeInsets.fromLTRB(4.w, 16.h, 4.w, 8.h),
                              child: Text(
                                row,
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                              ),
                            );
                          }

                          final item = row as WatchHistoryItem;
                          return _HistoryTile(
                            item: item,
                            timeLabel: _timeFormat.format(
                              item.viewedAt.toLocal(),
                            ),
                            onTap: () {
                              unawaited(
                                AnalyticsCapture.videoOpened(
                                  context,
                                  openUiName:
                                      AnalyticsTags.openedVideoFromHistory,
                                  screenName: 'watch_history',
                                  videoId: item.video.videoId,
                                  videoTitle: item.video.videoTitle,
                                  source: 'history',
                                ),
                              );
                              context.push(
                                '/video/${item.video.videoId}',
                                extra: VideoPlayerRouteExtra(
                                  video: item.video,
                                ),
                              );
                            },
                          );
                        },
                        childCount:
                            rows.length + (vm.hasMore ? 1 : 0),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.item,
    required this.timeLabel,
    required this.onTap,
  });

  final WatchHistoryItem item;
  final String timeLabel;
  final VoidCallback onTap;

  VideoModel get video => item.video;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbW = _historyThumbnailWidth(context);
    final thumbH = thumbW * 9 / 16;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: thumbW,
                  height: thumbH,
                  child: HiffiVideoThumbnail(
                    thumbnailPath: video.videoThumbnail,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.videoTitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                      maxLines: 2,
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
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            video.userUsername.isNotEmpty
                                ? '@${video.userUsername}'
                                : 'Unknown',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}
