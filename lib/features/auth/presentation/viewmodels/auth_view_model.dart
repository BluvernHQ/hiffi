import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../../../../core/exceptions/auth_failure.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../user/data/user_repository.dart';

enum AuthMode { signIn, signUp }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required UserRepository userRepository,
  }) : _authRepository = authRepository,
       _userRepository = userRepository;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;

  final usernameController = TextEditingController();
  final signInPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final signUpUsernameController = TextEditingController();
  final signUpPasswordController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _isLoading = false;
  String? _errorMessage;
  bool _postSignUpRedirectPending = false;
  String? _currentUsername;

  AuthMode get mode => _mode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPostSignUpRedirectPending => _postSignUpRedirectPending;
  String? get currentUsername => _currentUsername;

  void setCurrentUsername(String? username) {
    _currentUsername = username;
    notifyListeners();
  }

  void setMode(AuthMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> submit({GlobalKey<FormState>? formKey}) async {
    if (_isLoading) {
      return;
    }

    // Validate form if key is provided
    if (formKey != null && !(formKey.currentState?.validate() ?? false)) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      if (_mode == AuthMode.signIn) {
        await _authRepository.signIn(
          username: usernameController.text.trim(),
          password: signInPasswordController.text,
        );

        // Clear form immediately to allow UI to update
        _clearSignInForm();

        // Update username from auth user
        final currentUser = _authRepository.currentUser;
        if (currentUser?.username != null) {
          _currentUsername = currentUser!.username;
        }

        // Notify listeners to trigger router refresh
        notifyListeners();

        // Fetch user profile asynchronously (non-blocking for navigation)
        // The router will handle navigation based on auth state changes
        _fetchUserProfileAsync();
      } else {
        final name = nameController.text.trim();
        final username = signUpUsernameController.text.trim();
        final password = signUpPasswordController.text;

        developer.log(
          'Creating user account via backend API',
          name: 'hiffi.auth',
        );

        // Register user via backend API (this creates the user and returns a token)
        await _authRepository.signUp(
          name: name,
          username: username,
          password: password,
        );

        developer.log('User created successfully', name: 'hiffi.auth');

        // Update username from auth user
        final currentUser = _authRepository.currentUser;
        if (currentUser?.username != null) {
          _currentUsername = currentUser!.username;
        } else {
          _currentUsername = username;
        }

        notifyListeners();

        // Clear form
        _clearSignUpForm();

        // User is now logged in automatically after registration
        // Router will handle navigation based on auth state changes
      }
    } on AuthFailure catch (error) {
      _postSignUpRedirectPending = false;
      _setError(error.message);
    } catch (error) {
      _postSignUpRedirectPending = false;
      _setError('Unexpected error: $error');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  void _clearSignInForm() {
    usernameController.clear();
    signInPasswordController.clear();
  }

  void _clearSignUpForm() {
    nameController.clear();
    signUpUsernameController.clear();
    signUpPasswordController.clear();
  }

  /// Fetch user profile asynchronously (non-blocking for navigation)
  void _fetchUserProfileAsync() {
    Future.microtask(() async {
      try {
        // Wait a bit to ensure token is ready
        await Future.delayed(const Duration(milliseconds: 300));

        final currentUser = _authRepository.currentUser;
        if (currentUser != null) {
          // Try to fetch user profile to get full user info using JWT token
          print('   🔍 Attempting to fetch user profile after sign-in...');
          try {
            // Fetch current user profile from backend using the JWT token
            final userProfile = await _userRepository.getCurrentUser();
            if (userProfile.username.isNotEmpty) {
              _currentUsername = userProfile.username;
              notifyListeners();
              print('   ✅ Username retrieved: ${userProfile.username}');
              developer.log(
                'Username retrieved after sign-in: ${userProfile.username}',
                name: 'hiffi.auth',
              );
            } else {
              print('   ⚠️ User profile retrieved but username is empty');
            }
          } catch (error) {
            developer.log(
              'Failed to fetch user profile after sign-in: $error',
              name: 'hiffi.auth',
              error: error,
            );
            print('   ⚠️ Could not fetch user profile: $error');
          }
        }
      } catch (e) {
        print('   ⚠️ Error in async profile fetch: $e');
      }
    });
  }

  @override
  void dispose() {
    usernameController.dispose();
    signInPasswordController.dispose();
    nameController.dispose();
    signUpUsernameController.dispose();
    signUpPasswordController.dispose();
    super.dispose();
  }
}
