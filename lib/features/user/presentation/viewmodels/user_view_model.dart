import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter/material.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';

class UserViewModel extends ChangeNotifier {
  UserViewModel({required UserRepository userRepository})
    : _userRepository = userRepository;

  final UserRepository _userRepository;

  UserModel?
  _currentUser; // The logged-in user (should never be overwritten by loadUser)
  UserModel? _viewedUser; // The user being viewed in profile pages
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
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
  String? get errorMessage => _errorMessage;
  String? get usernameAvailabilityMessage => _usernameAvailabilityMessage;
  bool? get isUsernameAvailable => _isUsernameAvailable;
  bool get hasUnauthorizedError => _hasUnauthorizedError;

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
        _setError('Failed to load current user: $error');
        _hasUnauthorizedError = false;
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUser(String username) async {
    _setLoading(true);
    _setError(null);
    _viewedUser = null; // Clear previous viewed user
    notifyListeners(); // Notify that we're starting to load

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
      // Clear viewed user on error
      _viewedUser = null;
      _isLoading = false;
      if (error is ApiException) {
        _errorMessage = error.message;
      } else {
        _errorMessage = 'Failed to load user: $error';
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
    _setLoading(true);
    _setError(null);

    try {
      developer.log('Following user: $username', name: 'hiffi.user');
      await _userRepository.followUser(username);

      // Reload user to get updated follow status
      if (_viewedUser?.username == username) {
        // If viewing the user being followed, reload to update isFollowing
        await loadUser(username);
      } else {
        // Reload current user to update following count
        await loadCurrentUser();
      }

      developer.log('User followed successfully', name: 'hiffi.user');
    } catch (error) {
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
      _setLoading(false);
    }
  }

  Future<void> unfollowUser(String username) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log('Unfollowing user: $username', name: 'hiffi.user');
      await _userRepository.unfollowUser(username);

      // Reload user to get updated follow status
      if (_viewedUser?.username == username) {
        // If viewing the user being unfollowed, reload to update isFollowing
        await loadUser(username);
      } else {
        // Reload current user to update following count
        await loadCurrentUser();
      }

      developer.log('User unfollowed successfully', name: 'hiffi.user');
    } catch (error) {
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
      _setLoading(false);
    }
  }

  Future<void> becomeCreator() async {
    if (_currentUser == null) {
      throw ApiException('User must be logged in to become a creator', 401);
    }

    _setLoading(true);
    _setError(null);

    try {
      developer.log('Updating user role to creator', name: 'hiffi.user');
      _currentUser = await _userRepository.updateUser(
        currentUsername: _currentUser!.username,
        newUsername: null,
        name: null,
        email: null,
        bio: null,
        role: 'creator',
      );
      // Also update viewedUser if it matches the current user
      if (_viewedUser?.username == _currentUser?.username) {
        _viewedUser = _currentUser;
      }
      developer.log(
        'User role updated to creator successfully',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to become creator: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to become creator: $error');
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
}
