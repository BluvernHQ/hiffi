import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter_estatisticas/umami_navigation_observer.dart';
import 'package:flutter_estatisticas/umami_service.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/auth_page.dart';
import '../../features/auth/presentation/views/referral_entry_page.dart';
import '../../features/home/presentation/views/home_page.dart';
import '../../features/following/presentation/views/following_page.dart';
import '../../features/liked/presentation/views/liked_videos_page.dart';
import '../../features/watch_history/presentation/views/watch_history_page.dart';

import '../../features/upload/presentation/views/video_upload_page.dart';
import '../../features/user/presentation/views/become_creator_page.dart';
import '../../features/user/presentation/views/user_profile_page.dart';
import '../../features/video/domain/models/video_model.dart';
import '../../features/video/presentation/views/video_player_page.dart';
import 'video_player_route_extra.dart';
import '../../features/video/presentation/views/watch_screen.dart';
import '../../features/search/presentation/views/search_results_page.dart';
import '../../features/playlist/presentation/views/playlists_page.dart';
import '../../features/playlist/presentation/views/playlist_detail_page.dart';

class AppRouter {
  /// For [RouteAware] on [VideoPlayerPage] (PiP eligibility when another route covers the player).
  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  AppRouter({
    required AuthRepository authRepository,
    FirebaseAnalytics? analytics,
    UmamiService? umamiService,
  }) : _authRepository = authRepository,
       _analytics = analytics ?? FirebaseAnalytics.instance,
       _umamiService =
           umamiService ??
           UmamiService(
             endpoint: 'https://analytics.superlabs.co',
             website: 'b7a2884e-fdec-4b9f-9ff8-29c5a4e63454',
             hostname: 'hiffi.com',
           ),
       _navigatorKey = GlobalKey<NavigatorState>() {
    _refreshListenable = RouterRefreshStream(
      _authRepository.authStateChanges(),
    );

    router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/home',
      refreshListenable: _refreshListenable,
      debugLogDiagnostics: true,
      observers: [
        routeObserver,
        FirebaseAnalyticsObserver(analytics: _analytics),
        UmamiNavigationObserver(_umamiService),
      ],
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) {
            // Get return route from query parameters
            final returnRoute = state.uri.queryParameters['returnTo'];
            return AuthPage(
              initialMode: AuthMode.signIn,
              returnRoute: returnRoute,
            );
          },
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) {
            // Get return route from query parameters
            final returnRoute = state.uri.queryParameters['returnTo'];
            return AuthPage(
              initialMode: AuthMode.signUp,
              returnRoute: returnRoute,
            );
          },
        ),
        GoRoute(
          path: '/r/:username',
          name: 'referral_entry',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return ReferralEntryPage(username: username);
          },
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/following',
          name: 'following',
          builder: (context, state) => const FollowingPage(),
        ),
        GoRoute(
          path: '/liked',
          name: 'liked_videos',
          builder: (context, state) => const LikedVideosPage(),
        ),
        GoRoute(
          path: '/watch-history',
          name: 'watch_history',
          builder: (context, state) => const WatchHistoryPage(),
        ),

        GoRoute(
          path: '/upload/video',
          name: 'video_upload',
          builder: (context, state) => const VideoUploadPage(),
        ),
        GoRoute(
          path: '/become-creator',
          name: 'become_creator',
          builder: (context, state) => const BecomeCreatorPage(),
        ),
        GoRoute(
          path: '/users/:username',
          name: 'user_profile',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return UserProfilePage(username: username);
          },
        ),
        GoRoute(
          path: '/video/:videoId',
          name: 'video_detail',
          builder: (context, state) {
            final videoId = state.pathParameters['videoId'] ?? '';
            // Try to get video from extra first, then from cache
            final extra = state.extra;
            VideoModel? video;
            Duration? initialResumePosition;
            if (extra is VideoPlayerRouteExtra) {
              video = extra.video;
              initialResumePosition = extra.initialResumePosition;
            } else {
              video = extra as VideoModel?;
            }
            bool returningFromAuth = false;

            if (video == null) {
              // Try to get from VideoPlayerPage cache (e.g., after returning from auth)
              final cachedVideo = VideoPlayerPage.getCachedVideo(videoId);
              if (cachedVideo != null) {
                video = cachedVideo;
                returningFromAuth = true; // Mark that we're returning from auth
                // Clear cache after use
                VideoPlayerPage.clearCache();
              }
            }
            if (video == null) {
              // If no video provided and not in cache, throw error
              throw Exception('VideoModel is required');
            }
            return VideoPlayerPage(
              video: video,
              videoId: videoId,
              returningFromAuth: returningFromAuth,
              initialResumePosition: initialResumePosition,
            );
          },
        ),
        GoRoute(
          path: '/watch/:videoId',
          name: 'watch_video',
          builder: (context, state) {
            final videoId = state.pathParameters['videoId'] ?? '';
            final playlistId = state.uri.queryParameters['playlist'];
            final pindex = int.tryParse(
              state.uri.queryParameters['pindex'] ?? '',
            );
            final isCurated = state.uri.queryParameters['curated'] == '1';

            if (videoId.isEmpty) {
              // Invalid deep link: send to home instead of crashing.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/home');
              });
              return const SizedBox.shrink();
            }

            return WatchScreen(
              videoId: videoId,
              playlistId: playlistId,
              playlistIndex: pindex,
              isCuratedPlaylist: isCurated,
            );
          },
        ),
        GoRoute(
          path: '/playlists',
          name: 'playlists',
          builder: (context, state) => const PlaylistsPage(),
        ),
        GoRoute(
          path: '/playlists/:playlistId',
          name: 'playlist_detail',
          builder: (context, state) {
            final playlistId = state.pathParameters['playlistId'] ?? '';
            return PlaylistDetailPage(playlistId: playlistId);
          },
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) {
            final query = state.uri.queryParameters['q'] ?? '';
            return SearchResultsPage(query: query);
          },
        ),
      ],
      redirect: (context, state) {
        final authViewModel = _readAuthViewModel(context);
        final isPostSignUpPending =
            authViewModel?.isPostSignUpRedirectPending ?? false;

        if (isPostSignUpPending) {
          return state.uri.path == '/login' ? null : '/login';
        }

        final isLoggedIn = _authRepository.currentUser != null;
        final loggingIn = state.uri.path == '/login';
        final signingUp = state.uri.path == '/signup';
        final uploading =
            state.uri.path == '/upload' || state.uri.path == '/upload/video';
        final onProfile = state.uri.path.startsWith('/users/');
        final onHome = state.uri.path == '/home';
        final onFollowing = state.uri.path == '/following';
        final onVideo = state.uri.path.startsWith('/video/');
        final onWatch = state.uri.path.startsWith('/watch/');
        final onSearch = state.uri.path == '/search';
        final onPlaylists = state.uri.path.startsWith('/playlists');
        final onReferral = state.uri.path.startsWith('/r/');

        if (!isLoggedIn) {
          if (onPlaylists) {
            return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
          }
          final onLiked = state.uri.path == '/liked';
          if (onLiked) {
            return '/login?returnTo=/liked';
          }
          final onWatchHistory = state.uri.path == '/watch-history';
          if (onWatchHistory) {
            return '/login?returnTo=/watch-history';
          }
          // Allow access to home, video player, upload pages, and auth pages without authentication
          // Profile pages require authentication - redirect to home (login is optional)
          if (onProfile) {
            return '/home';
          }
          // Allow access to these pages without authentication
          if (loggingIn ||
              signingUp ||
              uploading ||
              onHome ||
              onFollowing ||
              onVideo ||
              onWatch ||
              onSearch ||
              onReferral ||
              onPlaylists) {
            return null;
          }
          // For any other route, redirect to home
          return '/home';
        }

        // If logged in and on login/signup page, redirect to home
        if (loggingIn || signingUp) {
          return '/home';
        }

        return null;
      },
    );
  }

  late final GoRouter router;
  late final RouterRefreshStream _refreshListenable;
  final AuthRepository _authRepository;
  final GlobalKey<NavigatorState> _navigatorKey;

  final FirebaseAnalytics _analytics;
  final UmamiService _umamiService;

  FirebaseAnalytics get analytics => _analytics;
  UmamiService get umamiService => _umamiService;

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  void dispose() {
    _refreshListenable.dispose();
    router.dispose();
  }

  AuthViewModel? _readAuthViewModel(BuildContext context) {
    try {
      return context.read<AuthViewModel>();
    } catch (_) {
      return null;
    }
  }
}

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((user) {
      print(
        '🔄 Auth state changed: ${user != null ? "logged in" : "logged out"}',
      );
      // Notify listeners immediately to trigger router refresh
      notifyListeners();
      // Also schedule multiple notifications to ensure router processes the change
      Future.microtask(() {
        notifyListeners();
      });
      // Additional delayed notification to catch any race conditions
      Future.delayed(const Duration(milliseconds: 200), () {
        notifyListeners();
      });
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
