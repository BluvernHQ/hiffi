import 'dart:developer' as developer;

import 'package:go_router/go_router.dart';

import '../constants/api_constants.dart';
import '../routes/app_router.dart';
import '../../features/auth/data/auth_repository.dart';

/// Central handler for expired sessions (401 on protected API routes).
class SessionExpiryHandler {
  SessionExpiryHandler({
    required AuthRepository authRepository,
    required AppRouter appRouter,
  }) : _authRepository = authRepository,
       _appRouter = appRouter;

  final AuthRepository _authRepository;
  final AppRouter _appRouter;
  bool _isHandling = false;
  DateTime? _lastHandledAt;

  static const _authEndpoints = <String>{
    ApiConstants.authRegister,
    ApiConstants.authLogin,
    ApiConstants.authResetPasswordRequest,
    ApiConstants.authResetPasswordVerify,
    ApiConstants.userAvailability,
  };

  bool isAuthEndpoint(String endpoint) {
    final path = endpoint.split('?').first;
    return _authEndpoints.any(
      (authPath) => path == authPath || path.startsWith('$authPath/'),
    );
  }

  Future<void> handleIfNeeded({
    required int statusCode,
    required bool requiresAuth,
    required String endpoint,
  }) async {
    if (statusCode != 401 || !requiresAuth) return;
    if (isAuthEndpoint(endpoint)) return;
    if (_authRepository.currentUser == null) return;

    final now = DateTime.now();
    final last = _lastHandledAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      return;
    }

    if (_isHandling) return;
    _isHandling = true;
    _lastHandledAt = now;

    try {
      developer.log(
        'Session expired — signing out (endpoint: $endpoint)',
        name: 'hiffi.session',
      );
      await _authRepository.signOut();
      _redirectToLogin();
    } finally {
      _isHandling = false;
    }
  }

  void _redirectToLogin() {
    final context = _appRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/login') || location.startsWith('/signup')) {
      return;
    }

    final returnTo = Uri.encodeComponent(location);
    context.go('/login?returnTo=$returnTo');
  }
}
