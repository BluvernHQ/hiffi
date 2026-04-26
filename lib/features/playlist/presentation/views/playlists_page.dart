import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/hiffi_logo.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/offline_info_state.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';
import '../../../video/domain/models/video_model.dart';
import '../../domain/models/playlist_models.dart';
import '../viewmodels/playlist_view_model.dart';

/// Brand red aligned with the rest of the app.
const Color _kHiffiRed = Color(0xFFED1C2F);

/// Stacked playlist preview: square “cubes”, white stroke, overlap like design refs.
const double _kStackCube = 52;
const double _kStackOverlap = 28; // ~54% of cube width → strong overlap
const double _kStackCubeRadius = 14;
const double _kStackBorder = 1;

class PlaylistsPage extends StatefulWidget {
  const PlaylistsPage({super.key});

  @override
  State<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends State<PlaylistsPage> {
  bool _initialLoadPending = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await context.read<AnalyticsService>().logEvent(
          context,
          'playlist_list_viewed',
        );
      } catch (_) {
        // Analytics should never block primary page load.
      }
      if (!mounted) return;
      try {
        await context.read<PlaylistViewModel>().loadPlaylists();
      } finally {
        if (mounted) {
          setState(() {
            _initialLoadPending = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlaylistViewModel>();
    final authRepository = context.watch<AuthRepository>();
    final userViewModel = context.watch<UserViewModel>();
    final user = authRepository.currentUser != null
        ? userViewModel.currentUser
        : null;

    return MainScaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        leadingWidth: 56,
        titleSpacing: 0,
        surfaceTintColor: Colors.transparent,
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
        title: Row(
          children: [
            const HiffiLogo(size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.push('/search'),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE5E5E5)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withValues(alpha: 0.45),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Search…',
                          style: TextStyle(
                            fontSize: 15,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: IconButton(
                tooltip: 'Your profile',
                onPressed: () {
                  context.push('/users/${user.username}');
                },
                icon: HiffiAvatar(
                  imageUrl: user.profilePicture,
                  size: 36,
                  fallbackText: user.name.isNotEmpty
                      ? user.name
                      : user.username,
                ),
              ),
            )
          else
            TextButton(
              onPressed: () {
                context.push(
                  '/login?returnTo=${Uri.encodeComponent('/playlists')}',
                );
              },
              child: const Text('Sign in'),
            ),
        ],
      ),
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: vm.loadPlaylists,
            color: _kHiffiRed,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const _CollectionsHeroCard(),
                      const SizedBox(height: 16),
                      if ((vm.isLoadingList || _initialLoadPending) &&
                          vm.playlists.isEmpty) ...[
                        const _PlaylistCardShimmer(),
                        const SizedBox(height: 12),
                        const _PlaylistCardShimmer(),
                        const SizedBox(height: 12),
                        const _PlaylistCardShimmer(),
                      ] else if (vm.listError != null && vm.playlists.isEmpty)
                        _ErrorCard(
                          message: vm.listError!,
                          isInformational: isOfflineErrorMessage(vm.listError!),
                          onRetry: vm.loadPlaylists,
                        )
                      else if (vm.playlists.isEmpty)
                        const _EmptyPlaylistsCard()
                      else
                        ...vm.playlists.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _PlaylistCard(
                              playlist: p,
                              detail: vm.detail(p.playlistId),
                              videoLookup: vm.cachedVideo,
                              onOpen: () =>
                                  context.push('/playlists/${p.playlistId}'),
                              onQuickPlay: () {
                                final d = vm.detail(p.playlistId);
                                if (d == null || d.items.isEmpty) return;
                                final first = d.items.first.videoId;
                                context.go(
                                  '/watch/$first?playlist=${p.playlistId}&pindex=0',
                                );
                              },
                            ),
                          ),
                        ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionsHeroCard extends StatelessWidget {
  const _CollectionsHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _kHiffiRed.withValues(alpha: 0.25)),
            ),
            child: const Text(
              'COLLECTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: _kHiffiRed,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'My playlists',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111111),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Curated collections you can jump into from any watch page.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF6B6B6B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.playlist,
    required this.detail,
    required this.videoLookup,
    required this.onOpen,
    required this.onQuickPlay,
  });

  final PlaylistSummary playlist;
  final PlaylistDetail? detail;
  final VideoModel? Function(String id) videoLookup;
  final VoidCallback onOpen;
  final VoidCallback onQuickPlay;

  int get _videoCount =>
      playlist.itemCount ?? (detail == null ? 0 : detail!.items.length);

  bool get _canPlay => detail != null && detail!.items.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final description = (playlist.description?.trim().isNotEmpty ?? false)
        ? playlist.description!.trim()
        : 'Curated collection you can jump into anytime.';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E5E5)),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PlaylistThumbStack(detail: detail, videoLookup: videoLookup),
                  const Spacer(),
                  Semantics(
                    label: 'Play playlist ${playlist.title}',
                    button: true,
                    child: Material(
                      color: _kHiffiRed,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _canPlay ? onQuickPlay : null,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: _canPlay
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                playlist.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: Color(0xFF6B6B6B),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_videoCount == 1 ? '1 video' : '$_videoCount videos'} · Updated ${playlistUpdatedRelative(playlist)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8A8A8A)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaylistThumbStack extends StatelessWidget {
  const _PlaylistThumbStack({required this.detail, required this.videoLookup});

  final PlaylistDetail? detail;
  final VideoModel? Function(String id) videoLookup;

  @override
  Widget build(BuildContext context) {
    final ids =
        detail?.items
            .map((e) => e.videoId)
            .where((id) => id.isNotEmpty)
            .toList() ??
        <String>[];

    if (ids.isEmpty) {
      return Center(
        child: _StackImageCube(
          video: null,
          placeholder: Icon(
            Icons.queue_music_rounded,
            size: 26,
            color: Colors.grey.shade500,
          ),
        ),
      );
    }

    // Up to 3 photo cubes; if more videos exist, top layer is a light “+N” cube (design refs).
    const maxPhotoCubes = 3;
    final photoCount = math.min(maxPhotoCubes, ids.length);
    final extraCount = ids.length > maxPhotoCubes ? ids.length - maxPhotoCubes : 0;
    final slotCount = photoCount + (extraCount > 0 ? 1 : 0);
    final stackWidth = _kStackOverlap * (slotCount - 1) + _kStackCube;

    final layers = <Widget>[];
    for (var i = 0; i < photoCount; i++) {
      layers.add(
        Positioned(
          left: i * _kStackOverlap,
          top: 0,
          child: _StackImageCube(
            video: videoLookup(ids[i]),
            fallbackThumbnail: detail?.items[i].videoThumbnail,
          ),
        ),
      );
    }
    if (extraCount > 0) {
      layers.add(
        Positioned(
          left: photoCount * _kStackOverlap,
          top: 0,
          child: _StackOverflowCube(count: extraCount),
        ),
      );
    }

    return SizedBox(
      width: stackWidth,
      height: _kStackCube,
      child: Stack(
        clipBehavior: Clip.none,
        children: layers,
      ),
    );
  }
}

class _StackImageCube extends StatelessWidget {
  const _StackImageCube({
    required this.video,
    this.placeholder,
    this.fallbackThumbnail,
  });

  final VideoModel? video;
  final Widget? placeholder;
  final String? fallbackThumbnail;

  @override
  Widget build(BuildContext context) {
    final url = ImageUtils.getVideoThumbnailUrl(
      video?.videoThumbnail ?? fallbackThumbnail,
    );
    return SizedBox(
      width: _kStackCube,
      height: _kStackCube,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(
                math.max(0, _kStackCubeRadius - _kStackBorder),
              ),
              child: url == null || url.isEmpty
                  ? placeholder ??
                      ColoredBox(
                        color: const Color(0xFF2A2A2A),
                        child: Icon(
                          Icons.videocam_outlined,
                          color: Colors.grey.shade600,
                          size: 24,
                        ),
                      )
                  : Image.network(
                      url,
                      width: _kStackCube,
                      height: _kStackCube,
                      fit: BoxFit.cover,
                      headers: ImageUtils.getVideoThumbnailHeaders(),
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: const Color(0xFF2A2A2A),
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: Colors.grey.shade600,
                          size: 24,
                        ),
                      ),
                    ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_kStackCubeRadius),
                  border: Border.all(color: Colors.white, width: _kStackBorder),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StackOverflowCube extends StatelessWidget {
  const _StackOverflowCube({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _kStackCube,
      height: _kStackCube,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_kStackCubeRadius),
          border: Border.all(color: Colors.white, width: _kStackBorder),
          color: const Color(0xFFECECEC),
        ),
        child: Center(
          child: Text(
            '+$count',
            style: TextStyle(
              fontSize: count >= 10 ? 15 : 17,
              fontWeight: FontWeight.w800,
              color: Colors.grey.shade700,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistCardShimmer extends StatelessWidget {
  const _PlaylistCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE7E7EA),
      highlightColor: const Color(0xFFF7F7FA),
      period: const Duration(milliseconds: 1300),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE8E8EC)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(
                      3,
                      (index) => Transform.translate(
                        offset: Offset(index == 0 ? 0 : -10.0 * index, 0),
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(_kStackCubeRadius),
                            border: Border.all(
                              color: const Color(0xFFFDFDFD),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              height: 16,
              width: 170,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 12,
              width: 220,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  height: 12,
                  width: 146,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const Spacer(),
                Container(
                  height: 10,
                  width: 72,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
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

class _EmptyPlaylistsCard extends StatelessWidget {
  const _EmptyPlaylistsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.playlist_add_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            'No playlists yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add videos from any watch page — tap Add to playlist on a video you love.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({
    required this.message,
    this.isInformational = false,
    this.onRetry,
  });

  final String message;
  final bool isInformational;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (isInformational) {
      return OfflineInfoState(
        message: 'Connect to the internet to view and manage your playlists.',
        actionLabel: onRetry == null ? null : 'Try Again',
        onAction: onRetry,
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: Colors.grey.shade600),
          const SizedBox(height: 12),
          Text(
            isInformational
                ? 'You are offline right now'
                : 'Couldn’t load playlists',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            isInformational
                ? 'Connect to the internet to view and manage your playlists.'
                : message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

String playlistUpdatedRelative(PlaylistSummary playlist) {
  final value = playlist.updatedAt;
  if (value == null || value.isEmpty) return 'recently';
  final updated = DateTime.tryParse(value);
  if (updated == null) return 'recently';
  final diff = DateTime.now().difference(updated);
  if (diff.inSeconds < 60) return 'less than a minute ago';
  if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  }
  if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  }
  if (diff.inDays < 14) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  }
  return '${(diff.inDays / 7).floor()} week(s) ago';
}
