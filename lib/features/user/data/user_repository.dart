import 'dart:developer' as developer;
import 'dart:convert';
import 'dart:io';

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
    String? email,
    String? bio,
    String? role,
    String? profilePicture,
  });
  Future<Map<String, dynamic>> getProfilePhotoUploadUrl();
  Future<void> uploadProfilePhoto(String gatewayUrl, File imageFile);
  Future<void> deleteUser(String username);
  Future<void> followUser(String username);
  Future<void> unfollowUser(String username);
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
        // API returns: {"success": true, "data": {"available": true/false, "username": "..."}}
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final available = data?['available'] as bool? ?? false;
          print(
            '   ✅ Username $username is ${available ? "available" : "taken"}',
          );
          return available;
        } else {
          // Fallback: check for 'available' field directly (if no data wrapper)
          final available = body['available'] as bool? ?? false;
          print(
            '   ✅ Username $username is ${available ? "available" : "taken"}',
          );
          return available;
        }
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
    // Note: Users are now created via /auth/register endpoint
    // This method is kept for backward compatibility but may not be used
    throw ApiException(
      'User creation is handled via /auth/register endpoint. Use authentication registration instead.',
      400,
    );
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
        // API returns: {"success": true, "data": {"user": {...}}}
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final userData = data?['user'] as Map<String, dynamic>?;
          if (userData != null) {
            final user = UserModel.fromJson({'user': userData});
            print('   ✅ Current user retrieved successfully');
            print('   📄 User data: ${user.toJson()}');
            return user;
          }
        }
        // Fallback: try parsing with status: success structure
        if (body['status'] == 'success' && body['user'] != null) {
          final user = UserModel.fromJson(body);
          print('   ✅ Current user retrieved successfully');
          print('   📄 User data: ${user.toJson()}');
          return user;
        }
        // Final fallback: try parsing user directly
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
        // API returns: {"success": true, "data": {"following": true, "user": {...}}}
        if (body['success'] == true) {
          final data = body['data'] as Map<String, dynamic>?;
          final userData = data?['user'] as Map<String, dynamic>?;
          if (userData != null) {
            // Extract following status from data level
            final following = data?['following'] as bool?;

            // Add following status to user data for parsing
            final userDataWithFollowing = Map<String, dynamic>.from(userData);
            if (following != null) {
              userDataWithFollowing['is_following'] = following;
            }

            final user = UserModel.fromJson({'user': userDataWithFollowing});
            print('   ✅ User retrieved successfully');
            print('   📄 User data: ${user.toJson()}');
            return user;
          }
        }
        // Fallback: try parsing with status: success structure
        if (body['status'] == 'success' && body['user'] != null) {
          final user = UserModel.fromJson(body);
          print('   ✅ User retrieved successfully');
          print('   📄 User data: ${user.toJson()}');
          return user;
        }
        // Final fallback: try parsing user directly
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
    String? email,
    String? bio,
    String? role,
    String? profilePicture,
  }) async {
    developer.log(
      'Updating user: name=$name, email=$email, bio=$bio',
      name: 'hiffi.user',
    );
    print('✏️ Updating user profile');

    try {
      // Note: Username cannot be updated via the API (per USERS_API.md)
      if (newUsername != null && newUsername.isNotEmpty) {
        throw ApiException(
          'Username cannot be updated. This feature is not supported.',
          400,
        );
      }

      final body = <String, dynamic>{};
      if (name != null && name.isNotEmpty) {
        body['name'] = name;
      }
      if (email != null) {
        body['email'] = email;
      }
      if (bio != null) {
        body['bio'] = bio;
      }
      if (role != null && role.isNotEmpty) {
        body['role'] = role;
      }
      if (profilePicture != null) {
        body['profile_picture'] = profilePicture;
      }

      // Use /users/self endpoint (user identified by JWT token)
      final response = await _apiClient.put(
        ApiConstants.updateUser,
        body,
        requiresAuth: true,
      );

      developer.log(
        'Update user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        // API returns: {"success": true, "data": {"user": {...}}}
        if (responseBody['success'] == true) {
          final data = responseBody['data'] as Map<String, dynamic>?;
          final userData = data?['user'] as Map<String, dynamic>?;
          if (userData != null) {
            final user = UserModel.fromJson({'user': userData});
            print('   ✅ User updated successfully');
            print('   📄 Updated user data: ${user.toJson()}');
            return user;
          }
        }
        // Fallback: try parsing with status: success structure
        if (responseBody['status'] == 'success' &&
            responseBody['user'] != null) {
          final user = UserModel.fromJson(responseBody);
          print('   ✅ User updated successfully');
          print('   📄 Updated user data: ${user.toJson()}');
          return user;
        }
        // Final fallback: try parsing user directly
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
  Future<Map<String, dynamic>> getProfilePhotoUploadUrl() async {
    developer.log('Getting profile photo upload URL', name: 'hiffi.user');
    print('📸 Getting profile photo upload URL');

    try {
      final response = await _apiClient.post(
        ApiConstants.profilePhotoUpload,
        {},
        requiresAuth: true,
      );

      developer.log(
        'Profile photo upload URL response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body) as Map<String, dynamic>;
        if (responseBody['success'] == true) {
          final data = responseBody['data'] as Map<String, dynamic>?;
          if (data != null) {
            final gatewayUrl = data['gateway_url'] as String?;
            final path = data['path'] as String?;
            if (gatewayUrl != null && path != null) {
              print('   ✅ Profile photo upload URL received');
              return {'gateway_url': gatewayUrl, 'path': path};
            }
          }
        }
        throw ApiException('Invalid response format', response.statusCode);
      } else {
        final errorMessage =
            'Failed to get profile photo upload URL: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to get profile photo upload URL: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error getting profile photo upload URL: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException(
        'Failed to get profile photo upload URL: $error',
        null,
      );
    }
  }

  @override
  Future<void> uploadProfilePhoto(String gatewayUrl, File imageFile) async {
    developer.log('Uploading profile photo', name: 'hiffi.user');
    print('📤 Uploading profile photo to gateway');

    try {
      final response = await _apiClient.uploadFileToGateway(
        gatewayUrl,
        imageFile,
        contentType: 'image/jpeg',
      );

      developer.log(
        'Profile photo upload response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        print('   ✅ Profile photo uploaded successfully');
      } else {
        final errorMessage =
            'Failed to upload profile photo: ${response.statusCode}';
        developer.log(errorMessage, name: 'hiffi.user');
        print('   ❌ $errorMessage');
        throw ApiException(errorMessage, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to upload profile photo: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error uploading profile photo: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to upload profile photo: $error', null);
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

  @override
  Future<void> followUser(String username) async {
    developer.log('Following user: $username', name: 'hiffi.user');
    print('👥 Following user: $username');

    try {
      final response = await _apiClient.post(
        ApiConstants.followUser(username),
        {},
        requiresAuth: true,
      );

      developer.log(
        'Follow user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // API returns: {"success": true, "data": {"message": "Followed successfully"}}
        if (json['success'] != true) {
          final error = json['error'] as String? ?? 'Failed to follow user';
          throw ApiException(error, response.statusCode);
        }

        print('   ✅ User followed successfully');
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String? ?? 'Failed to follow user';
        developer.log(error, name: 'hiffi.user');
        print('   ❌ $error');
        throw ApiException(error, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to follow user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error following user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to follow user: $error', null);
    }
  }

  @override
  Future<void> unfollowUser(String username) async {
    developer.log('Unfollowing user: $username', name: 'hiffi.user');
    print('👥 Unfollowing user: $username');

    try {
      final response = await _apiClient.post(
        ApiConstants.unfollowUser(username),
        {},
        requiresAuth: true,
      );

      developer.log(
        'Unfollow user response: ${response.statusCode}',
        name: 'hiffi.user',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;

        // API returns: {"success": true, "data": {"message": "Unfollowed successfully"}}
        if (json['success'] != true) {
          final error = json['error'] as String? ?? 'Failed to unfollow user';
          throw ApiException(error, response.statusCode);
        }

        print('   ✅ User unfollowed successfully');
      } else {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final error = json['error'] as String? ?? 'Failed to unfollow user';
        developer.log(error, name: 'hiffi.user');
        print('   ❌ $error');
        throw ApiException(error, response.statusCode);
      }
    } catch (error) {
      developer.log(
        'Failed to unfollow user: $error',
        name: 'hiffi.user',
        error: error,
      );
      print('   ❌ Error unfollowing user: $error');
      if (error is ApiException) {
        rethrow;
      }
      throw ApiException('Failed to unfollow user: $error', null);
    }
  }
}
