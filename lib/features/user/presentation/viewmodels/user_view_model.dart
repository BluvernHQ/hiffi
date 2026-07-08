import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';

class UserViewModel extends ChangeNotifier {
  UserViewModel({
    required UserRepository userRepository,
    NetworkConnectivityService? connectivityService,
  }) : _userRepository = userRepository,
       _connectivityService = connectivityService;

  final UserRepository _userRepository;
  final NetworkConnectivityService? _connectivityService;

  UserModel?
  _currentUser; // The logged-in user (should never be overwritten by loadUser)
  UserModel? _viewedUser; // The user being viewed in profile pages
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  bool _isFollowActionLoading = false;
  String? _errorMessage;
  String? _usernameAvailabilityMessage;
  bool? _isUsernameAvailable;
  bool _hasUnauthorizedError =
      false; // Track if we got a 401 to prevent retry loops

  UserModel? get currentUser => _currentUser;
  UserModel? get viewedUser => _viewedUser;

  /// Clear the current user (useful when logging out)
  void clearCurrentUser() {
    developer.log(
      'clearCurrentUser() called - clearing both _currentUser and _viewedUser',
      name: 'hiffi.user',
    );
    _currentUser = null;
    _viewedUser = null;
    _errorMessage = null;
    _hasUnauthorizedError = false;
    notifyListeners();
  }

  /// Clear the viewed user (useful when navigating away from profile pages)
  void clearViewedUser() {
    developer.log(
      'clearViewedUser() called - clearing _viewedUser',
      name: 'hiffi.user',
    );
    _viewedUser = null;
    notifyListeners();
  }

  bool get isLoading => _isLoading;
  bool get isCheckingAvailability => _isCheckingAvailability;
  bool get isFollowActionLoading => _isFollowActionLoading;
  String? get errorMessage => _errorMessage;
  String? get usernameAvailabilityMessage => _usernameAvailabilityMessage;
  bool? get isUsernameAvailable => _isUsernameAvailable;
  bool get hasUnauthorizedError => _hasUnauthorizedError;

  // OTP state (isolated, not global)
  bool _isSendingOTP = false;
  bool _isVerifyingOTP = false;
  String? _otpError;

  bool get isSendingOTP => _isSendingOTP;
  bool get isVerifyingOTP => _isVerifyingOTP;
  String? get otpError => _otpError;

