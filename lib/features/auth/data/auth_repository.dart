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

  /// Signs up a new user. Returns a registration ID that must be verified with OTP.
  Future<String> signUp({
    required String name,
    required String email,
    required String username,
    required String password,
  });

  /// Verifies the OTP sent during registration.
  Future<void> verifyOtp({required String id, required String otp});

  /// Requests a password reset for the given email.
  Future<String> requestPasswordReset({required String email});

  /// Verifies the OTP and sets a new password.
  Future<void> verifyPasswordReset({
    required String id,
    required String otp,
    required String newPassword,
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
  bool _authEstablishedDuringInit = false;

  @override
  Stream<AuthUser?> authStateChanges() => _authStateController.stream;

  @override
  AuthUser? get currentUser => _currentUser;

  Future<void> _initializeAuthState() async {
    // Snapshot the user state to avoid clobbering a successful sign-in that
    // may finish while this async initialization is still in flight.
    final userAtStart = _currentUser;

    // Check if token exists and is valid by trying to get current user
    final token = await TokenStorageService.getToken();

    if (_authEstablishedDuringInit || userAtStart != _currentUser) {
      // A login/logout already happened while we were reading storage.
      return;
    }

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
      throw const AuthFailure('Username/email and password are required.');
    }

    final identifier = username.trim().toLowerCase();
    final isEmail = identifier.contains('@');

    try {
      final body = <String, String>{'password': password};

      if (isEmail) {
        body['email'] = identifier;
      } else {
        body['username'] = identifier;
      }

      final response = await _apiClient.post(
        ApiConstants.authLogin,
        body,
        requiresAuth: false,
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;

        if (responseBody['success'] == true) {
          final data = responseBody['data'] as Map<String, dynamic>?;
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
              profilePicture:
                  userData['profile_picture'] as String? ??
                  userData['profilePicture'] as String? ??
                  userData['avatarUrl'] as String?,
            );
          } else {
            _currentUser = AuthUser(uid: '');
          }

          // Emit auth state change
          _authEstablishedDuringInit = true;
          _authStateController.add(_currentUser);
        } else {
          final message = responseBody['message'] as String? ?? 'Login failed.';
          throw AuthFailure(message);
        }
      } else if (response.statusCode == 401) {
        throw const AuthFailure('Invalid credentials.');
      } else {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>?;
        final message =
            responseBody?['message'] as String? ??
            'Login failed. Please try again.';
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
  Future<String> signUp({
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

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final id = data?['id'] as String?;

          if (id == null || id.isEmpty) {
            throw const AuthFailure('Failed to receive registration ID.');
          }

          return id;
        } else {
          final message = body['error'] as String? ?? 'Registration failed.';
          throw AuthFailure(message);
        }
      } else if (response.statusCode == 409) {
        throw const AuthFailure('Username already in use.');
      } else {
        final message =
            body['error'] as String? ??
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
  Future<void> verifyOtp({required String id, required String otp}) async {
    if (id.isEmpty || otp.isEmpty) {
      throw const AuthFailure('Registration ID and OTP are required.');
    }

    try {
      final response = await _apiClient.post(ApiConstants.authVerify, {
        'id': id,
        'otp': otp,
      }, requiresAuth: false);

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
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
              profilePicture:
                  userData['profile_picture'] as String? ??
                  userData['profilePicture'] as String? ??
                  userData['avatarUrl'] as String?,
            );
          } else {
            _currentUser = AuthUser(uid: '');
          }

          // Emit auth state change
          _authEstablishedDuringInit = true;
          _authStateController.add(_currentUser);
        } else {
          final message = body['error'] as String? ?? 'Verification failed.';
          throw AuthFailure(message);
        }
      } else {
        final message =
            body['error'] as String? ??
            'Verification failed. Please try again.';
        throw AuthFailure(message);
      }
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw AuthFailure('Failed to verify OTP: $error');
    }
  }

  @override
  Future<String> requestPasswordReset({required String email}) async {
    if (email.isEmpty) {
      throw const AuthFailure('Email is required.');
    }

    try {
      final response = await _apiClient.post(
        ApiConstants.authResetPasswordRequest,
        {'email': email.trim().toLowerCase()},
        requiresAuth: false,
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final id = data?['id'] as String?;

          if (id == null || id.isEmpty) {
            throw const AuthFailure('Failed to receive reset ID.');
          }

          return id;
        } else {
          final message = body['error'] as String? ?? 'Request failed.';
          throw AuthFailure(message);
        }
      } else {
        final message =
            body['error'] as String? ?? 'Request failed. Please try again.';
        throw AuthFailure(message);
      }
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw AuthFailure('Failed to request password reset: $error');
    }
  }

  @override
  Future<void> verifyPasswordReset({
    required String id,
    required String otp,
    required String newPassword,
  }) async {
    if (id.isEmpty || otp.isEmpty || newPassword.isEmpty) {
      throw const AuthFailure('All fields are required.');
    }

    try {
      final response = await _apiClient.post(
        ApiConstants.authResetPasswordVerify,
        {'id': id, 'otp': otp, 'new_password': newPassword},
        requiresAuth: false,
      );

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        if (body['success'] == true) {
          // Password reset successful
          return;
        } else {
          final message = body['error'] as String? ?? 'Reset failed.';
          throw AuthFailure(message);
        }
      } else {
        final message =
            body['error'] as String? ?? 'Reset failed. Please try again.';
        throw AuthFailure(message);
      }
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      throw AuthFailure('Failed to reset password: $error');
    }
  }

  @override
  Future<void> signOut() async {
    // Delete token
    await TokenStorageService.deleteToken();

    // Clear current user
    _currentUser = null;
    _authEstablishedDuringInit = true;

    // Emit auth state change
    _authStateController.add(null);
  }

  void dispose() {
    _authStateController.close();
  }
}
