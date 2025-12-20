import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/auth_page.dart';
import '../../features/home/presentation/views/home_page.dart';

import '../../features/upload/presentation/views/video_upload_page.dart';
import '../../features/user/presentation/views/become_creator_page.dart';
import '../../features/user/presentation/views/user_profile_page.dart';
import '../../features/video/domain/models/video_model.dart';
import '../../features/video/presentation/views/video_player_page.dart';

class AppRouter {
  AppRouter({required AuthRepository authRepository})
    : _authRepository = authRepository,
      _navigatorKey = GlobalKey<NavigatorState>() {
    _refreshListenable = RouterRefreshStream(
      _authRepository.authStateChanges(),
    );

    router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/login',
      refreshListenable: _refreshListenable,
      debugLogDiagnostics: true,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const AuthPage(initialMode: AuthMode.signIn),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) =>
              const AuthPage(initialMode: AuthMode.signUp),
        ),
        GoRoute(path: '/home', builder: (context, state) => const HomePage()),

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
            final video = state.extra as VideoModel?;
            if (video == null) {
              // Redirect to home if video not found
              return const HomePage();
            }
            return VideoPlayerPage(video: video);
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
        final onVideo = state.uri.path.startsWith('/video/');

        if (!isLoggedIn) {
          // Allow access to home, video player, upload pages, and auth pages without authentication
          // Profile pages require authentication - redirect to login
          if (onProfile) {
            return '/login';
          }
          return (loggingIn || signingUp || uploading || onHome || onVideo)
              ? null
              : '/login';
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
