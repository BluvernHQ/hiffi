import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../../../../core/exceptions/auth_failure.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../data/auth_repository.dart';
import '../../../user/data/user_repository.dart';

enum AuthMode { signIn, signUp, verifyOtp, forgotPassword, resetPassword }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    NetworkConnectivityService? connectivityService,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _connectivityService = connectivityService;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final NetworkConnectivityService? _connectivityService;

  final usernameController = TextEditingController();
  final signInPasswordController = TextEditingController();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final signUpUsernameController = TextEditingController();
  final signUpPasswordController = TextEditingController();
  final otpController = TextEditingController();
  final resetPasswordController = TextEditingController();
  final confirmResetPasswordController = TextEditingController();

  AuthMode _mode = AuthMode.signIn;
  bool _isLoading = false;
  String? _errorMessage;
  bool _postSignUpRedirectPending = false;
  String? _currentUsername;
  String? _registrationId;
  String? _resetId;
  int _resendTimer = 0;
  Timer? _countdownTimer;

  AuthMode get mode => _mode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isPostSignUpRedirectPending => _postSignUpRedirectPending;
  String? get currentUsername => _currentUsername;
  String? get registrationId => _registrationId;
  String? get resetId => _resetId;
  int get resendTimer => _resendTimer;
  bool get canResendOtp => _resendTimer == 0;

  void _startResendTimer() {
    _resendTimer = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        _resendTimer--;
        notifyListeners();
      } else {
        _countdownTimer?.cancel();
      }
    });
    notifyListeners();
  }

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

  void reset() {
    usernameController.clear();
    signInPasswordController.clear();
    nameController.clear();
    emailController.clear();
    signUpUsernameController.clear();
    signUpPasswordController.clear();
    otpController.clear();
    resetPasswordController.clear();
    confirmResetPasswordController.clear();
    _errorMessage = null;
    _currentUsername = null;
    _registrationId = null;
    _resetId = null;
    _resendTimer = 0;
    _countdownTimer?.cancel();
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
          username: usernameController.text.trim().toLowerCase(),
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
      } else if (_mode == AuthMode.signUp) {
        final name = nameController.text.trim();
        final email = emailController.text.trim();
        final username = signUpUsernameController.text.trim();
        final password = signUpPasswordController.text;

        developer.log(
          'Creating user account via backend API',
          name: 'hiffi.auth',
        );

        // Register user via backend API (this creates the user and returns a registration ID)
        final regId = await _authRepository.signUp(
          name: name,
          email: email,
          username: username,
          password: password,
        );

        developer.log(
          'Registration initiated successfully. ID: $regId',
          name: 'hiffi.auth',
        );

        _registrationId = regId;
        _mode = AuthMode.verifyOtp;
        _startResendTimer();

        notifyListeners();
      } else if (_mode == AuthMode.verifyOtp) {
        if (_registrationId == null) {
          throw const AuthFailure(
            'Registration ID missing. Please try signing up again.',
          );
        }

        final otp = otpController.text.trim();

        developer.log(
          'Verifying OTP for ID: $_registrationId',
          name: 'hiffi.auth',
        );

        await _authRepository.verifyOtp(id: _registrationId!, otp: otp);

        developer.log('OTP verified successfully', name: 'hiffi.auth');

        // Update username from auth user
        final currentUser = _authRepository.currentUser;
        if (currentUser?.username != null) {
          _currentUsername = currentUser!.username;
        }

        notifyListeners();

        // Clear forms
        _clearSignUpForm();
        _clearOtpForm();
      } else if (_mode == AuthMode.forgotPassword) {
        final email = emailController.text.trim();

        developer.log(
          'Requesting password reset for: $email',
          name: 'hiffi.auth',
        );

        final id = await _authRepository.requestPasswordReset(email: email);

        developer.log(
          'Password reset request successful. ID: $id',
          name: 'hiffi.auth',
        );

        _resetId = id;
        _mode = AuthMode.resetPassword;
        _startResendTimer();

        notifyListeners();
      } else if (_mode == AuthMode.resetPassword) {
        if (_resetId == null) {
          throw const AuthFailure('Reset ID missing. Please try again.');
        }

        final otp = otpController.text.trim();
        final newPassword = resetPasswordController.text;

        developer.log(
          'Verifying password reset for ID: $_resetId',
          name: 'hiffi.auth',
        );

        await _authRepository.verifyPasswordReset(
          id: _resetId!,
          otp: otp,
          newPassword: newPassword,
        );

        developer.log('Password reset successfully', name: 'hiffi.auth');

        _mode = AuthMode.signIn;
        _errorMessage =
            'Password reset successfully. Please sign in with your new password.';

        _clearResetForm();
        _clearOtpForm();
        notifyListeners();
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

  Future<void> resendOtp() async {
    if (!canResendOtp || _isLoading) return;

    _setLoading(true);
    _setError(null);

    try {
      if (_mode == AuthMode.verifyOtp) {
        final name = nameController.text.trim();
        final email = emailController.text.trim();
        final username = signUpUsernameController.text.trim();
        final password = signUpPasswordController.text;

        developer.log('Resending registration OTP', name: 'hiffi.auth');

        final regId = await _authRepository.signUp(
          name: name,
          email: email,
          username: username,
          password: password,
        );

        _registrationId = regId;
      } else if (_mode == AuthMode.resetPassword) {
        final email = emailController.text.trim();

        developer.log('Resending password reset OTP', name: 'hiffi.auth');

        final id = await _authRepository.requestPasswordReset(email: email);
        _resetId = id;
      }

      _startResendTimer();
      developer.log('OTP resent successfully', name: 'hiffi.auth');
    } on AuthFailure catch (error) {
      _setError(error.message);
    } catch (error) {
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
    emailController.clear();
    signUpUsernameController.clear();
    signUpPasswordController.clear();
  }

  void _clearOtpForm() {
    otpController.clear();
  }

  void _clearResetForm() {
    emailController.clear();
    resetPasswordController.clear();
    confirmResetPasswordController.clear();
  }

  /// Fetch user profile asynchronously (non-blocking for navigation)
  void _fetchUserProfileAsync() {
    Future.microtask(() async {
      try {
        // Check for internet connectivity before making the call
        if (_connectivityService != null && !_connectivityService.isConnected) {
          print('   🚫 Skipping async profile fetch: No internet connection');
          return;
        }

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
    _countdownTimer?.cancel();
    usernameController.dispose();
    signInPasswordController.dispose();
    nameController.dispose();
    emailController.dispose();
    signUpUsernameController.dispose();
    signUpPasswordController.dispose();
    super.dispose();
  }
}
