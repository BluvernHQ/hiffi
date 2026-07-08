import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../auth/data/auth_repository.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';
import '../../domain/profile_banner_theme.dart';
import '../viewmodels/user_view_model.dart';
import '../widgets/profile_about_card.dart';
import '../widgets/profile_cover_banner.dart';
import '../widgets/profile_referral_card.dart';
import '../widgets/profile_stat_column.dart';
import '../widgets/profile_video_section.dart';
import '../../../video/presentation/viewmodels/video_view_model.dart';
import '../../../flags/presentation/widgets/report_flag_sheet.dart';
import '../../../../core/analytics/analytics_capture.dart';
import '../../../../core/analytics/analytics_tags.dart';
import '../../../../core/utils/compact_count.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/utils/error_toast_utils.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/widgets/network_page_shell.dart';
import 'edit_profile_page.dart';

const _profileRed = Color(0xFFED1C2F);
const _minSocialCountDisplay = 10000;

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key, required this.username});

  final String username;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  UserModel? _currentLoggedInUser;

  bool _hasAttemptedLoad = false;
  List<VideoModel> _userVideos = [];
  bool _isLoadingVideos =
      true; // Start as true to prevent showing "no videos" before load
  bool _hasAttemptedLoadVideos =
      false; // Track if we've attempted to load videos
  String? _videosError;
  int _profilePictureCacheBust = 0; // Cache-busting timestamp for iOS

  @override
  void initState() {
    super.initState();
    // Start loading immediately to prevent showing "User not found" before loading starts
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authRepository = context.read<AuthRepository>();
      final isAuthenticated = authRepository.currentUser != null;

      final viewModel = context.read<UserViewModel>();
      final userRepository = context.read<UserRepository>();

      // Mark that we've attempted to load
      _hasAttemptedLoad = true;

      if (isAuthenticated) {
        // Load current logged-in user for own-profile / follow UI
        try {
          final currentUser = await userRepository.getCurrentUser();
          if (mounted) {
            setState(() {
              _currentLoggedInUser = currentUser;
            });
          }
        } catch (e) {
          debugPrint('Failed to load current user: $e');
        }
      }

      // Load the profile user (public read)
      await viewModel.loadUser(widget.username);

      final isOwnProfile =
          _currentLoggedInUser?.username == widget.username;
      if (!isOwnProfile && mounted) {
        unawaited(
          AnalyticsCapture.click(
            context,
            elementUiName: AnalyticsTags.viewedProfileOf(widget.username),
            screenName: 'profile',
          ),
        );
      }

      // Load user videos for own profile or creators with uploads
      final viewedUser = viewModel.viewedUser;
      if (viewedUser != null) {
        final isOwn = _currentLoggedInUser?.username == widget.username;
        if (isOwn ||
            viewedUser.role == 'creator' ||
            viewedUser.totalVideos > 0) {
          await _loadUserVideos(widget.username);
        }
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
          _videosError = isOfflineError(e)
              ? offlineUserMessage
              : 'Could not load videos. Please try again.';
          _isLoadingVideos = false;
        });
      }
    }
  }

  UserModel _profileShellUser() {
    final username = widget.username.trim();
    final displayName = username.isEmpty
        ? 'User'
        : username[0].toUpperCase() + username.substring(1);
    return UserModel(username: username, name: displayName);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserViewModel>();
    // Use viewedUser for the profile being displayed, not currentUser
    final user = viewModel.viewedUser;
    final isOffline = isOfflineErrorMessage(viewModel.errorMessage);
    final displayUser = user ?? _profileShellUser();
    final isOwnProfile = _currentLoggedInUser?.username == widget.username;

    // Debug: Log current state
    debugPrint(
      'ProfilePage build: user=${user?.username}, isLoading=${viewModel.isLoading}, error=${viewModel.errorMessage}',
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          title: const SizedBox.shrink(),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _profileRed),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          iconTheme: const IconThemeData(color: _profileRed),
        ),
        body: NetworkPageShell(
                hasCachedContent: user != null,
                isLoading:
                    (user == null && viewModel.isLoading) ||
                    (!_hasAttemptedLoad && user == null),
                emptyDescription:
                    'Connect to the internet to view this profile.',
                onRetry: () => viewModel.loadUser(widget.username),
                child: ((!_hasAttemptedLoad && user == null) ||
                        (user == null && viewModel.isLoading && !isOffline))
                    ? const ProfileShimmer()
                    : user == null &&
                          viewModel.errorMessage != null &&
                          !isOffline
                    ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        viewModel.errorMessage!.toLowerCase().contains(
                              'not found',
                            )
                            ? Icons.person_off
                            : Icons.error_outline_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        viewModel.errorMessage!.toLowerCase().contains(
                              'not found',
                            )
                            ? 'User not found'
                            : 'Something went wrong',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viewModel.errorMessage!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => viewModel.loadUser(widget.username),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            : RefreshIndicator(
                onRefresh: () async {
                  await viewModel.loadUser(widget.username);
                  final refreshedUser = viewModel.viewedUser;
                  if (refreshedUser != null) {
                    final isOwn =
                        _currentLoggedInUser?.username == widget.username;
                    if (isOwn ||
                        refreshedUser.role == 'creator' ||
                        refreshedUser.totalVideos > 0) {
                      await _loadUserVideos(widget.username);
                    }
                  }
                },
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: _buildProfileHeader(
                        context,
                        displayUser,
                        isOwnProfile && user != null,
                        viewModel,
                        showReportButton:
                            !isOwnProfile && user != null && !isOffline,
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        0,
                        16,
                        32 + MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          if (user != null) ...[
                            _buildStatsCard(context, user),
                            if (user.totalVideos > 0 ||
                                user.followers >= _minSocialCountDisplay ||
                                user.following >= _minSocialCountDisplay)
                              const SizedBox(height: 16),
                            if (user.bio != null && user.bio!.trim().isNotEmpty)
                              ProfileAboutCard(bio: user.bio!),
                            if (user.bio != null && user.bio!.trim().isNotEmpty)
                              const SizedBox(height: 16),
                          ],
                          if (!isOwnProfile &&
                              _currentLoggedInUser != null &&
                              user != null) ...[
                            _buildFollowButton(context, viewModel, user),
                            const SizedBox(height: 16),
                          ],
                          if (user != null &&
                              (isOwnProfile ||
                                  user.role == 'creator' ||
                                  user.totalVideos > 0))
                            ProfileVideoSection(
                              isOwnProfile: isOwnProfile,
                              sectionTitle: _videoSectionTitle(
                                isOwnProfile,
                                user,
                              ),
                              videos: _userVideos,
                              isLoading: _isLoadingVideos,
                              hasAttemptedLoad: _hasAttemptedLoadVideos,
                              errorMessage: _videosError,
                              onRetry: () => _loadUserVideos(widget.username),
                              onVideoTap: (video) {
                                unawaited(
                                  AnalyticsCapture.videoOpened(
                                    context,
                                    openUiName:
                                        AnalyticsTags.openedVideoFromProfile,
                                    screenName: 'profile',
                                    videoId: video.videoId,
                                    videoTitle: video.videoTitle,
                                    source: 'profile',
                                  ),
                                );
                                context.push(
                                  '/video/${video.videoId}',
                                  extra: video,
                                );
                              },
                              onDelete: isOwnProfile
                                  ? (video) =>
                                        _showDeleteConfirmation(context, video)
                                  : null,
                              onUpload: isOwnProfile
                                  ? () => context.push('/studio')
                                  : null,
                            )
                          else if (isOffline)
                            const ProfileVideosOfflinePlaceholder(),
                          if (isOwnProfile && user != null) ...[
                            const SizedBox(height: 16),
                            ProfileReferralCard(
                              referralUrl:
                                  'https://hiffi.com/referrar/${user.username.toLowerCase()}',
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
              ),
      ),
    );
  }

  String _videoSectionTitle(bool isOwnProfile, UserModel user) {
    final videoCount =
        _hasAttemptedLoadVideos ? _userVideos.length : user.totalVideos;
    if (videoCount > 0) {
      return isOwnProfile
          ? 'My Videos ($videoCount)'
          : 'Videos ($videoCount)';
    }
    return isOwnProfile ? 'My Videos' : 'Videos';
  }

  String _formatJoinedDate(DateTime? date) {
    if (date == null) return '';
    return 'Joined ${DateFormat('MMMM yyyy').format(date)}';
  }

  Future<void> _shareProfile(UserModel user) async {
    final url = 'https://hiffi.com/users/${user.username.toLowerCase()}';
    await Share.share('Check out ${user.name} on Hiffi\n$url');
  }

  Future<void> _openEditProfile(UserModel user, UserViewModel viewModel) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => EditProfilePage(user: user),
      ),
    );
    if (mounted) {
      await viewModel.loadUser(user.username);
      setState(() {
        _profilePictureCacheBust = DateTime.now().millisecondsSinceEpoch;
      });
    }
  }

  Widget _buildProfileHeader(
    BuildContext context,
    UserModel user,
    bool isOwnProfile,
    UserViewModel viewModel, {
    bool showReportButton = false,
  }) {
    const fadeBackground = Color(0xFFFAFAFA);
    const avatarRadius = 40.0;
    final bannerHeight =
        profileBannerHeightForWidth(MediaQuery.sizeOf(context).width);
    final joinedLabel = _formatJoinedDate(user.createdAt);
    final isCreator = user.role == 'creator';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: bannerHeight + avatarRadius,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: ProfileCoverBanner(
                  coverUrl: user.coverUrl,
                  displayName: user.name,
                  username: user.username,
                  height: bannerHeight,
                  fadeBackground: fadeBackground,
                ),
              ),
              Positioned(
                left: 16,
                top: bannerHeight - avatarRadius,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
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
                    if (user.status?.isLive == true)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Padding(
                padding: EdgeInsets.only(right: showReportButton ? 52 : 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            user.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1A1A1A),
                                ),
                          ),
                        ),
                        if (isCreator) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified,
                            color: Color(0xFF1D9BF0),
                            size: 22,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${user.username.toLowerCase()}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF8A8A8A),
                      ),
                    ),
                    if (joinedLabel.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            joinedLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: const Color(0xFF9A9A9A),
                                ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (isOwnProfile)
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _openEditProfile(user, viewModel),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _profileRed,
                                side: const BorderSide(
                                  color: _profileRed,
                                  width: 1.5,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Edit Profile',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => _shareProfile(user),
                              style: FilledButton.styleFrom(
                                backgroundColor: _profileRed,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                              ),
                              child: const Text(
                                'Share Profile',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (showReportButton)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: const Color(0xFFFFF0F2),
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () => _reportUser(user),
                      customBorder: const CircleBorder(),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.flag_outlined,
                          color: _profileRed,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStatsCard(BuildContext context, UserModel user) {
    final showFollowers = user.followers >= _minSocialCountDisplay;
    final showFollowing = user.following >= _minSocialCountDisplay;
    final showVideos = user.totalVideos > 0;

    final stats = <({String value, String label})>[
      if (showVideos)
        (value: user.totalVideos.toString(), label: 'VIDEOS'),
      if (showFollowers)
        (value: formatCompactCount(user.followers), label: 'FOLLOWERS'),
      if (showFollowing)
        (value: formatCompactCount(user.following), label: 'FOLLOWING'),
    ];

    if (stats.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E8E8)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Colors.grey.shade300,
                ),
              Expanded(
                child: ProfileStatColumn(
                  value: stats[i].value,
                  label: stats[i].label,
                ),
              ),
            ],
          ],
        ),
      ),
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
                    final wasFollowing = user.isFollowing == true;
                    if (wasFollowing) {
                      await viewModel.unfollowUser(widget.username);
                    } else {
                      await viewModel.followUser(widget.username);
                    }
                    if (mounted) {
                      unawaited(
                        AnalyticsCapture.click(
                          context,
                          elementUiName: wasFollowing
                              ? AnalyticsTags.unfollowedCreator
                              : AnalyticsTags.followedCreator,
                          screenName: 'profile',
                        ),
                      );
                    }
                  } catch (e) {
                    // Rapid taps can surface idempotent backend responses; avoid
                    // showing a scary error for "already following"/"not following".
                    if (e is ApiException && e.statusCode == 400) {
                      final msg = e.message.toLowerCase();
                      if (msg.contains('not following') ||
                          msg.contains("aren't following") ||
                          msg.contains('are not following') ||
                          msg.contains('already following') ||
                          msg.contains('already followed')) {
                        return;
                      }
                    }
                    if (mounted) {
                      showCatchToast(
                        context,
                        e,
                        fallback: user.isFollowing == true
                            ? 'Could not unfollow. Please try again.'
                            : 'Could not follow. Please try again.',
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

  Future<void> _reportUser(UserModel user) async {
    final authRepository = context.read<AuthRepository>();
    if (authRepository.currentUser == null) {
      final currentRoute = '/users/${widget.username}';
      if (!mounted) return;
      context.push('/login?returnTo=${Uri.encodeComponent(currentRoute)}');
      return;
    }
    if (!mounted) return;
    unawaited(
      AnalyticsCapture.click(
        context,
        elementUiName: AnalyticsTags.reportProfile,
        screenName: 'profile',
      ),
    );
    await ReportFlagSheet.show(
      context,
      title: 'user',
      reportType: user.role == 'creator' ? 'creator' : 'user',
      targetId: user.uid ?? user.username,
      targetType: user.role == 'creator' ? 'creator' : 'user',
      metadata: {'username': user.username, 'display_name': user.name},
    );
  }
}
