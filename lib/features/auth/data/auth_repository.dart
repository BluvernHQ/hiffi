import 'dart:async';
import 'dart:convert';

import '../../../core/exceptions/auth_failure.dart';
import '../../../core/services/token_storage_service.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import 'auth_user.dart';

abstract class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  AuthUser? get currentUser;
  Future<void> signIn({required String username, required String password});

  Future<void> signUp({
    required String name,
    required String email,
    required String username,
    required String password,
  });

  Future<void> signOut();
}

class BackendAuthRepository implements AuthRepository {
  BackendAuthRepository({required ApiClient apiClient})
    : _apiClient = apiClient {
    // Check if user is already logged in on initialization
    _initializeAuthState();
  }

  final ApiClient _apiClient;
  final StreamController<AuthUser?> _authStateController =
      StreamController<AuthUser?>.broadcast();
  AuthUser? _currentUser;

  @override
  Stream<AuthUser?> authStateChanges() => _authStateController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  Future<void> _initializeAuthState() async {
    // Check if token exists and is valid by trying to get current user
    final token = await TokenStorageService.getToken();
    if (token != null && token.isNotEmpty) {
      // Token exists, but we don't validate it here
      // The app will validate it when making API calls
      // For now, we'll consider user as logged in if token exists
      // In a real implementation, you might want to decode the JWT to get user info
      // or make a lightweight API call to validate the token
      _currentUser = AuthUser(
        uid: '',
      ); // Placeholder, will be updated on first API call
      _authStateController.add(_currentUser);
    } else {
      _currentUser = null;
      _authStateController.add(null);
    }
  }

  @override
  Future<void> signIn({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      throw const AuthFailure('Username and password are required.');
    }

    final trimmedUsername = username.trim().toLowerCase();

    try {
      final response = await _apiClient.post(ApiConstants.authLogin, {
        'username': trimmedUsername,
        'password': password,
      }, requiresAuth: false);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final token = data?['token'] as String?;
          final userData = data?['user'] as Map<String, dynamic>?;

          if (token == null || token.isEmpty) {
            throw const AuthFailure('Failed to receive authentication token.');
          }

          // Save token
          await TokenStorageService.saveToken(token);

          // Create auth user from response
          if (userData != null) {
            _currentUser = AuthUser(
              uid: userData['uid'] as String? ?? '',
              username: userData['username'] as String?,
              name: userData['name'] as String?,
              profilePicture: userData['profile_picture'] as String?,
            );
          } else {
            _currentUser = AuthUser(uid: '');
          }

          // Emit auth state change
          _authStateController.add(_currentUser);
        } else {
          final message = body['message'] as String? ?? 'Login failed.';
          throw AuthFailure(message);
        }
      } else if (response.statusCode == 401) {
        throw const AuthFailure('Invalid username or password.');
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            body?['message'] as String? ?? 'Login failed. Please try again.';
        throw AuthFailure(message);
      }
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw AuthFailure('Failed to sign in: $error');
    }
  }

  @override
  Future<void> signUp({
    required String name,
    required String email,
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || name.isEmpty || email.isEmpty || password.isEmpty) {
      throw const AuthFailure('All fields are required.');
    }

    final trimmedUsername = username.trim().toLowerCase();
    final trimmedName = name.trim();
    final trimmedEmail = email.trim().toLowerCase();

    // Validate email format
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(trimmedEmail)) {
      throw const AuthFailure('Please enter a valid email address.');
    }

    // Validate username format
    if (!RegExp(r'^[a-z0-9_]{3,30}$').hasMatch(trimmedUsername)) {
      throw const AuthFailure(
        'Username must be between 3 and 30 characters and contain only lowercase letters, numbers, and underscores.',
      );
    }

    // Validate name length
    if (trimmedName.length >= 30) {
      throw const AuthFailure('Name must be less than 30 characters.');
    }

    // Validate password length
    if (password.length < 6) {
      throw const AuthFailure('Password must be at least 6 characters.');
    }

    try {
      final response = await _apiClient.post(ApiConstants.authRegister, {
        'username': trimmedUsername,
        'name': trimmedName,
        'email': trimmedEmail,
        'password': password,
      }, requiresAuth: false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final token = data?['token'] as String?;
          final userData = data?['user'] as Map<String, dynamic>?;

          if (token == null || token.isEmpty) {
            throw const AuthFailure('Failed to receive authentication token.');
          }

          // Save token
          await TokenStorageService.saveToken(token);

          // Create auth user from response
          if (userData != null) {
            _currentUser = AuthUser(
              uid: userData['uid'] as String? ?? '',
              username: userData['username'] as String?,
              name: userData['name'] as String?,
              profilePicture: userData['profile_picture'] as String?,
            );
          } else {
            _currentUser = AuthUser(uid: '');
          }

          // Emit auth state change
          _authStateController.add(_currentUser);
        } else {
          final message = body['message'] as String? ?? 'Registration failed.';
          throw AuthFailure(message);
        }
      } else if (response.statusCode == 409) {
        throw const AuthFailure('Username already in use.');
      } else {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            body?['message'] as String? ??
            'Registration failed. Please try again.';
        throw AuthFailure(message);
      }
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw AuthFailure('Failed to register: $error');
    }
  }

  @override
  Future<void> signOut() async {
    // Delete token
    await TokenStorageService.deleteToken();

    // Clear current user
    _currentUser = null;

    // Emit auth state change
    _authStateController.add(null);
  }

  void dispose() {
    _authStateController.close();
  }
}
