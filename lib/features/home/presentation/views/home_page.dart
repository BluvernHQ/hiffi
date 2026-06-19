import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:in_app_update/in_app_update.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/network_page_shell.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../../../search/presentation/widgets/search_overlay.dart';
import '../../../../core/routes/watch_route_extra.dart';
import '../../../playlist/presentation/viewmodels/playlist_view_model.dart';
import '../../../mood/domain/models/mood_def.dart';
import '../../../mood/presentation/viewmodels/mood_feed_view_model.dart';
import '../../../mood/presentation/widgets/active_mood_bar.dart';
import '../../../mood/presentation/widgets/mood_picker_card.dart';
import '../../../playlist/domain/models/playlist_models.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/app_sidebar.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/hiffi_logo.dart';
import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../../core/analytics/first_party_analytics_service.dart';
import '../viewmodels/home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  StreamSubscription? _authSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchActive = false;
  bool _isCheckingUpdate = false;
  int _curatedShuffleSeed = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(clearViewedUser: true);
      _setupAuthListener();
      _checkForInAppUpdate();
      context.read<MoodFeedViewModel>().restoreFromStorage();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      context.read<PlaylistViewModel>().loadCuratedPlaylists(
        silent: true,
        force: true,
      );
      _curatedShuffleSeed = DateTime.now().millisecondsSinceEpoch;
    }
  }

  void _onSearchChanged(String query) {
    setState(() {}); // Update UI to show/hide clear button
  }

  void _onSuggestionTap(VideoModel video) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchActive = false;
    });
    // Navigate to video player
    context.push('/video/${video.videoId}', extra: video);
  }

  void _onViewAllResults() {
    final query = _searchController.text.trim();
    if (query.isNotEmpty) {
      unawaited(
        context.read<FirstPartyAnalyticsService>().capture(
          r'$click',
          elementUiName: 'search-overlay-view-all-results-button',
          screenName: 'search_overlay',
          properties: {'query': query},
        ),
      );
      context.push('/search?q=${Uri.encodeComponent(query)}');
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _isSearchActive = false;
      });
    }
  }

  void _clearSearch() {
    // If there's text, clear it first; otherwise close search
    if (_searchController.text.isNotEmpty) {
      _searchController.clear();
      _onSearchChanged('');
      _searchFocusNode.requestFocus();
    } else {
      _searchController.clear();
      _searchFocusNode.unfocus();
      setState(() {
        _isSearchActive = false;
      });
    }
  }

  void _activateSearch() {
    setState(() {
      _isSearchActive = true;
    });
    // Focus after a tiny delay to ensure the TextField is built
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _setupAuthListener() {
    final authRepository = context.read<AuthRepository>();
    _authSubscription = authRepository.authStateChanges().listen((user) {
      if (mounted) {
        // Don't clear viewed user on auth state changes, only reload data
        _loadData(clearViewedUser: false);
      }
    });
  }

  Future<void> _checkForInAppUpdate() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return;
    }

    if (_isCheckingUpdate) {
      return;
    }

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate().catchError((error) {
            _showUpdateMessage(
              'Update failed. Please try again later.',
            );
            return AppUpdateResult.inAppUpdateFailed;
          });
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate().then((_) async {
            if (!mounted) return;
            _showUpdateMessage(
              'A new version is ready. Restart to update.',
              actionLabel: 'RESTART',
              onAction: () async {
                await InAppUpdate.completeFlexibleUpdate().catchError((_) {});
              },
            );
          }).catchError((_) {
            _showUpdateMessage(
              'Could not start app update. You can try again later.',
            );
          });
        }
      }
    } catch (_) {
      // Silently ignore update errors to avoid disrupting the user flow
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  void _showUpdateMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                onPressed: onAction,
              )
            : null,
      ),
    );
  }

  void _loadData({bool clearViewedUser = false}) {
    final authRepository = context.read<AuthRepository>();
    final userViewModel = context.read<UserViewModel>();

    // Clear viewed user only when explicitly requested (e.g., on page init)
    if (clearViewedUser) {
      userViewModel.clearViewedUser();
    }

    // Check if user is authenticated
    if (authRepository.currentUser != null) {
      // Always reload current user data when page loads to ensure we have the right user
      userViewModel.loadCurrentUser();
    } else {
      // Clear user data if not authenticated
      userViewModel.clearCurrentUser();
    }

    // Load videos feed (works for both authenticated and unauthenticated users)
    context.read<VideoViewModel>().loadVideos(refresh: true);
    context.read<PlaylistViewModel>().loadCuratedPlaylists(
      silent: true,
      force: true,
    );
    _curatedShuffleSeed = DateTime.now().millisecondsSinceEpoch;
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
    final playlistViewModel = context.watch<PlaylistViewModel>();
    final moodFeedViewModel = context.watch<MoodFeedViewModel>();
    final isMoodFeed = moodFeedViewModel.isMoodActive;
    final feedVideos = isMoodFeed
        ? moodFeedViewModel.videos
        : _buildPrioritizedFeed(
            videoViewModel.videos,
            playlistViewModel,
          );
    final feedHasMore =
        isMoodFeed ? moodFeedViewModel.hasMore : videoViewModel.hasMore;
    final feedIsLoadingMore = isMoodFeed
        ? moodFeedViewModel.isLoadingMore
        : videoViewModel.isLoading;

    final authRepository = context.watch<AuthRepository>();
    final isAuthenticated = authRepository.currentUser != null;
    final user = isAuthenticated ? userViewModel.currentUser : null;

    // Clear user data if auth state changes to logged out
    if (!isAuthenticated && userViewModel.currentUser != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        userViewModel.clearCurrentUser();
      });
    }

    // Load user data if authenticated and not already loaded
    if (isAuthenticated && user == null && !userViewModel.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        userViewModel.loadCurrentUser();
      });
    }

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
          title: _isSearchActive
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: 'Search videos...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.6),
                      fontSize: 16,
                    ),
                    suffixIcon:
                        null, // Clear button removed - using AppBar close button instead
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      context.push(
                        '/search?q=${Uri.encodeComponent(value.trim())}',
                      );
                      _searchController.clear();
                      _searchFocusNode.unfocus();
                      setState(() {
                        _isSearchActive = false;
                      });
                    }
                  },
                )
              : const HiffiLogo(size: 28),
          actions: [
            if (!_isSearchActive)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  unawaited(
                    context.read<FirstPartyAnalyticsService>().capture(
                      r'$click',
                      elementUiName: 'navbar-open-search-button',
                      screenName: 'home',
                    ),
                  );
                  _activateSearch();
                },
                tooltip: 'Search',
              ),
            if (_isSearchActive)
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return IconButton(
                    icon: Icon(
                      value.text.isNotEmpty ? Icons.clear : Icons.close,
                    ),
                    onPressed: _clearSearch,
                    tooltip: value.text.isNotEmpty
                        ? 'Clear search'
                        : 'Close search',
                  );
                },
              ),
            if (user != null)
              IconButton(
                onPressed: () async {
                  unawaited(
                    context.read<FirstPartyAnalyticsService>().capture(
                      r'$click',
                      elementUiName: 'navbar-logout-confirm-button',
                      screenName: 'home',
                    ),
                  );
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
                    homeViewModel.signOut();
                  }
                },
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
              )
            else if (!_isSearchActive)
              TextButton(
                onPressed: () {
                  unawaited(
                    context.read<FirstPartyAnalyticsService>().capture(
                      r'$click',
                      elementUiName: 'navbar-login-button',
                      screenName: 'home',
                    ),
                  );
                  context.push('/signup');
                },
                child: const Text('Sign Up'),
              ),
          ],
        ),
        child: NetworkPageShell(
          hasCachedContent:
              feedVideos.isNotEmpty || user != null,
          isLoading: isMoodFeed
              ? (moodFeedViewModel.isLoading && feedVideos.isEmpty)
              : ((userViewModel.isLoading && user == null) ||
                    (videoViewModel.isLoading && videoViewModel.videos.isEmpty)),
          emptyDescription: isMoodFeed
              ? 'Connect to the internet to load this mix.'
              : 'Connect to the internet and try again to load your feed.',
          onRetry: () async {
            if (isMoodFeed) {
              await context.read<MoodFeedViewModel>().refreshActiveMood();
            } else {
              await context.read<VideoViewModel>().refresh();
              await context.read<PlaylistViewModel>().loadCuratedPlaylists(
                silent: true,
                force: true,
              );
            }
          },
          child: SafeArea(
            child: userViewModel.isLoading && user == null
                ? VideoListShimmer(itemCount: 6)
                : Stack(
                  children: [
                    RefreshIndicator(
                      onRefresh: () async {
                        if (moodFeedViewModel.isMoodActive) {
                          await moodFeedViewModel.refreshActiveMood();
                          return;
                        }
                        await context.read<UserViewModel>().loadCurrentUser();
                        await context.read<VideoViewModel>().refresh();
                        await context.read<PlaylistViewModel>().loadCuratedPlaylists(
                          silent: true,
                          force: true,
                        );
                        if (mounted) {
                          setState(() {
                            _curatedShuffleSeed =
                                DateTime.now().millisecondsSinceEpoch;
                          });
                        }
                      },
                      child: CustomScrollView(
                        slivers: [
                          // Compact Profile Section or Sign In Button
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                              child: user != null
                                  ? _CompactProfileSection(
                                      user: user,
                                      onProfileTap: () {
                                        unawaited(
                                          context
                                              .read<FirstPartyAnalyticsService>()
                                              .capture(
                                                r'$click',
                                                elementUiName:
                                                    'navbar-profile-link',
                                                screenName: 'home',
                                              ),
                                        );
                                        context.push('/users/${user.username}');
                                      },
                                      onUploadTap: () {
                                        // Redirect to become creator if not a creator
                                        if (user.role != 'creator') {
                                          context.push('/become-creator');
                                        } else {
                                          context.push('/upload/video');
                                        }
                                      },
                                    )
                                  : _SignInPrompt(
                                      onSignInTap: () {
                                        // Pass current route as return route
                                        const currentRoute = '/home';
                                        context.push(
                                          '/login?returnTo=${Uri.encodeComponent(currentRoute)}',
                                        );
                                      },
                                    ),
                            ),
                          ),
                          if (!_isSearchActive && !isMoodFeed && moodFeedViewModel.pickerOpen)
                            SliverToBoxAdapter(
                              child: MoodPickerCard(
                                onMoodSelected: (query) {
                                  context.read<MoodFeedViewModel>().applyMood(query);
                                },
                              ),
                            ),
                          if (!_isSearchActive &&
                              isMoodFeed &&
                              moodFeedViewModel.activeMood != null)
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _ActiveMoodBarHeader(
                                mood: moodFeedViewModel.activeMood!,
                                onBack: () {
                                  context.read<MoodFeedViewModel>().clearActiveMood();
                                },
                                onPlay: () => _playMoodFromStart(context),
                              ),
                            ),
                          // Search indicator
                          if (_isSearchActive &&
                              videoViewModel.searchQuery != null)
                            SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Searching for "${videoViewModel.searchQuery}"',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          // Video Feed
                          if (isMoodFeed &&
                              moodFeedViewModel.isLoading &&
                              feedVideos.isEmpty)
                            const SliverFillRemaining(
                              child: VideoListShimmer(itemCount: 6),
                            )
                          else if (!isMoodFeed &&
                              videoViewModel.isLoading &&
                              videoViewModel.videos.isEmpty)
                            SliverFillRemaining(
                              child: VideoListShimmer(itemCount: 6),
                            )
                          else if (isMoodFeed &&
                              moodFeedViewModel.errorMessage != null &&
                              feedVideos.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _buildScrollableSliverFill(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isOfflineErrorMessage(
                                            moodFeedViewModel.errorMessage,
                                          )
                                          ? Icons.wifi_off_rounded
                                          : Icons.error_outline_rounded,
                                      size: 48,
                                      color: isOfflineErrorMessage(
                                            moodFeedViewModel.errorMessage,
                                          )
                                          ? Theme.of(context).colorScheme.primary
                                          : Theme.of(context).colorScheme.error,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      moodFeedViewModel.errorMessage!,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    FilledButton(
                                      onPressed: moodFeedViewModel
                                          .refreshActiveMood,
                                      child: const Text('Try Again'),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (!isMoodFeed &&
                              videoViewModel.errorMessage != null &&
                              videoViewModel.videos.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Builder(
                                builder: (context) {
                                  final offline = isOfflineErrorMessage(
                                    videoViewModel.errorMessage,
                                  );
                                  return _buildScrollableSliverFill(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            color: offline
                                                ? Theme.of(context)
                                                    .colorScheme
                                                    .primaryContainer
                                                    .withOpacity(0.3)
                                                : Theme.of(context)
                                                    .colorScheme
                                                    .errorContainer
                                                    .withOpacity(0.3),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            offline
                                                ? Icons.wifi_off_rounded
                                                : Icons.error_outline_rounded,
                                            size: 48,
                                            color: offline
                                                ? Theme.of(
                                                    context,
                                                  ).colorScheme.primary
                                                : Theme.of(
                                                    context,
                                                  ).colorScheme.error,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        Text(
                                          offline
                                              ? 'You are offline right now'
                                              : 'Oops! Something went wrong',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          offline
                                              ? 'Please check your connection and try again.'
                                              : 'We encountered an issue while loading your feed.',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                        const SizedBox(height: 20),
                                        FilledButton.icon(
                                          onPressed: videoViewModel.refresh,
                                          icon: const Icon(Icons.refresh_rounded),
                                          label: const Text('Try Again'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            )
                          else if (feedVideos.isEmpty)
                            SliverFillRemaining(
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isSearchActive
                                          ? Icons.search_off
                                          : Icons.video_library_outlined,
                                      size: 48,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isSearchActive
                                          ? 'No videos found'
                                          : isMoodFeed
                                          ? 'No tracks yet'
                                          : 'No videos yet',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.6),
                                          ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (_isSearchActive) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try a different search term',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withOpacity(0.5),
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: EdgeInsets.fromLTRB(12.w, 0, 12.w, 16.h),
                              sliver: SliverOpacity(
                                opacity: isMoodFeed &&
                                        moodFeedViewModel.isLoading &&
                                        feedVideos.isNotEmpty
                                    ? 0.35
                                    : 1,
                                sliver: SliverGrid(
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: responsiveGridColumns(context),
                                  mainAxisSpacing: 12.h,
                                  crossAxisSpacing: 12.w,
                                  childAspectRatio: _calculateAspectRatio(
                                    context,
                                  ),
                                ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    if (index >= feedVideos.length) {
                                      if (feedHasMore && !feedIsLoadingMore) {
                                        WidgetsBinding.instance
                                            .addPostFrameCallback((_) {
                                              if (isMoodFeed) {
                                                moodFeedViewModel.loadMore();
                                              } else {
                                                videoViewModel.loadVideos();
                                              }
                                            });
                                      }
                                      return feedIsLoadingMore
                                          ? const Center(
                                              child: InlineShimmer(
                                                width: 40,
                                                height: 40,
                                              ),
                                            )
                                          : const SizedBox.shrink();
                                    }
                                    final video = feedVideos[index];
                                    return _GridVideoCard(
                                      video: video,
                                      isMoodFeed: isMoodFeed,
                                      moodSessionBuilder: isMoodFeed
                                          ? () => moodFeedViewModel
                                                .buildSessionAt(index)
                                          : null,
                                    );
                                  },
                                  childCount:
                                      feedVideos.length +
                                      (feedHasMore ? 1 : 0),
                                ),
                              ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Search Suggestions Overlay (Twitch-like) - positioned directly below AppBar
                    if (_isSearchActive && _searchController.text.isNotEmpty)
                      Positioned(
                        top:
                            0, // Position at top of body (right below AppBar, no gap)
                        left: 0,
                        right: 0,
                        child: SearchOverlay(
                          query: _searchController.text,
                          onQueryChanged: _onSearchChanged,
                          onResultTap: _onSuggestionTap,
                          onViewAllResults: _onViewAllResults,
                        ),
                      ),
                  ],
                ),
          ),
        ),
      ),
    );
  }

  List<VideoModel> _buildPrioritizedFeed(
    List<VideoModel> source,
    PlaylistViewModel playlistViewModel,
  ) {
    if (source.isEmpty) return const [];

    final curatedIds = <String>{};
    for (final curated in playlistViewModel.curatedPlaylists) {
      final detail = playlistViewModel.curatedDetail(curated.playlistId);
      if (detail == null) continue;
      for (final item in detail.items) {
        if (item.videoId.isNotEmpty) curatedIds.add(item.videoId);
      }
    }
    if (curatedIds.isEmpty) return source;

    final curatedVideos = <VideoModel>[];
    final nonCuratedVideos = <VideoModel>[];
    for (final video in source) {
      if (curatedIds.contains(video.videoId)) {
        curatedVideos.add(video);
      } else {
        nonCuratedVideos.add(video);
      }
    }

    // Keep curated-first behavior while rotating order per refresh/session.
    final rng = Random(_curatedShuffleSeed);
    curatedVideos.shuffle(rng);
    return [...curatedVideos, ...nonCuratedVideos];
  }

  Future<void> _playMoodFromStart(BuildContext context) async {
    final moodVm = context.read<MoodFeedViewModel>();
    final session = moodVm.buildSessionAt(0);
    if (session == null || moodVm.videos.isEmpty) return;

    final video = moodVm.videos.first;
    await moodVm.persistSession(session);
    if (!context.mounted) return;

    unawaited(
      context.read<FirstPartyAnalyticsService>().capture(
        r'$click',
        elementUiName: 'mood-play-button',
        screenName: 'home',
        videoId: video.videoId,
        videoTitle: video.videoTitle,
      ),
    );

    context.push(
      '/watch/${video.videoId}?playlist=${Uri.encodeComponent(session.playlistId)}&pindex=0',
      extra: WatchRouteExtra(video: video, playlistSession: session),
    );
  }

  Widget _buildScrollableSliverFill({required Widget child}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

class _ActiveMoodBarHeader extends SliverPersistentHeaderDelegate {
  _ActiveMoodBarHeader({
    required this.mood,
    required this.onBack,
    required this.onPlay,
  });

  final MoodDef mood;
  final VoidCallback onBack;
  final VoidCallback onPlay;

  @override
  double get minExtent => ActiveMoodBar.kHeight;

  @override
  double get maxExtent => ActiveMoodBar.kHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: ActiveMoodBar.kHeight,
      child: ActiveMoodBar(
        mood: mood,
        onBack: onBack,
        onPlay: onPlay,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ActiveMoodBarHeader oldDelegate) {
    return oldDelegate.mood != mood;
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
              HiffiAvatar(
                imageUrl: user.profilePicture ?? user.avatarUrl,
                size: 56,
                fallbackText: user.name,
                cacheBust: user.updatedAt?.millisecondsSinceEpoch,
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
                        user.name.isNotEmpty
                            ? user.name
                            : user.username.toLowerCase(),
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
                  '@${user.username.toLowerCase()}',
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
        // Upload Button - Compact FAB (role-based icon)
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
                child: Icon(Icons.bolt, color: Colors.white, size: 24),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignInTap});

  final VoidCallback onSignInTap;

  @override
  Widget build(BuildContext context) {
    final isTablet = isTabletOrLarger(context);
    return Container(
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: isTablet ? 28 : 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: isTablet ? 28 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sign in to access your profile',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 14 : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload videos and manage your account',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withOpacity(0.7),
                    fontSize: isTablet ? 13 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onSignInTap, child: const Text('Sign In')),
        ],
      ),
    );
  }
}

// Calculate aspect ratio based on screen width and content height
double _calculateAspectRatio(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final columns = responsiveGridColumns(context).toDouble();
  // Card width: (screen width - left padding - right padding - (columns-1)*spacing) / columns
  final horizontalPadding = 12.w * 2;
  final spacing = 12.w;
  final cardWidth =
      (screenWidth - horizontalPadding - spacing * (columns - 1)) / columns;

  // Thumbnail maintains 16:9 aspect ratio
  final thumbnailHeight = cardWidth * (9 / 16);

  // Text section height: responsive so cards stay balanced on tablet
  final textSectionHeight =
      responsiveGridTextSectionHeight(context) + 8.h;

  // Total card height
  final totalHeight = thumbnailHeight + textSectionHeight;

  return cardWidth / totalHeight;
}

// Grid video card for feed layout
class _GridVideoCard extends StatelessWidget {
  const _GridVideoCard({
    required this.video,
    this.isMoodFeed = false,
    this.moodSessionBuilder,
  });

  final VideoModel video;
  final bool isMoodFeed;
  final PlaylistSession? Function()? moodSessionBuilder;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final moodSession = moodSessionBuilder?.call();
          if (isMoodFeed && moodSession != null) {
            unawaited(
              context.read<FirstPartyAnalyticsService>().capture(
                r'$click',
                elementUiName: 'opened-video-from-mood',
                screenName: 'home',
                videoId: video.videoId,
                videoTitle: video.videoTitle,
                properties: {
                  'source': 'mood',
                  'source_path': '/home',
                  'path': '/home',
                  'video_id': video.videoId,
                  'video_title': video.videoTitle,
                },
              ),
            );
            await context.read<MoodFeedViewModel>().persistSession(moodSession);
            if (!context.mounted) return;
            context.push(
              '/watch/${video.videoId}?playlist=${Uri.encodeComponent(moodSession.playlistId)}&pindex=${moodSession.currentIndex}',
              extra: WatchRouteExtra(
                video: video,
                playlistSession: moodSession,
              ),
            );
            return;
          }

          unawaited(
            context.read<FirstPartyAnalyticsService>().capture(
              r'$click',
              elementUiName: 'opened-video-from-home',
              screenName: 'home',
              videoId: video.videoId,
              videoTitle: video.videoTitle,
              properties: {
                'source': 'home',
                'source_path': '/home',
                'path': '/home',
                'video_id': video.videoId,
                'video_title': video.videoTitle,
              },
            ),
          );
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
                          // Processing indicator overlay (top right) – only when processing
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
            // Title and User section – responsive font sizes for tablet (YouTube-style: 2 lines + ellipsis)
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
