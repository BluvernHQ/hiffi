import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/auth_page.dart';
import '../../features/home/presentation/views/home_page.dart';
import '../../features/following/presentation/views/following_page.dart';

import '../../features/upload/presentation/views/video_upload_page.dart';
import '../../features/user/presentation/views/become_creator_page.dart';
import '../../features/user/presentation/views/user_profile_page.dart';
import '../../features/video/domain/models/video_model.dart';
import '../../features/video/presentation/views/video_player_page.dart';
import '../../features/search/presentation/views/search_results_page.dart';

class AppRouter {
  AppRouter({required AuthRepository authRepository})
    : _authRepository = authRepository,
      _navigatorKey = GlobalKey<NavigatorState>() {
    _refreshListenable = RouterRefreshStream(
      _authRepository.authStateChanges(),
    );

    router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/home',
      refreshListenable: _refreshListenable,
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: '/login',
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
          builder: (context, state) {
            // Get return route from query parameters
            final returnRoute = state.uri.queryParameters['returnTo'];
            return AuthPage(
              initialMode: AuthMode.signUp,
              returnRoute: returnRoute,
            );
          },
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),
        GoRoute(
          path: '/following',
          builder: (context, state) => const FollowingPage(),
        ),

        GoRoute(
          path: '/upload/video',
          builder: (context, state) => const VideoUploadPage(),
        ),
        GoRoute(
          path: '/become-creator',
          builder: (context, state) => const BecomeCreatorPage(),
        ),
        GoRoute(
          path: '/users/:username',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return UserProfilePage(username: username);
          },
        ),
        GoRoute(
          path: '/video/:videoId',
          builder: (context, state) {
            final videoId = state.pathParameters['videoId'] ?? '';
            // Try to get video from extra first, then from cache
            var video = state.extra as VideoModel?;
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
            );
          },
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) {
            final query = state.uri.queryParameters['q'] ?? '';
            return SearchResultsPage(query: query);
          },
        ),
      ],
      redirect: (context, state) async {
        final authViewModel = _readAuthViewModel(context);
        final isPostSignUpPending =
            authViewModel?.isPostSignUpRedirectPending ?? false;

        if (isPostSignUpPending) {
          return state.uri.path == '/login' ? null : '/login';
        }

        // Wait a tiny bit to ensure auth state is updated
        await Future.delayed(const Duration(milliseconds: 100));

        final isLoggedIn = _authRepository.currentUser != null;
        final loggingIn = state.uri.path == '/login';
        final signingUp = state.uri.path == '/signup';
        final uploading =
            state.uri.path == '/upload' || state.uri.path == '/upload/video';
        final onProfile = state.uri.path.startsWith('/users/');
        final onHome = state.uri.path == '/home';
        final onFollowing = state.uri.path == '/following';
        final onVideo = state.uri.path.startsWith('/video/');
        final onSearch = state.uri.path == '/search';

        if (!isLoggedIn) {
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
              onSearch) {
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