  Future<bool> checkUsernameAvailability(String username) async {
    if (username.trim().isEmpty) {
      _usernameAvailabilityMessage = null;
      _isUsernameAvailable = null;
      notifyListeners();
      return false;
    }

    _isCheckingAvailability = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final available = await _userRepository.checkUsernameAvailability(
        username.trim(),
      );
      _isUsernameAvailable = available;
      _usernameAvailabilityMessage = available
          ? 'Username is available'
          : 'Username is already taken';
      developer.log(
        'Username availability: $username = $available',
        name: 'hiffi.user',
      );
      return available;
    } catch (error) {
      developer.log(
        'Error checking username availability: $error',
        name: 'hiffi.user',
        error: error,
      );
      _errorMessage = 'Failed to check username availability';
      _isUsernameAvailable = null;
      _usernameAvailabilityMessage = null;
      return false;
    } finally {
      _isCheckingAvailability = false;
      notifyListeners();
    }
  }

  Future<void> createUser({
    required String username,
    required String name,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log(
        'Creating user via API: username=$username, name=$name',
        name: 'hiffi.user',
      );
      _currentUser = await _userRepository.createUser(
        username: username,
        name: name,
      );
      developer.log(
        'User created successfully: ${_currentUser?.username}',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to create user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to create user: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadCurrentUser() async {
    // If we're already loading, don't start another request
    if (_isLoading) return;

    final connectivity = _connectivityService;
    if (connectivity != null) {
      await connectivity.ensureInitialized();
      if (!connectivity.isConnected) {
        developer.log(
          'Skipping loadCurrentUser: No internet connection',
          name: 'hiffi.user',
        );
        _setError(offlineUserMessage);
        return;
      }
    }

    _setLoading(true);
    _setError(null);

    try {
      developer.log('Loading current user by token', name: 'hiffi.user');
      _currentUser = await _userRepository.getCurrentUser();
      developer.log(
        'Current user loaded successfully: ${_currentUser?.username}',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to load current user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
        // If 401 Unauthorized, clear the current user and set flag to prevent infinite retry loops
        if (error.statusCode == 401) {
          developer.log(
            '401 Unauthorized - clearing current user to prevent retry loop',
            name: 'hiffi.user',
          );
          _currentUser = null;
          _hasUnauthorizedError = true;
        } else {
          _hasUnauthorizedError = false;
        }
      } else {
        _setError(
          userFriendlyErrorMessage(
            error,
            fallback: 'Could not load your profile. Please try again.',
          ),
        );
        _hasUnauthorizedError = false;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUser(String username) async {
    // If we're already loading, don't start another request
    if (_isLoading) return;

    final connectivity = _connectivityService;
    if (connectivity != null) {
      await connectivity.ensureInitialized();
      if (!connectivity.isConnected) {
        developer.log(
          'Skipping loadUser: No internet connection',
          name: 'hiffi.user',
        );
        _errorMessage = offlineUserMessage;
        notifyListeners();
        return;
      }
    }

    _setLoading(true);
    _setError(null);
    // Keep existing user on screen while refreshing to avoid full-page flicker.

    try {
      developer.log('Loading user: $username', name: 'hiffi.user');
      // Load the viewed user without overwriting currentUser
      final loadedUser = await _userRepository.getUser(username);
      developer.log(
        'User loaded successfully: ${loadedUser.username}',
        name: 'hiffi.user',
      );
      // Set viewed user and clear errors
      _viewedUser = loadedUser;
      _errorMessage = null;
      _isLoading = false;
      developer.log(
        'Viewed user set: ${_viewedUser?.username}, isLoading: $_isLoading',
        name: 'hiffi.user',
      );
      notifyListeners(); // Notify listeners that user is loaded
    } catch (error) {
      developer.log(
        'Failed to load user: $error',
        name: 'hiffi.user',
        error: error,
      );
      // Keep last loaded profile when offline so the page can still show layout.
      if (!isOfflineError(error)) {
        _viewedUser = null;
      }
      _isLoading = false;
      if (error is ApiException) {
        _errorMessage = error.message;
      } else {
        _errorMessage = userFriendlyErrorMessage(
          error,
          fallback: 'Could not load this profile. Please try again.',
        );
      }
      notifyListeners(); // Notify listeners of error
    }
  }

  Future<void> updateUser({
    required String currentUsername,
    String? newUsername, // Deprecated: username cannot be updated via API
    String? name,
    String? email,
    String? bio,
    String? role,
    String? profilePicture,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log(
        'Updating user: name=$name, email=$email, bio=$bio, profilePicture=$profilePicture',
        name: 'hiffi.user',
      );
      // Note: username cannot be updated via API (per USERS_API.md)
      if (newUsername != null && newUsername.isNotEmpty) {
        throw ApiException(
          'Username cannot be updated. This feature is not supported.',
          400,
        );
      }
      _currentUser = await _userRepository.updateUser(
        currentUsername: currentUsername,
        newUsername: null, // Username updates not supported
        name: name,
        email: email,
        bio: bio,
        role: role,
        profilePicture: profilePicture,
      );
      // Also update viewedUser if it matches the current user
      if (_viewedUser?.username == currentUsername) {
        _viewedUser = _currentUser;
      }
      developer.log(
        'User updated successfully: ${_currentUser?.username}',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to update user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to update user: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> removeProfilePicture() async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log('Removing profile picture', name: 'hiffi.user');

      if (_currentUser == null) {
        throw ApiException('No logged-in user found.', 401);
      }

      // We send an empty string to signify removal
      _currentUser = await _userRepository.updateUser(
        currentUsername: _currentUser!.username,
        profilePicture: '',
      );

      // Also update viewedUser if it matches the current user
      if (_viewedUser?.username == _currentUser?.username) {
        _viewedUser = _currentUser;
      }

      developer.log('Profile picture removed successfully', name: 'hiffi.user');
    } catch (error) {
      developer.log(
        'Failed to remove profile picture: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to remove profile picture: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadProfilePicture(File imageFile) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log('Uploading profile picture', name: 'hiffi.user');

      if (_currentUser == null) {
        throw ApiException('No logged-in user found.', 401);
      }

      // Step 1: Get upload URL
      final uploadData = await _userRepository.getProfilePhotoUploadUrl();
      final gatewayUrl = uploadData['gateway_url'] as String;
      final path = uploadData['path'] as String;

      // Step 2: Upload image to gateway
      await _userRepository.uploadProfilePhoto(gatewayUrl, imageFile);

      // Step 3: Update user profile with the path
      await updateUser(
        currentUsername: _currentUser!.username,
        profilePicture: path,
      );

      developer.log(
        'Profile picture uploaded successfully',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to upload profile picture: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to upload profile picture: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteUser(String username) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log('Deleting user: $username', name: 'hiffi.user');
      await _userRepository.deleteUser(username);
      _currentUser = null;
      developer.log('User deleted successfully', name: 'hiffi.user');
    } catch (error) {
      developer.log(
        'Failed to delete user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to delete user: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> followUser(String username) async {
    if (_isFollowActionLoading) return;
    _isFollowActionLoading = true;
    _setError(null);
    final previousViewedUser = _viewedUser;

    try {
      developer.log('Following user: $username', name: 'hiffi.user');
      if (_viewedUser?.username == username) {
        _viewedUser = _viewedUser!.copyWith(
          isFollowing: true,
          followers: _viewedUser!.followers + 1,
        );
      }
      notifyListeners();
      await _userRepository.followUser(username);
      developer.log('User followed successfully', name: 'hiffi.user');
    } catch (error) {
      _viewedUser = previousViewedUser;
      notifyListeners();
      developer.log(
        'Failed to follow user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to follow user: $error');
      }
      rethrow;
    } finally {
      _isFollowActionLoading = false;
      notifyListeners();
    }
  }

  Future<void> unfollowUser(String username) async {
    if (_isFollowActionLoading) return;
    _isFollowActionLoading = true;
    _setError(null);
    final previousViewedUser = _viewedUser;

    try {
      developer.log('Unfollowing user: $username', name: 'hiffi.user');
      if (_viewedUser?.username == username) {
        final nextFollowers = _viewedUser!.followers > 0
            ? _viewedUser!.followers - 1
            : 0;
        _viewedUser = _viewedUser!.copyWith(
          isFollowing: false,
          followers: nextFollowers,
        );
      }
      notifyListeners();
      await _userRepository.unfollowUser(username);
      developer.log('User unfollowed successfully', name: 'hiffi.user');
    } catch (error) {
      _viewedUser = previousViewedUser;
      notifyListeners();
      developer.log(
        'Failed to unfollow user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to unfollow user: $error');
      }
      rethrow;
    } finally {
      _isFollowActionLoading = false;
      notifyListeners();
    }
  }

  String? _creatorUpgradeOtpId;

  Future<CreatorUpgradeRequestResult> requestCreatorUpgrade() async {
    if (_currentUser == null) {
      throw ApiException('User must be logged in to become a creator', 401);
    }

    _setLoading(true);
    _setError(null);

    try {
      final result = await _userRepository.requestCreatorUpgrade();
      _creatorUpgradeOtpId = result.id;
      return result;
    } catch (error) {
      developer.log(
        'Failed to request creator upgrade: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to request creator upgrade: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserModel> verifyCreatorUpgrade({required String otp}) async {
    if (_currentUser == null) {
      throw ApiException('User must be logged in to become a creator', 401);
    }
    final otpId = _creatorUpgradeOtpId;
    if (otpId == null || otpId.isEmpty) {
      throw ApiException(
        'Creator upgrade session expired. Please request a new code.',
        400,
      );
    }

    _setLoading(true);
    _setError(null);

    try {
      final user = await _userRepository.verifyCreatorUpgrade(
        id: otpId,
        otp: otp.trim(),
      );
      _currentUser = user;
      if (_viewedUser?.username == user.username) {
        _viewedUser = user;
      }
      _creatorUpgradeOtpId = null;
      developer.log('Creator upgrade verified successfully', name: 'hiffi.user');
      notifyListeners();
      return user;
    } catch (error) {
      developer.log(
        'Failed to verify creator upgrade: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to verify creator upgrade: $error');
      }
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void clearUsernameAvailability() {
    _usernameAvailabilityMessage = null;
    _isUsernameAvailable = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  /// Sends OTP for email update
  Future<Map<String, dynamic>> sendEmailUpdateOTP({
    required String currentUsername,
    String? name,
    required String email,
    String? bio,
  }) async {
    _isSendingOTP = true;
    _otpError = null;
    notifyListeners();

    try {
      developer.log(
        'Sending email update OTP: email=$email',
        name: 'hiffi.user',
      );
      final result = await _userRepository.sendEmailUpdateOTP(
        currentUsername: currentUsername,
        name: name,
        email: email,
        bio: bio,
      );
      developer.log(
        'OTP sent successfully: id=${result['id']}',
        name: 'hiffi.user',
      );
      return result;
    } catch (error) {
      developer.log(
        'Failed to send email update OTP: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _otpError = error.message;
      } else {
        _otpError = 'Failed to send OTP: $error';
      }
      rethrow;
    } finally {
      _isSendingOTP = false;
      notifyListeners();
    }
  }

  /// Verifies OTP and completes email update
  Future<void> verifyEmailUpdateOTP({
    required String id,
    required String otp,
    required String currentUsername,
  }) async {
    _isVerifyingOTP = true;
    _otpError = null;
    notifyListeners();

    try {
      developer.log('Verifying email update OTP: id=$id', name: 'hiffi.user');
      _currentUser = await _userRepository.verifyEmailUpdateOTP(
        id: id,
        otp: otp,
      );
      // Also update viewedUser if it matches the current user
      if (_viewedUser?.username == currentUsername) {
        _viewedUser = _currentUser;
      }
      developer.log(
        'Email update verified successfully: ${_currentUser?.username}',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to verify email update OTP: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _otpError = error.message;
      } else {
        _otpError = 'Failed to verify OTP: $error';
      }
      rethrow;
    } finally {
      _isVerifyingOTP = false;
      notifyListeners();
    }
  }

  /// Clears OTP state (call when OTP flow is cancelled/completed)
  void clearOTPState() {
    _isSendingOTP = false;
    _isVerifyingOTP = false;
    _otpError = null;
    notifyListeners();
  }
}
