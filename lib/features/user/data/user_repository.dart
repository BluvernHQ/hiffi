import 'dart:developer' as developer;
import 'dart:convert';

import '../../../core/exceptions/api_exception.dart';
import '../../../core/services/api_client.dart';
import '../../../core/constants/api_constants.dart';
import '../domain/models/user_model.dart';

abstract class UserRepository {
  Future<bool> checkUsernameAvailability(String username);
  Future<UserModel> createUser({
    required String username,
    required String name,
  });
  Future<UserModel> getCurrentUser(); // Get current user by token
  Future<UserModel> getUser(String username);
  Future<UserModel> updateUser({
    required String currentUsername,
    String? newUsername,
    String? name,
  });
  Future<void> deleteUser(String username);
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<bool> checkUsernameAvailability(String username) async {
    developer.log(
      'Checking username availability: $username',
      name: 'hiffi.user',
    );
    print('🔍 Checking username availability: $username');

    try {
      final response = await _apiClient.get(
        '${ApiConstants.userAvailability}/$username',
        requiresAuth: false,
      );

      developer.log(
        'Username availability check response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final available = body['available'] as bool? ?? false;
        print(
          '   ✅ Username $username is ${available ? "available" : "taken"}',
        );
        return available;
      } else {
        print('   ⚠️ Unexpected status code: ${response.statusCode}');
        // If API returns non-200, assume username is taken for safety
        return false;
      }
    } catch (error) {
      developer.log(
        'Failed to check username availability: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error checking availability: $error');
      // On error, assume username is taken to prevent conflicts
      return false;
    }
  }

  @override
  Future<UserModel> createUser({
    required String username,
    required String name,
  }) async {
    developer.log(
      'Creating user: username=$username, name=$name',
      name: 'hiffi.user',
    );
    print('👤 Creating user: $username');

    try {
      final response = await _apiClient.post(ApiConstants.createUser, {
        'username': username,
        'name': name,
      }, requiresAuth: true);

      developer.log(
        'Create user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(body);
        print('   ✅ User created successfully');
        print('   📄 User data: ${user.toJson()}');
        return user;
      } else {
        final errorMessage = 'Failed to create user: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to create user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error creating user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to create user: $error', null);
    }
  }

  @override
  Future<UserModel> getCurrentUser() async {
    developer.log('Getting current user by token', name: 'hiffi.user');
    print('👤 Getting current user by token');

    try {
      final response = await _apiClient.get(
        ApiConstants.getCurrentUser,
        requiresAuth: true,
      );

      developer.log(
        'Get current user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        // Handle nested response structure: {"success": true, "user": {...}}
        final user = UserModel.fromJson(body);
        print('   ✅ Current user retrieved successfully');
        print('   📄 User data: ${user.toJson()}');
        return user;
      } else {
        final errorMessage =
            'Failed to get current user: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to get current user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error getting current user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to get current user: $error', null);
    }
  }

  @override
  Future<UserModel> getUser(String username) async {
    developer.log('Getting user: $username', name: 'hiffi.user');
    print('👤 Getting user: $username');

    try {
      final response = await _apiClient.get(
        ApiConstants.getUser(username),
        requiresAuth: true,
      );

      developer.log(
        'Get user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(body);
        print('   ✅ User retrieved successfully');
        print('   📄 User data: ${user.toJson()}');
        return user;
      } else {
        final errorMessage = 'Failed to get user: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to get user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error getting user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to get user: $error', null);
    }
  }

  @override
  Future<UserModel> updateUser({
    required String currentUsername,
    String? newUsername,
    String? name,
  }) async {
    developer.log(
      'Updating user: currentUsername=$currentUsername, newUsername=$newUsername, name=$name',
      name: 'hiffi.user',
    );
    print('✏️ Updating user: $currentUsername');

    try {
      // If username is being changed, check availability first
      if (newUsername != null &&
          newUsername.isNotEmpty &&
          newUsername != currentUsername) {
        print('   🔍 Checking username availability: $newUsername');
        final isAvailable = await checkUsernameAvailability(newUsername);
        if (!isAvailable) {
          throw ApiException('Username "$newUsername" is already taken', 400);
        }
        print('   ✅ Username "$newUsername" is available');
      }

      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        body['name'] = name;
      }
      if (newUsername != null &&
          newUsername.isNotEmpty &&
          newUsername != currentUsername) {
        body['username'] = newUsername;
      }

      final response = await _apiClient.put(
        ApiConstants.updateUser(currentUsername),
        body,
        requiresAuth: true,
      );

      developer.log(
        'Update user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        final user = UserModel.fromJson(responseBody);
        print('   ✅ User updated successfully');
        print('   📄 Updated user data: ${user.toJson()}');
        return user;
      } else {
        final errorMessage = 'Failed to update user: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to update user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error updating user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to update user: $error', null);
    }
  }

  @override
  Future<void> deleteUser(String username) async {
    developer.log('Deleting user: $username', name: 'hiffi.user');
    print('🗑️ Deleting user: $username');

    try {
      final response = await _apiClient.delete(
        ApiConstants.deleteUser(username),
        requiresAuth: true,
      );

      developer.log(
        'Delete user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('   ✅ User deleted successfully');
      } else {
        final errorMessage = 'Failed to delete user: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to delete user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error deleting user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to delete user: $error', null);
    }
  }
}
