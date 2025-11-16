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

  final identifierController = TextEditingController();
  final signInPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
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
          email: identifierController.text.trim(),
          password: signInPasswordController.text,
        );

        // After sign-in, fetch user profile to get username
        // Wait a bit to ensure Firebase token is ready
        print('   ⏳ Waiting for Firebase token to be ready after sign-in...');
        await Future.delayed(const Duration(milliseconds: 500));

        // Reload user to ensure token is fresh
        final currentUser = _authRepository.currentUser;
        if (currentUser != null) {
          print('   🔄 Reloading Firebase user to refresh token...');
          await currentUser.reload();
          await Future.delayed(const Duration(milliseconds: 300));

          // Try to fetch user profile to get username using bearer token
          print('   🔍 Attempting to fetch user profile after sign-in...');
          print('   🔑 Using Firebase ID token as Bearer token');
          try {
            // Fetch current user profile from backend using the Firebase token
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

        _clearSignInForm();
      } else {
        _postSignUpRedirectPending = true;
        notifyListeners();

        final name = nameController.text.trim();
        final username = usernameController.text.trim();
        final email = emailController.text.trim();
        final password = signUpPasswordController.text;

        // Step 1: Create Firebase auth account
        developer.log(
          'Step 1: Creating Firebase auth account',
          name: 'hiffi.auth',
        );
        await _authRepository.signUp(
          name: name,
          username: username,
          email: email,
          password: password,
        );

        // Wait a bit to ensure Firebase token is ready and backend recognizes the user
        // Firebase tokens can take a moment to propagate
        print('   ⏳ Waiting for Firebase token to be ready...');
        await Future.delayed(const Duration(seconds: 1));

        // Verify we have a current user before proceeding
        final currentUser = _authRepository.currentUser;
        if (currentUser == null) {
          throw AuthFailure('Failed to create account. Please try again.');
        }

        // Reload user to ensure token is fresh
        print('   🔄 Reloading Firebase user to refresh token...');
        await currentUser.reload();
        await Future.delayed(const Duration(milliseconds: 300));

        // Step 2: Create user in backend API
        developer.log(
          'Step 2: Creating user in backend API',
          name: 'hiffi.auth',
        );
        print(
          '   👤 Current Firebase user: ${_authRepository.currentUser?.email}',
        );
        print('   👤 User ID: ${_authRepository.currentUser?.uid}');

        try {
          await _userRepository.createUser(username: username, name: name);
          developer.log(
            'User created successfully in backend',
            name: 'hiffi.auth',
          );
          // Store username after successful creation
          _currentUsername = username;
          notifyListeners();
        } catch (error) {
          developer.log(
            'Failed to create user in backend, cleaning up Firebase account',
            name: 'hiffi.auth',
            error: error,
          );
          print('   ❌ Backend API error: $error');

          // If backend creation fails, delete Firebase account
          // IMPORTANT: Delete user BEFORE signing out, otherwise currentUser becomes null
          try {
            final currentUser = _authRepository.currentUser;
            if (currentUser != null) {
              print('   🗑️ Deleting Firebase user account...');
              await currentUser.delete();
              print('   ✅ Firebase account deleted');
            }
          } catch (deleteError) {
            developer.log(
              'Error deleting Firebase user: $deleteError',
              name: 'hiffi.auth',
              error: deleteError,
            );
            print('   ⚠️ Error deleting Firebase account: $deleteError');
            // Try to sign out as fallback
            try {
              await _authRepository.signOut();
            } catch (signOutError) {
              developer.log(
                'Error signing out: $signOutError',
                name: 'hiffi.auth',
                error: signOutError,
              );
            }
          }

          final errorMessage = error.toString().contains('401')
              ? 'Authentication failed. Please try signing up again.'
              : 'Failed to create user profile. Please try again.';
          throw AuthFailure(errorMessage);
        }

        _clearSignUpForm();
        await _authRepository.signOut();
        _postSignUpRedirectPending = false;
        _mode = AuthMode.signIn;
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
    identifierController.clear();
    signInPasswordController.clear();
  }

  void _clearSignUpForm() {
    nameController.clear();
    usernameController.clear();
    emailController.clear();
    signUpPasswordController.clear();
  }

  @override
  void dispose() {
    identifierController.dispose();
    signInPasswordController.dispose();
    nameController.dispose();
    usernameController.dispose();
    emailController.dispose();
    signUpPasswordController.dispose();
    super.dispose();
  }
}
