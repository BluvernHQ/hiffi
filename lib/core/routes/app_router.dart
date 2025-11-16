import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/auth_page.dart';
import '../../features/home/presentation/views/home_page.dart';

import '../../features/upload/presentation/views/video_upload_page.dart';
import '../../features/user/presentation/views/user_profile_page.dart';

class AppRouter {
  AppRouter({required AuthRepository authRepository})
    : _authRepository = authRepository {
    _refreshListenable = RouterRefreshStream(
      _authRepository.authStateChanges(),
    );

    router = GoRouter(
      initialLocation: '/login',
      refreshListenable: _refreshListenable,
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
          path: '/users/:username',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return UserProfilePage(username: username);
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

        final isLoggedIn = _authRepository.currentUser != null;
        final loggingIn = state.uri.path == '/login';
        final signingUp = state.uri.path == '/signup';
        final uploading =
            state.uri.path == '/upload' || state.uri.path == '/upload/video';
        final onProfile = state.uri.path.startsWith('/users/');

        if (!isLoggedIn) {
          // Allow access to upload pages for testing without authentication
          return (loggingIn || signingUp || uploading) ? null : '/login';
        }

        // If already on profile page, don't redirect
        if (onProfile) {
          return null;
        }

        if (loggingIn || signingUp) {
          // Redirect to home page - it will show profile if username is available
          return '/home';
        }

        return null;
      },
    );
  }

  late final GoRouter router;
  late final RouterRefreshStream _refreshListenable;
  final AuthRepository _authRepository;

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
    _subscription = stream.listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
