import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';
import '../viewmodels/user_view_model.dart';
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/file_validation_utils.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../../core/widgets/hiffi_image.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.username});

  final String username;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditingName = false;
  bool _isEditingEmail = false;
  UserModel? _currentLoggedInUser;

  bool _hasAttemptedLoad = false;
  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos =
      true; // Start as true to prevent showing "no videos" before load
  bool _hasAttemptedLoadVideos =
      false; // Track if we've attempted to load videos
  String? _videosError;
  int _profilePictureCacheBust = 0; // Cache-busting timestamp for iOS
  bool _isPickingFile = false; // Track if file picker is open

  @override
  void initState() {
    super.initState();
    // Start loading immediately to prevent showing "User not found" before loading starts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authRepository = context.read<AuthRepository>();
      final isAuthenticated = authRepository.currentUser != null;

      // Redirect to login if not authenticated
      if (!isAuthenticated) {
        if (mounted) {
          // Pass current route as return route
          final currentRoute = '/users/${widget.username}';
          context.push('/login?returnTo=${Uri.encodeComponent(currentRoute)}');
        }
        return;
      }

      final viewModel = context.read<UserViewModel>();
      final userRepository = context.read<UserRepository>();

      // Mark that we've attempted to load
      _hasAttemptedLoad = true;

      // Load current logged-in user first and store it
      try {
        final currentUser = await userRepository.getCurrentUser();
        setState(() {
          _currentLoggedInUser = currentUser;
        });
      } catch (e) {
        // Ignore error, might not be logged in
        debugPrint('Failed to load current user: $e');
      }
      // Load the profile user
      await viewModel.loadUser(widget.username);

      // Load user videos if user is a creator or has uploaded videos
      // This ensures video views are always up-to-date when profile page loads
      final viewedUser = viewModel.viewedUser;
      if (viewedUser != null &&
          (viewedUser.role == 'creator' || viewedUser.totalVideos > 0)) {
        await _loadUserVideos(widget.username);
      }
    });
  }

  Future<void> _loadUserVideos(String username) async {
    setState(() {
      _isLoadingVideos = true;
      _videosError = null;
      _hasAttemptedLoadVideos = true;
    });

    try {
      final videoRepository = context.read<VideoRepository>();

      // Determine if this is the current user's own profile
      final isOwnProfile = _currentLoggedInUser?.username == username;

      final List<VideoModel> videos;
      if (isOwnProfile) {
        // Use /videos/list/self for current user's profile
        videos = await videoRepository.getUserVideos(limit: 20, offset: 0);
      } else {
        // Fetch videos with latest data including up-to-date video views
        videos = await videoRepository.getVideosByUsername(
          username: username,
          limit: 20,
          offset: 0,
        );
      }

      if (mounted) {
        setState(() {
          // Update videos list with latest data including current video views
          _userVideos = videos;
          _isLoadingVideos = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videosError = e.toString();
          _isLoadingVideos = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    // Use viewedUser for the profile being displayed, not currentUser
    final user = viewModel.viewedUser;
    final isOwnProfile = _currentLoggedInUser?.username == widget.username;
    final authRepository = context.read<AuthRepository>();
    final isAuthenticated = authRepository.currentUser != null;

    // Debug: Log current state
    debugPrint(
      'ProfilePage build: user=${user?.username}, isLoading=${viewModel.isLoading}, error=${viewModel.errorMessage}',
    );

    // Update controllers when user data changes and not editing
    if (user != null && _nameController.text != user.name && !_isEditingName) {
      _nameController.text = user.name;
    }
    if (user != null &&
        _emailController.text != (user.email ?? '') &&
        !_isEditingEmail) {
      _emailController.text = user.email ?? '';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isPickingFile) {
          // Show confirmation dialog when back is pressed during file selection
          final shouldExit = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Exit file selection?'),
              content: const Text(
                'Are you sure you want to exit? Your file selection will be cancelled.',
              ),
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
          if (shouldExit == true && mounted) {
            setState(() {
              _isPickingFile = false;
            });
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          }
        } else {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.light,
          title: Text(
            widget.username,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            if (isOwnProfile && user != null)
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white),
                onPressed: () =>
                    _showEditProfileDialog(context, user, viewModel),
              ),
          ],
        ),
        body: !isAuthenticated
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock_outline, size: 64),
                    SizedBox(height: 16),
                    Text('Please sign in to view profiles'),
                  ],
                ),
              )
            : ((!_hasAttemptedLoad && user == null) ||
                  (user == null && viewModel.isLoading))
            ? const ProfileShimmer()
            : viewModel.errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color:
                              (viewModel.errorMessage!.contains(
                                    'SocketException',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Failed host lookup',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Network is unreachable',
                                  ))
                              ? Theme.of(
                                  context,
                                ).colorScheme.primaryContainer.withOpacity(0.3)
                              : Theme.of(
                                  context,
                                ).colorScheme.errorContainer.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          (viewModel.errorMessage!.contains(
                                    'SocketException',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Failed host lookup',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Network is unreachable',
                                  ))
                              ? Icons.wifi_off_rounded
                              : Icons.error_outline_rounded,
                          size: 64,
                          color:
                              (viewModel.errorMessage!.contains(
                                    'SocketException',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Failed host lookup',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Network is unreachable',
                                  ))
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        (viewModel.errorMessage!.contains('SocketException') ||
                                viewModel.errorMessage!.contains(
                                  'Failed host lookup',
                                ) ||
                                viewModel.errorMessage!.contains(
                                  'Network is unreachable',
                                ))
                            ? 'No Internet Connection'
                            : 'Oops! Something went wrong',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          (viewModel.errorMessage!.contains(
                                    'SocketException',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Failed host lookup',
                                  ) ||
                                  viewModel.errorMessage!.contains(
                                    'Network is unreachable',
                                  ))
                              ? 'Please check your connection and try again to view this profile.'
                              : 'We encountered an error while loading the profile. Please try again later.',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        onPressed: () {
                          viewModel.loadUser(widget.username);
                        },
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
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
              )
            : user == null
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_off,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'User not found',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await viewModel.loadUser(widget.username);
                  final refreshedUser = viewModel.viewedUser;
                  if (refreshedUser != null &&
                      (refreshedUser.role == 'creator' ||
                          refreshedUser.totalVideos > 0)) {
                    await _loadUserVideos(widget.username);
                  }
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // Banner with Profile Header Stacked on Top
                    SliverToBoxAdapter(
                      child: _buildBannerWithProfileHeader(
                        context,
                        user,
                        isOwnProfile,
                        viewModel,
                      ),
                    ),
                    // Profile Content
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const SizedBox(height: 32),
                          // About Card with Stats
                          _buildAboutCard(
                            context,
                            user,
                            isOwnProfile,
                            viewModel,
                          ),
                          const SizedBox(height: 24),
                          // Follow/Unfollow button for other users
                          if (!isOwnProfile && _currentLoggedInUser != null)
                            _buildFollowButton(context, viewModel, user),
                          const SizedBox(height: 16),
                          // Videos Section - Show if user is a creator or has videos
                          if (user.role == 'creator' || user.totalVideos > 0)
                            _buildUserVideosSection(context, isOwnProfile),
                          // Creator Studio Promo - Show for non-creators (own profile only)
                          if (isOwnProfile &&
                              user.role != 'creator' &&
                              user.totalVideos == 0)
                            _buildCreatorStudioPromo(context),
                          const SizedBox(height: 32),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildBannerWithProfileHeader(
    BuildContext context,
    UserModel user,
    bool isOwnProfile,
    UserViewModel viewModel,
  ) {
    // Responsive banner height: Mobile (180px), Tablet (240px), Desktop (320px)
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = screenWidth > 1024
        ? 320.0
        : screenWidth > 640
        ? 240.0
        : 180.0;

    // Responsive avatar size: Mobile (80px), Tablet (96-112px), Desktop (128px)
    final avatarRadius = screenWidth > 1024
        ? 64.0
        : screenWidth > 640
        ? 48.0
        : 40.0;
    final avatarOffset = screenWidth > 1024
        ? 64.0
        : screenWidth > 640
        ? 48.0
        : 40.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Banner Background
        Container(
          height: bannerHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            image: const DecorationImage(
              image: AssetImage('assets/abstract-orange-pattern.png'),
              fit: BoxFit.cover,
            ),
          ),
        ),
        // Profile Header Positioned on Top of Banner
        Positioned(
          left: 0,
          right: 0,
          bottom: -avatarOffset,
          child: Container(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with Edit Button Overlay and Elevation
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        key: ValueKey(
                          'avatar_${user.profilePicture}_$_profilePictureCacheBust',
                        ),
                        radius: avatarRadius,
                        backgroundColor: Colors.white,
                        child: HiffiAvatar(
                          size: (avatarRadius - 2) * 2,
                          imageUrl: user.profilePicture ?? user.avatarUrl,
                          fallbackText: user.name,
                          cacheBust: _profilePictureCacheBust != 0
                              ? _profilePictureCacheBust
                              : user.updatedAt?.millisecondsSinceEpoch,
                        ),
                      ),
                    ),
                    // Live status indicator
                    if (user.status?.isLive == true)
                      Positioned(
                        right: isOwnProfile ? 40 : 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.circle,
                            color: Colors.white,
                            size: 12,
                          ),
                        ),
                      ),
                    // Edit Icon Overlay (only for own profile) - Must be last for proper z-index
                    if (isOwnProfile)
                      Positioned(
                        // right: -4,
                        // bottom: -4,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            print('📸📸📸 Edit button tapped!');
                            _showProfilePictureOptions(
                              context,
                              viewModel,
                              user,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFED1C2F),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Name and Username (Left aligned)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      // Name
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      // Username
                      Text(
                        '@${user.username.toLowerCase()}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFollowButton(
    BuildContext context,
    UserViewModel viewModel,
    UserModel user,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: viewModel.isFollowActionLoading
              ? null
              : () async {
                  try {
                    if (user.isFollowing == true) {
                      await viewModel.unfollowUser(widget.username);
                    } else {
                      await viewModel.followUser(widget.username);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Failed to ${user.isFollowing == true ? 'unfollow' : 'follow'}: ${e.toString()}',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFED1C2F),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: viewModel.isFollowActionLoading
              ? const InlineShimmer(width: 20, height: 20)
              : Text(
                  user.isFollowing == true ? 'Following' : 'Follow',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAboutCard(
    BuildContext context,
    UserModel user,
    bool isOwnProfile,
    UserViewModel viewModel,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // About Section
          Text(
            'About',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          // Bio
          if (user.bio != null && user.bio!.isNotEmpty)
            Text(user.bio!, style: Theme.of(context).textTheme.bodyMedium),
          // Email (own profile only)
          if (isOwnProfile && user.email != null && user.email!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Text(
              'Email',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.email_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(width: 8),
                Text(
                  user.email!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
          // Stats Section - Only show if user is a creator
          if (user.role == 'creator') ...[
            const SizedBox(height: 24),
            Text(
              'Stats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive spacing: smaller on mobile, larger on tablet/desktop
                final spacing = constraints.maxWidth > 640 ? 12.0 : 8.0;
                return Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        value: user.totalVideos.toString(),
                        label: 'VIDEOS',
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _StatBox(
                        value: user.followers.toString(),
                        label: 'FOLLOWERS',
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _StatBox(
                        value: user.following.toString(),
                        label: 'FOLLOWING',
                      ),
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            // Show only followers and following for non-creators
            const SizedBox(height: 24),
            Text(
              'Stats',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                // Responsive spacing: smaller on mobile, larger on tablet/desktop
                final spacing = constraints.maxWidth > 640 ? 12.0 : 8.0;
                return Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        value: user.followers.toString(),
                        label: 'FOLLOWERS',
                      ),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: _StatBox(
                        value: user.following.toString(),
                        label: 'FOLLOWING',
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreatorStudioPromo(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFED1C2F).withOpacity(0.1),
            const Color(0xFFED1C2F).withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFED1C2F).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFED1C2F).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Color(0xFFED1C2F),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Become a Creator',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start sharing your content and grow your audience',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B6B6B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxWidth < 400;

              if (isSmallScreen) {
                // Stack vertically on small screens
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.video_library_rounded,
                              size: 18,
                              color: Color(0xFFED1C2F),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Upload Videos',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              size: 18,
                              color: Color(0xFFED1C2F),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Create your own music world',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          context.push('/become-creator');
                        },
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        label: const Text('View Creator Studio'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFED1C2F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }

              // Horizontal layout on larger screens
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.video_library_rounded,
                              size: 18,
                              color: Color(0xFFED1C2F),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Upload Videos',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note_rounded,
                              size: 18,
                              color: Color(0xFFED1C2F),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Create your own music world',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF1A1A1A),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: FilledButton.icon(
                      onPressed: () {
                        context.push('/become-creator');
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('View Creator Studio'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFED1C2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildUserVideosSection(BuildContext context, bool isOwnProfile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isOwnProfile ? 'My Videos' : 'Videos',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_isLoadingVideos)
          _buildVideoListShimmer(context)
        else if (_videosError != null)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Failed to load videos',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _loadUserVideos(widget.username),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_userVideos.isEmpty && _hasAttemptedLoadVideos)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No videos yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_userVideos.isEmpty && !_hasAttemptedLoadVideos)
          const SizedBox.shrink() // Don't show anything if we haven't attempted to load yet
        else
          _buildVideoList(context, isOwnProfile),
      ],
    );
  }

  Widget _buildVideoListShimmer(BuildContext context) {
    if (!isTabletOrLarger(context)) {
      const itemWidth = 200.0;
      const itemHeight = 112.5;
      return SizedBox(
        height: itemHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: const InlineShimmer(width: itemWidth, height: itemHeight),
            );
          },
        ),
      );
    }

    final crossAxisCount = responsiveGridColumns(context);
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemCount: crossAxisCount * 2,
      itemBuilder: (context, index) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: const InlineShimmer(width: double.infinity, height: 110),
        );
      },
    );
  }

  Widget _buildVideoList(BuildContext context, bool isOwnProfile) {
    // Use responsive breakpoints: horizontal list on mobile, grid on tablet/iPad
    if (!isTabletOrLarger(context)) {
      // Mobile: Horizontal ListView with Landscape Thumbnails
      const itemWidth = 200.0;
      const itemHeight = 112.5; // 200 * (9/16)

      return SizedBox(
        height: itemHeight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          itemCount: _userVideos.length,
          itemBuilder: (context, index) {
            final video = _userVideos[index];
            return Container(
              width: itemWidth,
              height: itemHeight,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: _VideoGridItem(
                video: video,
                onTap: () {
                  context.push('/video/${video.videoId}', extra: video);
                },
                onDelete: isOwnProfile
                    ? () => _showDeleteConfirmation(context, video)
                    : null,
              ),
            );
          },
        ),
      );
    }

    // Tablet/iPad: Grid with responsive columns (2/3/4)
    final crossAxisCount = responsiveGridColumns(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9, // Landscape video aspect ratio
      ),
      itemCount: _userVideos.length,
      itemBuilder: (context, index) {
        final video = _userVideos[index];
        return _VideoGridItem(
          video: video,
          onTap: () {
            context.push('/video/${video.videoId}', extra: video);
          },
          onDelete: isOwnProfile
              ? () => _showDeleteConfirmation(context, video)
              : null,
        );
      },
    );
  }

  Future<void> _showDeleteConfirmation(
    BuildContext context,
    VideoModel video,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Video'),
        content: const Text(
          'Are you sure you want to delete this video? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final videoViewModel = context.read<VideoViewModel>();
        await videoViewModel.deleteVideo(video.videoId);

        if (mounted) {
          setState(() {
            _userVideos.removeWhere((v) => v.videoId == video.videoId);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete video: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _showEditProfileDialog(
    BuildContext context,
    UserModel user,
    UserViewModel viewModel,
  ) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');

    // 💡 SINGLE SOURCE OF TRUTH: Cache initial email
    final initialEmail = user.email ?? '';
    String? emailError;
    String? otpId; // Store OTP ID in memory

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // 💡 REACTIVE: Detect email change efficiently
          final currentEmail = emailController.text.trim();
          final emailChanged = currentEmail != initialEmail;
          final buttonLabel = emailChanged ? 'Send OTP' : 'Save';
          final isLoading = viewModel.isLoading || viewModel.isSendingOTP;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle bar
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Title
                    Text(
                      'Edit Profile',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),
                    // Name field
                    TextField(
                      controller: nameController,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'[a-zA-Z\s]'),
                        ),
                        LengthLimitingTextInputFormatter(30),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Name',
                        hintText: 'Enter your name',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Email field
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email *',
                        hintText: 'Enter your email',
                        errorText: emailError,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.email),
                      ),
                      onChanged: (value) {
                        if (emailError != null) {
                          setModalState(() {
                            emailError = null;
                          });
                        }
                        // Trigger rebuild to update button label
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    // Bio field
                    TextField(
                      controller: bioController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: 'Bio',
                        hintText: 'Tell us about yourself',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.description),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Primary CTA (Save or Send OTP)
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              final newName = nameController.text.trim();
                              final newEmail = emailController.text.trim();
                              final newBio = bioController.text.trim();

                              // Validate name
                              if (newName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Name cannot be empty'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              // Validate email (required)
                              if (newEmail.isEmpty) {
                                setModalState(() {
                                  emailError = 'Email is required';
                                });
                                return;
                              }

                              // Validate email format
                              final emailRegex = RegExp(
                                r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                              );
                              if (!emailRegex.hasMatch(newEmail)) {
                                setModalState(() {
                                  emailError =
                                      'Please enter a valid email address';
                                });
                                return;
                              }

                              if (emailChanged) {
                                // 💡 OTP FLOW: Email changed, send OTP
                                try {
                                  final result = await viewModel
                                      .sendEmailUpdateOTP(
                                        currentUsername: user.username,
                                        name: newName,
                                        email: newEmail,
                                        bio: newBio,
                                      );
                                  otpId = result['id'] as String?;
                                  if (otpId != null && mounted) {
                                    // Show OTP verification bottom sheet
                                    _showOTPVerificationSheet(
                                      context,
                                      viewModel,
                                      user.username,
                                      otpId!,
                                      () {
                                        // On success: close both sheets and refresh
                                        Navigator.of(
                                          context,
                                        ).pop(); // Close OTP sheet
                                        Navigator.of(
                                          context,
                                        ).pop(); // Close edit sheet
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Profile updated successfully',
                                            ),
                                          ),
                                        );
                                        viewModel.loadUser(user.username);
                                      },
                                    );
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          viewModel.otpError ??
                                              'Failed to send OTP: $error',
                                        ),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              } else {
                                // 💡 NORMAL FLOW: Email unchanged, direct save
                                try {
                                  await viewModel.updateUser(
                                    currentUsername: user.username,
                                    name: newName,
                                    email: newEmail,
                                    bio: newBio,
                                  );

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Profile updated successfully',
                                        ),
                                      ),
                                    );
                                    await viewModel.loadUser(user.username);
                                  }
                                } catch (error) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to update: $error',
                                        ),
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.error,
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFED1C2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              buttonLabel,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    // Cancel button
                    TextButton(
                      onPressed: () {
                        viewModel.clearOTPState();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    ).whenComplete(() {
      // Cleanup OTP state when sheet is dismissed
      viewModel.clearOTPState();
    });
  }

  void _showOTPVerificationSheet(
    BuildContext context,
    UserViewModel viewModel,
    String currentUsername,
    String otpId,
    VoidCallback onSuccess,
  ) {
    final otpController = TextEditingController();
    String? otpError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // Prevent accidental dismissal
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Title
                  Text(
                    'Verify Email',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the OTP sent to your new email',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // OTP Input (6 digits)
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: 'OTP',
                      hintText: '000000',
                      errorText: otpError,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    onChanged: (value) {
                      if (otpError != null) {
                        setModalState(() {
                          otpError = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  // Verify & Save button
                  ElevatedButton(
                    onPressed: viewModel.isVerifyingOTP
                        ? null
                        : () async {
                            final otp = otpController.text.trim();
                            if (otp.length != 6) {
                              setModalState(() {
                                otpError = 'Please enter a 6-digit OTP';
                              });
                              return;
                            }

                            try {
                              await viewModel.verifyEmailUpdateOTP(
                                id: otpId,
                                otp: otp,
                                currentUsername: currentUsername,
                              );
                              if (mounted) {
                                onSuccess();
                              }
                            } catch (error) {
                              if (mounted) {
                                setModalState(() {
                                  otpError =
                                      viewModel.otpError ??
                                      'Invalid OTP. Please try again.';
                                });
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFED1C2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: viewModel.isVerifyingOTP
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Verify & Save',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  // Cancel button
                  TextButton(
                    onPressed: () {
                      viewModel.clearOTPState();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      // Cleanup OTP state when sheet is dismissed
      viewModel.clearOTPState();
    });
  }

  void _showProfilePictureOptions(
    BuildContext context,
    UserViewModel viewModel,
    UserModel user,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Profile Picture',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAndUploadProfilePicture(context, viewModel, user);
                },
              ),
              if (user.profilePicture != null &&
                  user.profilePicture!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Remove Current Photo',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    // Show confirmation dialog
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Remove Photo'),
                        content: const Text(
                          'Are you sure you want to remove your profile photo?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red,
                            ),
                            child: const Text('Remove'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && mounted) {
                      try {
                        // Show loading dialog
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (loadingContext) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        await viewModel.removeProfilePicture();

                        if (mounted) {
                          Navigator.pop(context); // Close loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Profile photo removed'),
                            ),
                          );
                          // Reload user to refresh UI
                          await viewModel.loadUser(user.username);
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context); // Close loading dialog
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to remove photo: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadProfilePicture(
    BuildContext context,
    UserViewModel viewModel,
    UserModel user,
  ) async {
    print('📸 Edit profile picture button tapped');
    try {
      // Pick image file
      print('   📂 Opening file picker...');

      // Check if context is still mounted before opening file picker
      if (!mounted) return;

      // Wrap file picker in try-catch to handle back button press gracefully
      FilePickerResult? result;
      bool userCancelled = false;
      try {
        // Set flag to track that file picker is open
        setState(() {
          _isPickingFile = true;
        });

        result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          allowMultiple: false,
        );
      } catch (pickerError) {
        // User pressed back or cancelled - handle gracefully
        print('   ℹ️ File picker cancelled or closed: $pickerError');
        userCancelled = true;
      } finally {
        // Always reset flag when file picker closes
        if (mounted) {
          setState(() {
            _isPickingFile = false;
          });
        }
      }

      // Check if user cancelled or result is null
      if (userCancelled || result == null) {
        // Check if we're at root route - if so, show exit dialog
        if (mounted && !context.canPop()) {
          // Small delay to ensure file picker is fully closed
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted && !context.canPop()) {
            final shouldExit = await _showExitAppDialog();
            if (shouldExit == true && mounted) {
              SystemNavigator.pop();
            }
          }
        }
        return;
      }

      // Check if context is still mounted after file picker
      if (!mounted) return;

      // Check if result is invalid (user cancelled or no file selected)
      if (result.files.isEmpty || result.files.single.path == null) {
        print('   ℹ️ User cancelled file selection');
        // Check if we're at root route - if so, show exit dialog
        if (mounted && !context.canPop()) {
          // Small delay to ensure file picker is fully closed
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted && !context.canPop()) {
            final shouldExit = await _showExitAppDialog();
            if (shouldExit == true && mounted) {
              SystemNavigator.pop();
            }
          }
        }
        return; // User cancelled - return gracefully
      }

      print('   ✅ File selected: ${result.files.single.path}');

      final filePath = result.files.single.path;
      final pickedFile = result.files.single;

      // Check if we have file bytes (web platform) or file path (mobile platforms)
      int? fileSizeBytes;
      File? imageFile;

      if (pickedFile.bytes != null) {
        // Web platform: use bytes directly
        fileSizeBytes = pickedFile.bytes!.length;
        print(
          '   📊 File size from bytes: ${FileValidationUtils.formatFileSize(fileSizeBytes)}',
        );
      } else if (filePath != null) {
        // Mobile platforms: use file path
        imageFile = File(filePath);
        try {
          fileSizeBytes = imageFile.lengthSync();
          print(
            '   📊 File size from path: ${FileValidationUtils.formatFileSize(fileSizeBytes)}',
          );
        } catch (e) {
          print('   ❌ Error reading file size: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Unable to read file size. Please try selecting a different image.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }
      } else {
        print('   ❌ No file path or bytes available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Unable to access selected file. Please try again.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if file is a valid image (jpg, jpeg, png)
      final fileName = pickedFile.name.toLowerCase();
      if (!FileValidationUtils.isValidImageExtension(fileName)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a JPG or PNG image'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Validate file size before upload (client-side validation to match web behavior)
      print(
        '   🔍 Validating file size: ${FileValidationUtils.formatFileSize(fileSizeBytes)}',
      );

      if (fileSizeBytes > FileValidationUtils.maxProfilePictureSizeBytes) {
        print(
          '   ❌ File size validation failed: ${FileValidationUtils.formatFileSize(fileSizeBytes)} exceeds ${FileValidationUtils.formatFileSize(FileValidationUtils.maxProfilePictureSizeBytes)}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Image size should be less than 10 MB. Please choose a smaller image.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      print('   ✅ File size validation passed, proceeding with upload...');

      // Ensure we have a File object for upload
      // On mobile platforms, imageFile is already set from the file path
      // On web, we need to use the file path (FilePicker provides it)
      if (imageFile == null && filePath != null) {
        imageFile = File(filePath);
      }

      if (imageFile == null) {
        print('   ❌ Unable to create file object for upload');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to process file. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // Upload profile picture
        print('   📤 Uploading profile picture...');
        await viewModel.uploadProfilePicture(imageFile);

        // Reload user to get updated profile picture
        print('   🔄 Reloading user data...');
        // Reload both current user and viewed user to ensure both are updated
        await viewModel.loadCurrentUser();
        await viewModel.loadUser(user.username);

        if (mounted) {
          // Force cache refresh for iOS by updating cache-bust timestamp
          setState(() {
            _profilePictureCacheBust = DateTime.now().millisecondsSinceEpoch;
          });

          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile picture updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          print('   ✅ Profile picture updated successfully');
          print(
            '   📸 Updated profile picture path: ${viewModel.viewedUser?.profilePicture}',
          );
        }
      } catch (uploadError) {
        print('   ❌ Upload error: $uploadError');
        if (mounted) {
          // Close loading dialog if still open
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload profile picture: $uploadError'),
              backgroundColor: Colors.red,
            ),
          );
        }
        rethrow;
      }
    } catch (error) {
      print('   ❌ Error in _pickAndUploadProfilePicture: $error');
      if (mounted) {
        // Close loading dialog if still open
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload profile picture: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool?> _showExitAppDialog() async {
    return showDialog<bool>(
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
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    // Responsive padding based on screen size
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = screenWidth > 640
        ? const EdgeInsets.symmetric(vertical: 20, horizontal: 16)
        : const EdgeInsets.symmetric(vertical: 16, horizontal: 12);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.clip,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatefulWidget {
  const _EditableField({
    required this.label,
    required this.value,
    required this.controller,
    required this.isEditing,
    required this.isLoading,
    required this.onTap,
    required this.onSave,
    required this.onCancel,
    this.isUsername = false,
    this.currentUsername,
    this.isMultiline = false,
  });

  final String label;
  final String value;
  final TextEditingController controller;
  final bool isEditing;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool isUsername;
  final String? currentUsername;
  final bool isMultiline;

  @override
  State<_EditableField> createState() => _EditableFieldState();
}

class _EditableFieldState extends State<_EditableField> {
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAvailability(String username) async {
    if (username.trim().isEmpty) {
      context.read<UserViewModel>().clearUsernameAvailability();
      return;
    }

    if (widget.currentUsername != null &&
        username.trim() == widget.currentUsername) {
      context.read<UserViewModel>().clearUsernameAvailability();
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9_]{3,}$').hasMatch(username.trim())) {
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      context.read<UserViewModel>().checkUsernameAvailability(username.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final userViewModel = context.watch<UserViewModel>();
    final isChecking =
        widget.isUsername && userViewModel.isCheckingAvailability;
    final availabilityMessage = widget.isUsername
        ? userViewModel.usernameAvailabilityMessage
        : null;
    final isAvailable = widget.isUsername
        ? userViewModel.isUsernameAvailable
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget.isEditing
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: widget.controller,
                    autofocus: true,
                    enabled: !widget.isLoading,
                    maxLines: widget.isMultiline ? 4 : 1,
                    keyboardType: widget.label.toLowerCase() == 'email'
                        ? TextInputType.emailAddress
                        : (widget.isMultiline
                              ? TextInputType.multiline
                              : TextInputType.text),
                    decoration: InputDecoration(
                      labelText: widget.label,
                      hintText: 'Enter ${widget.label.toLowerCase()}',
                      helperText: widget.isUsername
                          ? 'Letters, numbers, or underscores only.'
                          : null,
                      suffixIcon: widget.isUsername
                          ? (isChecking
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: const Padding(
                                      padding: EdgeInsets.all(12),
                                      child: InlineShimmer(
                                        width: 20,
                                        height: 20,
                                      ),
                                    ),
                                  )
                                : isAvailable == true &&
                                      widget.controller.text.trim() !=
                                          widget.currentUsername
                                ? Icon(
                                    Icons.check_circle,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : isAvailable == false
                                ? Icon(
                                    Icons.cancel,
                                    color: Theme.of(context).colorScheme.error,
                                  )
                                : null)
                          : null,
                      helperMaxLines: 2,
                    ),
                    textInputAction: widget.isMultiline
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    onChanged: widget.isUsername ? _checkAvailability : null,
                    onFieldSubmitted: (_) {
                      if (widget.isUsername) {
                        if (isAvailable != false &&
                            widget.controller.text.trim().isNotEmpty &&
                            widget.controller.text.trim() !=
                                widget.currentUsername) {
                          widget.onSave();
                        }
                      } else {
                        if (!widget.isMultiline &&
                            widget.controller.text.trim().isNotEmpty) {
                          widget.onSave();
                        }
                      }
                    },
                    onTapOutside: (_) {
                      FocusScope.of(context).unfocus();
                      if (widget.isUsername) {
                        if (isAvailable != false &&
                            widget.controller.text.trim().isNotEmpty &&
                            widget.controller.text.trim() !=
                                widget.currentUsername) {
                          widget.onSave();
                        } else {
                          widget.onCancel();
                        }
                      } else {
                        if (widget.controller.text.trim() != widget.value) {
                          widget.onSave();
                        } else {
                          widget.onCancel();
                        }
                      }
                    },
                  ),
                  if (availabilityMessage != null && !isChecking) ...[
                    const SizedBox(height: 4),
                    Text(
                      availabilityMessage,
                      style: TextStyle(
                        fontSize: 12,
                        color: isAvailable == true
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              )
            : InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.value,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }
}

class _VideoGridItem extends StatelessWidget {
  const _VideoGridItem({
    required this.video,
    required this.onTap,
    this.onDelete,
  });

  final VideoModel video;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  String? get _thumbnailUrl {
    return ImageUtils.getVideoThumbnailUrl(video.videoThumbnail);
  }

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Navigation layer (at the bottom of the stack)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
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
                  : Image.network(
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
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ), // 1.5 Processing Overlay
          if (video.status == 'temp')
            IgnorePointer(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: Icon(Icons.sync, color: Colors.white70, size: 24),
                ),
              ),
            ),
          // 2. Processing indicator overlay (non-interactive) – only when processing
          if (video.status == 'temp')
            Positioned(
              top: 8,
              right: 8,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            ),
          // 3. More menu (interactive layer on top)
          if (onDelete != null && video.status != 'temp')
            Positioned(
              bottom: 4,
              right: 4,
              child: Material(
                color: Colors.transparent,
                child: PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert,
                    color: Colors.white,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 120),
                  onSelected: (value) {
                    if (value == 'delete') {
                      onDelete?.call();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline,
                            size: 20,
                            color: Colors.red,
                          ),
                          SizedBox(width: 12),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          // 4. Gradient and text (non-interactive)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                  ),
                ),
                padding: const EdgeInsets.only(
                  left: 12,
                  top: 12,
                  bottom: 12,
                  right: 32, // Space for the more menu
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      video.videoTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.thumb_up,
                          size: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(video.videoUpvotes),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
