import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../user/domain/models/user_model.dart';
import '../../../user/presentation/viewmodels/user_view_model.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../viewmodels/home_view_model.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  StreamSubscription? _authSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchDebounce;
  bool _isSearchActive = false;
  List<VideoModel> _searchSuggestions = [];
  bool _isLoadingSuggestions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData(clearViewedUser: true);
      _setupAuthListener();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadSearchSuggestions(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    // Only show loading if we don't have suggestions yet or query changed significantly
    if (_searchSuggestions.isEmpty ||
        !_searchController.text.toLowerCase().startsWith(
          _searchSuggestions.isNotEmpty
              ? _searchSuggestions.first.videoTitle.toLowerCase().substring(
                  0,
                  _searchSuggestions.first.videoTitle.length > query.length
                      ? query.length
                      : _searchSuggestions.first.videoTitle.length,
                )
              : '',
        )) {
      setState(() {
        _isLoadingSuggestions = true;
      });
    }

    try {
      final videoRepository = context.read<VideoRepository>();
      final suggestions = await videoRepository.getVideos(
        page: 1,
        limit: 5, // Show 5 suggestions
        searchQuery: query,
      );

      if (mounted && _searchController.text == query) {
        setState(() {
          _searchSuggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchSuggestions = [];
          _isLoadingSuggestions = false;
        });
      }
    }
  }

  void _onSearchChanged(String query) {
    setState(() {}); // Update UI to show/hide clear button

    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _searchSuggestions = [];
        _isLoadingSuggestions = false;
      });
      return;
    }

    // Load suggestions immediately as user types (with shorter debounce for better UX)
    _loadSearchSuggestions(query);

    // Perform full search after debounce (only if user stops typing)
    _searchDebounce = Timer(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final videoViewModel = context.read<VideoViewModel>();
      if (query.trim().isNotEmpty) {
        videoViewModel.search(query);
      }
    });
  }

  void _onSuggestionTap(VideoModel video) {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchActive = false;
      _searchSuggestions = [];
    });
    // Navigate to video player
    context.push('/video/${video.videoId}', extra: video);
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
      final videoViewModel = context.read<VideoViewModel>();
      videoViewModel.clearSearch();
      setState(() {
        _isSearchActive = false;
        _searchSuggestions = [];
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

  Widget _buildNoResultsState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No videos found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
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
      child: Scaffold(
        appBar: AppBar(
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
                      final videoViewModel = context.read<VideoViewModel>();
                      videoViewModel.search(value);
                      _searchFocusNode.unfocus();
                      setState(() {
                        _searchSuggestions = [];
                      });
                    }
                  },
                )
              : const Text('Home'),
          actions: [
            if (!_isSearchActive)
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: _activateSearch,
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
                onPressed: () {
                  homeViewModel.signOut();
                },
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
              )
            else if (!_isSearchActive)
              TextButton(
                onPressed: () {
                  context.push('/login');
                },
                child: const Text('Sign In'),
              ),
          ],
        ),
        body: userViewModel.isLoading && user == null
            ? VideoListShimmer(itemCount: 6)
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: () async {
                      await context.read<UserViewModel>().loadCurrentUser();
                      await context.read<VideoViewModel>().refresh();
                    },
                    child: CustomScrollView(
                      slivers: [
                        // Compact Profile Section or Sign In Button
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: user != null
                                ? _CompactProfileSection(
                                    user: user,
                                    onProfileTap: () {
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
                                      context.push('/login');
                                    },
                                  ),
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
                                    style: Theme.of(context).textTheme.bodySmall
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
                        if (videoViewModel.isLoading &&
                            videoViewModel.videos.isEmpty)
                          SliverFillRemaining(
                            child: VideoListShimmer(itemCount: 6),
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyMedium,
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
                            sliver: SliverGrid(
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12.h,
                                crossAxisSpacing: 12.w,
                                // Calculate aspect ratio based on screen size
                                // Thumbnail (16:9) + spacing + text section (60h)
                                childAspectRatio: _calculateAspectRatio(
                                  context,
                                ),
                              ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index >= videoViewModel.videos.length) {
                                    // Load more if available (schedule after build to avoid setState during build)
                                    if (videoViewModel.hasMore &&
                                        !videoViewModel.isLoading) {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            videoViewModel.loadVideos();
                                          });
                                    }
                                    return videoViewModel.isLoading
                                        ? const Center(
                                            child: InlineShimmer(
                                              width: 40,
                                              height: 40,
                                            ),
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
                  // Search Suggestions Overlay (Twitch-like) - positioned directly below AppBar
                  if (_isSearchActive && _searchController.text.isNotEmpty)
                    Positioned(
                      top:
                          0, // Position at top of body (right below AppBar, no gap)
                      left: 0,
                      right: 0,
                      child: Material(
                        elevation: 8,
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(8),
                              bottomRight: Radius.circular(8),
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outline.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                          ),
                          child: _isLoadingSuggestions
                              ? const Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: Center(
                                    child: VideoListShimmer(
                                      itemCount: 3,
                                      isGrid: false,
                                    ),
                                  ),
                                )
                              : _searchSuggestions.isEmpty
                              ? _buildNoResultsState(context)
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Results count header
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .outline
                                                .withOpacity(0.1),
                                            width: 1,
                                          ),
                                        ),
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
                                            '${_searchSuggestions.length} ${_searchSuggestions.length == 1 ? 'result' : 'results'}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            onPressed: () {
                                              final videoViewModel = context
                                                  .read<VideoViewModel>();
                                              videoViewModel.search(
                                                _searchController.text,
                                              );
                                              _searchFocusNode.unfocus();
                                              setState(() {
                                                _searchSuggestions = [];
                                              });
                                            },
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            child: const Text('View all'),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Suggestions list
                                    Flexible(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: _searchSuggestions.length,
                                        itemBuilder: (context, index) {
                                          final video =
                                              _searchSuggestions[index];
                                          return _SearchSuggestionItem(
                                            video: video,
                                            searchQuery: _searchController.text,
                                            onTap: () =>
                                                _onSuggestionTap(video),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
                backgroundImage: () {
                  final profileUrl =
                      user.profilePicture != null &&
                          user.profilePicture!.isNotEmpty
                      ? ImageUtils.getProfileImageUrl(user.profilePicture!)
                      : null;
                  final avatarUrl =
                      user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                      ? user.avatarUrl
                      : null;

                  if (profileUrl != null) {
                    return NetworkImage(
                      profileUrl,
                      headers: ImageUtils.getProfileImageHeaders(),
                    );
                  } else if (avatarUrl != null) {
                    return NetworkImage(avatarUrl);
                  }
                  return null;
                }(),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(
              Icons.person_outline,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sign in to access your profile',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Upload videos and manage your account',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withOpacity(0.7),
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
                        backgroundImage: () {
                          final profileUrl =
                              video.profilePicture != null &&
                                  video.profilePicture!.isNotEmpty
                              ? ImageUtils.getProfileImageUrl(
                                  video.profilePicture!,
                                )
                              : null;
                          return profileUrl != null
                              ? NetworkImage(
                                  profileUrl,
                                  headers: ImageUtils.getProfileImageHeaders(),
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

/// Search suggestion item widget (Twitch-like style)
class _SearchSuggestionItem extends StatelessWidget {
  const _SearchSuggestionItem({
    required this.video,
    required this.searchQuery,
    required this.onTap,
  });

  final VideoModel video;
  final String searchQuery;
  final VoidCallback onTap;

  String? get _thumbnailUrl {
    return ImageUtils.getVideoThumbnailUrl(video.videoThumbnail);
  }

  /// Highlight matching text in the title
  List<TextSpan> _buildHighlightedText(String text, String query) {
    if (query.isEmpty) {
      return [TextSpan(text: text)];
    }

    final queryLower = query.toLowerCase();
    final textLower = text.toLowerCase();
    final matches = <({int start, int end})>[];

    int start = 0;
    while ((start = textLower.indexOf(queryLower, start)) != -1) {
      matches.add((start: start, end: start + query.length));
      start += query.length;
    }

    if (matches.isEmpty) {
      return [TextSpan(text: text)];
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: text.substring(match.start, match.end),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B35),
          ),
        ),
      );
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: _thumbnailUrl == null || _thumbnailUrl!.isEmpty
                    ? Container(
                        width: 80,
                        height: 45,
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.video_library,
                          size: 24,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
                        ),
                      )
                    : Image.network(
                        _thumbnailUrl!,
                        headers: ImageUtils.getVideoThumbnailHeaders(),
                        width: 80,
                        height: 45,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 45,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Icon(
                              Icons.broken_image,
                              size: 24,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            width: 80,
                            height: 45,
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            child: Center(
                              child: CircularProgressIndicator(
                                value:
                                    loadingProgress.expectedTotalBytes != null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(width: 12),
              // Video info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title with highlighted search query
                    RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        children: _buildHighlightedText(
                          video.videoTitle,
                          searchQuery,
                        ),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // User info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          backgroundImage: () {
                            final profileUrl =
                                video.profilePicture != null &&
                                    video.profilePicture!.isNotEmpty
                                ? ImageUtils.getProfileImageUrl(
                                    video.profilePicture!,
                                  )
                                : null;
                            return profileUrl != null
                                ? NetworkImage(
                                    profileUrl,
                                    headers:
                                        ImageUtils.getProfileImageHeaders(),
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
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimaryContainer,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            video.userUsername.isNotEmpty
                                ? video.userUsername
                                : 'Unknown',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant
                                      .withOpacity(0.8),
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Views
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${_formatCount(video.videoViews)} views',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant.withOpacity(0.6),
                                fontSize: 11,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow icon
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
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
