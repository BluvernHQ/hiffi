import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../../../../core/exceptions/auth_failure.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/services/referral_storage_service.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/analytics/first_party_analytics_service.dart';
import '../../data/auth_repository.dart';
import '../../../user/data/user_repository.dart';

enum AuthMode { signIn, signUp, forgotPassword, resetPassword }

class AuthViewModel extends ChangeNotifier {
  AuthViewModel({
    required AuthRepository authRepository,
    required UserRepository userRepository,
    NetworkConnectivityService? connectivityService,
    FirstPartyAnalyticsService? firstPartyAnalytics,
  }) : _authRepository = authRepository,
       _userRepository = userRepository,
       _connectivityService = connectivityService,
       _firstPartyAnalytics = firstPartyAnalytics;

  final AuthRepository _authRepository;
  final UserRepository _userRepository;
  final NetworkConnectivityService? _connectivityService;
  final FirstPartyAnalyticsService? _firstPartyAnalytics;

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
  String? _currentUsername;
  String? _resetId;
  String? _pendingPostAuthRoute;
  int _resendTimer = 0;
  Timer? _countdownTimer;

  AuthMode get mode => _mode;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get currentUsername => _currentUsername;
  String? get resetId => _resetId;
  int get resendTimer => _resendTimer;
  bool get canResendOtp => _resendTimer == 0;

  /// One-shot destination after sign-in/sign-up (e.g. referral profile).
  String? consumePostAuthRoute() {
    final route = _pendingPostAuthRoute;
    _pendingPostAuthRoute = null;
    return route;
  }

  String _normalizeEmail(String value) => value.trim().toLowerCase();

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
    _resetId = null;
    _pendingPostAuthRoute = null;
    _resendTimer = 0;
    _countdownTimer?.cancel();
    notifyListeners();
  }

  Future<void> submit({GlobalKey<FormState>? formKey}) async {
    if (_isLoading) {
      return;
    }

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

        _clearSignInForm();

        final currentUser = _authRepository.currentUser;
        if (currentUser?.username != null) {
          _currentUsername = currentUser!.username;
        }
        await _firstPartyAnalytics?.identify(currentUser?.uid);

        notifyListeners();
        _fetchUserProfileAsync();
      } else if (_mode == AuthMode.signUp) {
        final name = nameController.text.trim();
        final email = _normalizeEmail(emailController.text);
        final username = signUpUsernameController.text.trim();
        final password = signUpPasswordController.text;
        final referralCode = await ReferralStorageService.getReferralCode();
        final redirectToReferrer = referralCode != null &&
            referralCode.isNotEmpty &&
            await ReferralStorageService.isRedirectPending();

        developer.log(
          'Creating user account via backend API',
          name: 'hiffi.auth',
        );

        await _authRepository.signUp(
          name: name,
          email: email,
          username: username,
          password: password,
          referralCode: referralCode,
        );

        if (redirectToReferrer) {
          _pendingPostAuthRoute = '/users/$referralCode';
        }

        await ReferralStorageService.clearReferral();

        developer.log('Registration completed successfully', name: 'hiffi.auth');

        final currentUser = _authRepository.currentUser;
        if (currentUser?.username != null) {
          _currentUsername = currentUser!.username;
        }
        await _firstPartyAnalytics?.identify(currentUser?.uid);
        await _firstPartyAnalytics?.capture(
          'conversion_signup_completed',
          properties: {'source': 'signup', 'source_path': '/signup'},
        );

        _clearSignUpForm();
        notifyListeners();
        _fetchUserProfileAsync();
      } else if (_mode == AuthMode.forgotPassword) {
        final email = _normalizeEmail(emailController.text);

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
      _setError(error.message);
    } catch (error) {
      _setError(userFriendlyErrorMessage(error));
    } finally {
      _setLoading(false);
    }
  }

  Future<void> resendOtp() async {
    if (!canResendOtp || _isLoading) return;

    _setLoading(true);
    _setError(null);

    try {
      if (_mode == AuthMode.resetPassword) {
        final email = _normalizeEmail(emailController.text);

        developer.log('Resending password reset OTP', name: 'hiffi.auth');

        final id = await _authRepository.requestPasswordReset(email: email);
        _resetId = id;
      }

      _startResendTimer();
      developer.log('OTP resent successfully', name: 'hiffi.auth');
    } on AuthFailure catch (error) {
      _setError(error.message);
    } catch (error) {
      _setError(userFriendlyErrorMessage(error));
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

  void _fetchUserProfileAsync() {
    Future.microtask(() async {
      try {
        final connectivity = _connectivityService;
        if (connectivity != null) {
          await connectivity.ensureInitialized();
          if (!connectivity.isConnected) {
            print('   🚫 Skipping async profile fetch: No internet connection');
            return;
          }
        }

        await Future.delayed(const Duration(milliseconds: 300));

        final currentUser = _authRepository.currentUser;
        if (currentUser != null) {
          print('   🔍 Attempting to fetch user profile after sign-in...');
          try {
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
    otpController.dispose();
    resetPasswordController.dispose();
    confirmResetPasswordController.dispose();
    super.dispose();
  }
}
