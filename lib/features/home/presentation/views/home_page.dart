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
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../../../search/presentation/widgets/search_overlay.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../../core/widgets/app_sidebar.dart';
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
  bool _isSearchActive = false;

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
    super.dispose();
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

    // If we got a 401 error, sign out to clear auth state and prevent infinite loops
    if (userViewModel.hasUnauthorizedError && isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        homeViewModel.signOut();
      });
    }

    // Load user data if authenticated and not already loaded
    // Don't retry if there's a 401 error (unauthorized) to prevent infinite loops
    if (isAuthenticated &&
        user == null &&
        !userViewModel.isLoading &&
        !userViewModel.hasUnauthorizedError) {
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
          leading: Builder(
            builder: (context) {
              // Only show menu icon if user is authenticated and sidebar is available
              final authRepository = context.read<AuthRepository>();
              final isAuthenticated = authRepository.currentUser != null;

              if (!isAuthenticated) {
                // Return empty widget to hide the icon completely for logged-out users
                return const SizedBox.shrink();
              }

              final sidebar = AppSidebar.of(context);
              // If sidebar is not available (shouldn't happen when authenticated, but be safe)
              if (sidebar == null) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: const Icon(Icons.menu),
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
              : SizedBox.shrink(),
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
                    homeViewModel.signOut();
                  }
                },
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout),
              )
            else if (!_isSearchActive)
              TextButton(
                onPressed: () {
                  context.push('/signup');
                },
                child: const Text('Sign Up'),
              ),
          ],
        ),
        child: SafeArea(
          child: userViewModel.isLoading && user == null
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
                                        // Pass current route as return route
                                        const currentRoute = '/home';
                                        context.push(
                                          '/login?returnTo=${Uri.encodeComponent(currentRoute)}',
                                        );
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
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
                      ? ImageUtils.getProfileImageUrl(
                          user.profilePicture!,
                          cacheBust: user.updatedAt?.millisecondsSinceEpoch,
                        )
                      : null;
                  final avatarUrl =
                      user.avatarUrl != null &&
                          user.avatarUrl!.isNotEmpty &&
                          ImageUtils.isValidImageUrl(user.avatarUrl)
                      ? user.avatarUrl
                      : null;

                  if (profileUrl != null) {
                    return NetworkImage(
                      profileUrl,
                      headers: ImageUtils.getProfileImageHeaders(profileUrl),
                    );
                  } else if (avatarUrl != null &&
                      ImageUtils.isValidImageUrl(avatarUrl)) {
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
                          // Processing indicator or View count overlay (top right)
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
                              child: video.status == 'temp'
                                  ? const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                        Text(
                                          '• ',
                                          style: TextStyle(
                                            color: Colors.orangeAccent,
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
                                    )
                                  : Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
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
                                ? video.userUsername.toLowerCase()
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
