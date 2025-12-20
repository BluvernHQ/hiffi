import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';
import '../viewmodels/user_view_model.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/shimmer_widgets.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.username});

  final String username;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  bool _isEditingName = false;
  bool _isEditingEmail = false;
  bool _isEditingBio = false;
  UserModel? _currentLoggedInUser;

  bool _hasAttemptedLoad = false;
  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos = false;
  String? _videosError;

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
          context.push('/login');
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

      // Load user videos if viewing own profile
      if (_currentLoggedInUser?.username == widget.username) {
        await _loadUserVideos();
      }
    });
  }

  Future<void> _loadUserVideos() async {
    setState(() {
      _isLoadingVideos = true;
      _videosError = null;
    });

    try {
      final videoRepository = context.read<VideoRepository>();
      final videos = await videoRepository.getUserVideos(
        limit: 20,
        offset: 0,
        seed: 'profile_videos',
      );
      if (mounted) {
        setState(() {
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
    _bioController.dispose();
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
    if (user != null &&
        _bioController.text != (user.bio ?? '') &&
        !_isEditingBio) {
      _bioController.text = user.bio ?? '';
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (isOwnProfile && user != null)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => _showEditProfileDialog(context, user, viewModel),
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
          : viewModel.isLoading || (!_hasAttemptedLoad && user == null)
          ? const ProfileShimmer()
          : viewModel.errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    viewModel.errorMessage ?? 'Failed to load profile',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      viewModel.loadUser(widget.username);
                    },
                    child: const Text('Retry'),
                  ),
                ],
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
                if (isOwnProfile) {
                  await _loadUserVideos();
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
                        const SizedBox(height: 16),
                        // Follow/Unfollow button for other users
                        if (!isOwnProfile && _currentLoggedInUser != null)
                          _buildFollowButton(context, viewModel, user),
                        // About Card with Stats
                        _buildAboutCard(context, user, isOwnProfile, viewModel),
                        const SizedBox(height: 24),
                        // Videos Section
                        if (isOwnProfile) _buildUserVideosSection(context),
                        const SizedBox(height: 32),
                      ]),
                    ),
                  ),
                ],
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
          decoration: const BoxDecoration(
            image: DecorationImage(
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
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: avatarRadius,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: avatarRadius - 2,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          backgroundImage: () {
                            final profileUrl =
                                user.profilePicture != null &&
                                    user.profilePicture!.isNotEmpty
                                ? ImageUtils.getProfileImageUrl(
                                    user.profilePicture!,
                                  )
                                : null;
                            final avatarUrl =
                                user.avatarUrl != null &&
                                    user.avatarUrl!.isNotEmpty
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
                                  (user.avatarUrl == null ||
                                      user.avatarUrl!.isEmpty)
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : 'U',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineLarge
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                      ),
                                )
                              : null,
                        ),
                      ),
                      // Edit Icon Overlay (only for own profile)
                      if (isOwnProfile)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6B35),
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
                    ],
                  ),
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
                        '@${user.username}',
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
          onPressed: viewModel.isLoading
              ? null
              : () async {
                  try {
                    if (user.isFollowing == true) {
                      await viewModel.unfollowUser(widget.username);
                    } else {
                      await viewModel.followUser(widget.username);
                    }
                    await viewModel.loadUser(widget.username);
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
            backgroundColor: const Color(0xFFFF6B35),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: viewModel.isLoading
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
          if (isOwnProfile)
            _EditableField(
              label: 'Bio',
              value: user.bio ?? '',
              controller: _bioController,
              isEditing: _isEditingBio,
              isLoading: viewModel.isLoading,
              onTap: () {
                setState(() {
                  _isEditingBio = true;
                });
              },
              onSave: () async {
                await _saveBio(viewModel, user);
              },
              onCancel: () {
                setState(() {
                  _isEditingBio = false;
                  _bioController.text = user.bio ?? '';
                });
              },
              isMultiline: true,
            )
          else if (user.bio != null && user.bio!.isNotEmpty)
            Text(user.bio!, style: Theme.of(context).textTheme.bodyMedium)
          else
            Text(
              'No bio available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          // Email (own profile only)
          if (isOwnProfile && user.email != null) ...[
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
          // Stats Section
          const SizedBox(height: 24),
          Text(
            'Stats',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  value: user.totalVideos.toString(),
                  label: 'VIDEOS',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  value: user.followers.toString(),
                  label: 'FOLLOWERS',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatBox(
                  value: user.following.toString(),
                  label: 'FOLLOWING',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUserVideosSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'My Videos',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        if (_isLoadingVideos)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          )
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
                    onPressed: _loadUserVideos,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (_userVideos.isEmpty)
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
        else
          _buildVideoGrid(context),
      ],
    );
  }

  Widget _buildVideoGrid(BuildContext context) {
    // Responsive grid: 1 column on mobile, 2 on tablet, 3-4 on desktop
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth > 1024
        ? 4
        : screenWidth > 640
        ? 2
        : 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
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
        );
      },
    );
  }

  void _showEditProfileDialog(
    BuildContext context,
    UserModel user,
    UserViewModel viewModel,
  ) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email ?? '');
    final bioController = TextEditingController(text: user.bio ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Name field
              TextField(
                controller: nameController,
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
                  labelText: 'Email',
                  hintText: 'Enter your email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
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
              // Save button
              ElevatedButton(
                onPressed: viewModel.isLoading
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

                        try {
                          // Update user
                          await viewModel.updateUser(
                            currentUsername: user.username,
                            name: newName,
                            email: newEmail.isEmpty ? null : newEmail,
                            bio: newBio.isEmpty ? null : newBio,
                          );

                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully'),
                              ),
                            );
                            // Reload user to get updated data
                            await viewModel.loadUser(user.username);
                          }
                        } catch (error) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update: $error'),
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: viewModel.isLoading
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
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 16),
              // Cancel button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveBio(UserViewModel viewModel, UserModel user) async {
    final newBio = _bioController.text.trim();

    if (newBio == (user.bio ?? '')) {
      setState(() {
        _isEditingBio = false;
      });
      return;
    }

    try {
      await viewModel.updateUser(
        currentUsername: user.username,
        bio: newBio.isEmpty ? null : newBio,
      );
      if (mounted) {
        setState(() {
          _isEditingBio = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bio updated successfully')),
        );
        // Reload user to get updated data
        await viewModel.loadUser(user.username);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $error'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
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
  const _VideoGridItem({required this.video, required this.onTap});

  final VideoModel video;
  final VoidCallback onTap;

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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              _thumbnailUrl == null || _thumbnailUrl!.isEmpty
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
                      Icon(Icons.visibility, size: 12, color: Colors.white),
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
              // Gradient overlay for better text readability
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
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
            ],
          ),
        ),
      ),
    );
  }
}
