import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../data/user_repository.dart';
import '../../domain/models/user_model.dart';

class UserViewModel extends ChangeNotifier {
  UserViewModel({required UserRepository userRepository})
    : _userRepository = userRepository;

  final UserRepository _userRepository;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  String? _errorMessage;
  String? _usernameAvailabilityMessage;
  bool? _isUsernameAvailable;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isCheckingAvailability => _isCheckingAvailability;
  String? get errorMessage => _errorMessage;
  String? get usernameAvailabilityMessage => _usernameAvailabilityMessage;
  bool? get isUsernameAvailable => _isUsernameAvailable;

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
      } else {
        _setError('Failed to load current user: $error');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadUser(String username) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log('Loading user: $username', name: 'hiffi.user');
      _currentUser = await _userRepository.getUser(username);
      developer.log(
        'User loaded successfully: ${_currentUser?.username}',
        name: 'hiffi.user',
      );
    } catch (error) {
      developer.log(
        'Failed to load user: $error',
        name: 'hiffi.user',
        error: error,
      );
      if (error is ApiException) {
        _setError(error.message);
      } else {
        _setError('Failed to load user: $error');
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateUser({
    required String currentUsername,
    String? newUsername,
    String? name,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      developer.log(
        'Updating user: currentUsername=$currentUsername, newUsername=$newUsername, name=$name',
        name: 'hiffi.user',
      );
      _currentUser = await _userRepository.updateUser(
        currentUsername: currentUsername,
        newUsername: newUsername,
        name: name,
      );
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
      if (_currentUser?.username == username) {
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
      if (_currentUser?.username == username) {
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
