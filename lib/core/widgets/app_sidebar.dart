import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/auth_user.dart';
import '../../features/playlist/presentation/viewmodels/playlist_view_model.dart';
import '../../features/playlist/domain/models/playlist_models.dart';
import '../../features/video/domain/models/video_model.dart';
import '../../features/user/presentation/viewmodels/user_view_model.dart';
import '../../features/user/domain/models/user_model.dart';
import '../analytics/first_party_analytics_service.dart';
import '../routes/watch_route_extra.dart';
import 'hiffi_image.dart';
import 'hiffi_logo.dart';

class AppSidebar extends StatefulWidget {
  final Widget child;
  final String currentRoute;
  final bool isAuthenticated;

  const AppSidebar({
    super.key,
    required this.child,
    required this.currentRoute,
    this.isAuthenticated = false,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();

  static _AppSidebarState? of(BuildContext context) {
    return context.findAncestorStateOfType<_AppSidebarState>();
  }
}

class _AppSidebarState extends State<AppSidebar>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _animation;
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOutExpo,
    );
    _animationController.value = 0;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void toggleSidebar() {
    final opening = !_isExpanded;
    setState(() {
      _isExpanded = opening;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
    if (opening) {
      context.read<PlaylistViewModel>().loadCuratedPlaylists(
        silent: true,
        force: true,
      );
    }
  }

  void _toggleSidebar() => toggleSidebar();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authRepository = context.watch<AuthRepository>();
    final user = authRepository.currentUser;
    final userViewModel = context.watch<UserViewModel>();
    final playlistViewModel = context.watch<PlaylistViewModel>();
    final currentUserModel = userViewModel.currentUser;

    // Only auto-fetch once per app lifetime (or until TTL refresh is requested elsewhere).
    // Curated can legitimately be empty; don't treat empty as "not loaded".
    if (playlistViewModel.curatedLastFetchedAt == null &&
        !playlistViewModel.isLoadingCurated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<PlaylistViewModel>().loadCuratedPlaylists(
            silent: true,
            force: false,
          );
        }
      });
    }

    return Stack(
      children: [
        // Main content
        widget.child,

        // Backdrop blur overlay
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            if (_animation.value == 0) return const SizedBox.shrink();
            return Positioned.fill(
              child: GestureDetector(
                onTap: _toggleSidebar,
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 4 * _animation.value,
                    sigmaY: 4 * _animation.value,
                  ),
                  child: Container(
                    color: Colors.black.withOpacity(0.2 * _animation.value),
                  ),
                ),
              ),
            );
          },
        ),

        // Sidebar overlay
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final offset = -280 * (1 - _animation.value);
            return Positioned(
              left: offset,
              top: 0,
              bottom: 0,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: 280,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface.withOpacity(0.95),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1 * _animation.value),
                        blurRadius: 24,
                        offset: const Offset(8, 0),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(32),
                      bottomRight: Radius.circular(32),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                24,
                                16,
                                16,
                                16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const HiffiLogo(size: 32),
                                  IconButton(
                                    onPressed: _toggleSidebar,
                                    icon: const Icon(Icons.close_rounded),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme
                                          .colorScheme
                                          .surfaceVariant
                                          .withOpacity(0.5),
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Navigation Items
                            Expanded(
                              child: ListView(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                children: [
                                  const _SidebarSectionHeader(label: 'EXPLORE'),
                                  _SidebarItem(
                                    icon: Icons.home_outlined,
                                    activeIcon: Icons.home_outlined,
                                    label: 'Home',
                                    isActive: widget.currentRoute == '/home',
                                    onTap: () {
                                      unawaited(
                                        context
                                            .read<FirstPartyAnalyticsService>()
                                            .capture(
                                              r'$click',
                                              elementUiName:
                                                  'sidebar-home-button',
                                              screenName: 'sidebar',
                                            ),
                                      );
                                      _toggleSidebar();
                                      if (widget.currentRoute != '/home') {
                                        Future.delayed(
                                          const Duration(milliseconds: 200),
                                          () {
                                            if (mounted) context.go('/home');
                                          },
                                        );
                                      }
                                    },
                                  ),
                                  _CuratedPlaylistsSection(
                                    playlists:
                                        playlistViewModel.curatedPlaylists,
                                    onTapPlaylist: (playlistId) async {
                                      final vm = context
                                          .read<PlaylistViewModel>();
                                      try {
                                        final detail = await vm
                                            .loadCuratedPlaylistDetail(
                                              playlistId,
                                              silent: true,
                                            );
                                        final firstItem =
                                            detail?.items.isNotEmpty == true
                                            ? detail!.items.first
                                            : null;
                                        if (firstItem == null ||
                                            firstItem.videoId.isEmpty) {
                                          return;
                                        }
                                        final video =
                                            vm.cachedVideo(firstItem.videoId) ??
                                            VideoModel.preview(
                                              videoId: firstItem.videoId,
                                              title: firstItem.videoTitle ?? '',
                                              thumbnail:
                                                  firstItem.videoThumbnail ??
                                                  '',
                                            );
                                        final session = PlaylistSession(
                                          playlistId: detail!.playlistId,
                                          title: detail.title,
                                          videoIds: detail.items
                                              .map((e) => e.videoId)
                                              .toList(),
                                          currentIndex: 0,
                                          autoplay: true,
                                        );
                                        _toggleSidebar();
                                        Future.delayed(
                                          const Duration(milliseconds: 200),
                                          () {
                                            if (!mounted) return;
                                            context.push(
                                              '/watch/${firstItem.videoId}?playlist=$playlistId&pindex=0&curated=1',
                                              extra: WatchRouteExtra(
                                                video: video,
                                                playlistSession: session,
                                              ),
                                            );
                                          },
                                        );
                                      } catch (_) {
                                        // Ignore and keep sidebar responsive.
                                      }
                                    },
                                  ),
                                  if (widget.isAuthenticated) ...[
                                    const _SidebarSectionHeader(
                                      label: 'YOUR ACTIVITY',
                                    ),
                                    _SidebarItem(
                                      icon: Icons.history_rounded,
                                      activeIcon: Icons.history_rounded,
                                      label: 'History',
                                      isActive:
                                          widget.currentRoute ==
                                          '/watch-history',
                                      onTap: () {
                                        unawaited(
                                          context
                                              .read<
                                                FirstPartyAnalyticsService
                                              >()
                                              .capture(
                                                r'$click',
                                                elementUiName:
                                                    'sidebar-history-link',
                                                screenName: 'sidebar',
                                              ),
                                        );
                                        _toggleSidebar();
                                        if (widget.currentRoute !=
                                            '/watch-history') {
                                          Future.delayed(
                                            const Duration(milliseconds: 200),
                                            () {
                                              if (mounted) {
                                                context.go('/watch-history');
                                              }
                                            },
                                          );
                                        }
                                      },
                                    ),
                                    _SidebarItem(
                                      icon: Icons.thumb_up_outlined,
                                      activeIcon: Icons.thumb_up_outlined,
                                      label: 'Liked Videos',
                                      isActive: widget.currentRoute == '/liked',
                                      onTap: () {
                                        unawaited(
                                          context
                                              .read<
                                                FirstPartyAnalyticsService
                                              >()
                                              .capture(
                                                r'$click',
                                                elementUiName:
                                                    'sidebar-liked-videos-link',
                                                screenName: 'sidebar',
                                              ),
                                        );
                                        _toggleSidebar();
                                        if (widget.currentRoute != '/liked') {
                                          Future.delayed(
                                            const Duration(milliseconds: 200),
                                            () {
                                              if (mounted) {
                                                context.go('/liked');
                                              }
                                            },
                                          );
                                        }
                                      },
                                    ),
                                    _SidebarItem(
                                      icon: Icons.queue_music_outlined,
                                      activeIcon: Icons.queue_music_outlined,
                                      label: 'Playlists',
                                      isActive:
                                          widget.currentRoute == '/playlists',
                                      onTap: () {
                                        unawaited(
                                          context
                                              .read<
                                                FirstPartyAnalyticsService
                                              >()
                                              .capture(
                                                r'$click',
                                                elementUiName:
                                                    'sidebar-playlists-link',
                                                screenName: 'sidebar',
                                              ),
                                        );
                                        _toggleSidebar();
                                        if (widget.currentRoute !=
                                            '/playlists') {
                                          Future.delayed(
                                            const Duration(milliseconds: 200),
                                            () {
                                              if (mounted) {
                                                context.go('/playlists');
                                              }
                                            },
                                          );
                                        }
                                      },
                                    ),
                                    _SidebarItem(
                                      icon: Icons.person_outline_rounded,
                                      activeIcon: Icons.person_outline_rounded,
                                      label: 'Following',
                                      isActive:
                                          widget.currentRoute == '/following',
                                      onTap: () {
                                        unawaited(
                                          context
                                              .read<
                                                FirstPartyAnalyticsService
                                              >()
                                              .capture(
                                                r'$click',
                                                elementUiName:
                                                    'sidebar-following-link',
                                                screenName: 'sidebar',
                                              ),
                                        );
                                        _toggleSidebar();
                                        if (widget.currentRoute !=
                                            '/following') {
                                          Future.delayed(
                                            const Duration(milliseconds: 200),
                                            () {
                                              if (mounted) {
                                                context.go('/following');
                                              }
                                            },
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            // Footer / Profile Section
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildHelpLegalEntry(context),
                                _buildProfileSection(
                                  context,
                                  user,
                                  currentUserModel,
                                ),
                                _buildVersionFooter(context),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHelpLegalEntry(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = widget.currentRoute == '/help-legal';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withOpacity(0.45),
            width: 1,
          ),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          _toggleSidebar();
          Future.delayed(const Duration(milliseconds: 200), () {
            if (!mounted) return;
            context.push('/help-legal');
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.help_outline_rounded,
                size: 17,
                color: isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withOpacity(0.82),
              ),
              const SizedBox(width: 8),
              Text(
                'Help & Legal',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12.5,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant.withOpacity(0.82),
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(
    BuildContext context,
    AuthUser? user,
    UserModel? userModel,
  ) {
    final theme = Theme.of(context);

    if (user == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.3),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const Text(
              'Join the Hiffi community!',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                context.push('/login');
                _toggleSidebar();
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }

    // Use profile picture from userModel if it's available, otherwise fallback to auth user
    final profilePicture = userModel?.profilePicture ?? user.profilePicture;
    final displayName = userModel?.name ?? user.name ?? 'Hiffi User';
    final displayUsername = userModel?.username ?? user.username ?? 'user';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () {
                    _toggleSidebar();
                    context.push('/users/$displayUsername');
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      children: [
                        HiffiAvatar(
                          imageUrl: profilePicture,
                          size: 48,
                          fallbackText: displayName,
                          cacheBust:
                              userModel?.updatedAt?.millisecondsSinceEpoch,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                '@$displayUsername',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () async {
                  final shouldSignOut = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                  if (shouldSignOut == true && mounted) {
                    await context.read<AuthRepository>().signOut();
                    if (mounted) _toggleSidebar();
                  }
                },
                icon: const Icon(Icons.logout_rounded),
                color: theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVersionFooter(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Center(
        child: FutureBuilder<PackageInfo>(
          future: _packageInfoFuture,
          builder: (context, snapshot) {
            final info = snapshot.data;
            final versionText = info == null
                ? ' '
                : 'v${info.version}+${info.buildNumber}';

            return Text(
              versionText,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SidebarSectionHeader extends StatelessWidget {
  const _SidebarSectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          letterSpacing: 1.2,
          color: theme.colorScheme.onSurfaceVariant.withOpacity(0.65),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _CuratedPlaylistsSection extends StatelessWidget {
  const _CuratedPlaylistsSection({
    required this.playlists,
    required this.onTapPlaylist,
  });

  final List<PlaylistSummary> playlists;
  final void Function(String playlistId) onTapPlaylist;

  static const _sparkleColor = Color(0xFFE57373);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (playlists.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SidebarSectionHeader(label: 'CURATED MIX'),
        ...playlists.take(4).map((playlist) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onTapPlaylist(playlist.playlistId),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      size: 20,
                      color: _sparkleColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        playlist.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(
                        0.55,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.75)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? (activeIcon ?? icon) : icon,
                  color: theme.colorScheme.onSurface.withOpacity(
                    isActive ? 0.95 : 0.72,
                  ),
                  size: 22,
                ),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                    color: theme.colorScheme.onSurface.withOpacity(
                      isActive ? 0.95 : 0.88,
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
