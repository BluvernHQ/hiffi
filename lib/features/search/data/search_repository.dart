import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/api_client.dart';
import '../../user/domain/models/user_model.dart';
import '../../video/domain/models/video_model.dart';

/// Response model for user search results
class UserSearchResult {
  final List<UserModel> users;
  final int count;
  final int limit;
  final String query;

  UserSearchResult({
    required this.users,
    required this.count,
    required this.limit,
    required this.query,
  });
}

/// Response model for video search results
class VideoSearchResult {
  final List<VideoModel> videos;
  final int count;
  final int limit;
  final String query;

  VideoSearchResult({
    required this.videos,
    required this.count,
    required this.limit,
    required this.query,
  });
}

abstract class SearchRepository {
  Future<UserSearchResult> searchUsers(
    String query, {
    int page = 1,
    int limit = 50,
  });
  Future<VideoSearchResult> searchVideos(
    String query, {
    int page = 1,
    int limit = 100,
  });
}

class ApiSearchRepository implements SearchRepository {
  ApiSearchRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserSearchResult> searchUsers(
    String query, {
    int page = 1,
    int limit = 50,
  }) async {
    if (query.trim().isEmpty) {
      return UserSearchResult(users: [], count: 0, limit: limit, query: query);
    }

    try {
      final response = await _apiClient.get(
        ApiConstants.searchUsers(query, page: page, limit: limit),
        requiresAuth: false,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          final usersList = data['users'] as List<dynamic>? ?? [];

          final users = usersList
              .map((json) => UserModel.fromJson(json as Map<String, dynamic>))
              .toList();

          return UserSearchResult(
            users: users,
            count: (data['count'] as num?)?.toInt() ?? 0,
            limit: (data['limit'] as num?)?.toInt() ?? limit,
            query: data['query'] as String? ?? query,
          );
        }
      }

      // Return empty result on error
      return UserSearchResult(users: [], count: 0, limit: limit, query: query);
    } catch (error) {
      print('❌ Error searching users: $error');
      return UserSearchResult(users: [], count: 0, limit: limit, query: query);
    }
  }

  @override
  Future<VideoSearchResult> searchVideos(
    String query, {
    int page = 1,
    int limit = 100,
  }) async {
    if (query.trim().isEmpty) {
      return VideoSearchResult(
        videos: [],
        count: 0,
        limit: limit,
        query: query,
      );
    }

    try {
      final response = await _apiClient.get(
        ApiConstants.searchVideos(query, page: page, limit: limit),
        requiresAuth: false,
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;

        if (body['success'] == true && body['data'] != null) {
          final data = body['data'] as Map<String, dynamic>;
          final videosList = data['videos'] as List<dynamic>? ?? [];

          // Parse videos with error handling for missing/null fields
          // Search API may return simplified video objects missing some fields
          final videos = <VideoModel>[];
          for (final videoJson in videosList) {
            try {
              final videoMap = videoJson as Map<String, dynamic>;

              // Ensure all required fields have values (search API may omit some)
              final enrichedVideoMap = Map<String, dynamic>.from(videoMap);

              // Provide defaults for missing or null required fields
              final videoId = videoMap['video_id'] as String? ?? '';
              enrichedVideoMap['video_url'] =
                  videoMap['video_url'] ?? 'videos/$videoId';
              enrichedVideoMap['video_thumbnail'] =
                  videoMap['video_thumbnail'] ??
                  'thumbnails/videos/$videoId.jpg';
              enrichedVideoMap['user_uid'] = videoMap['user_uid'] ?? '';
              enrichedVideoMap['user_username'] =
                  videoMap['user_username'] ?? '';
              enrichedVideoMap['created_at'] =
                  videoMap['created_at'] ?? DateTime.now().toIso8601String();
              enrichedVideoMap['updated_at'] =
                  videoMap['updated_at'] ?? DateTime.now().toIso8601String();

              // Only parse if we have the minimum required fields
              if (enrichedVideoMap['video_id'] != null &&
                  enrichedVideoMap['video_title'] != null) {
                videos.add(VideoModel.fromJson(enrichedVideoMap));
              } else {
                print('⚠️ Skipping video with missing required fields');
              }
            } catch (e, stackTrace) {
              print('⚠️ Error parsing video: $e');
              print('   Stack trace: $stackTrace');
              // Continue with next video instead of failing entire search
              continue;
            }
          }

          return VideoSearchResult(
            videos: videos,
            count: (data['count'] as num?)?.toInt() ?? 0,
            limit: (data['limit'] as num?)?.toInt() ?? limit,
            query: data['query'] as String? ?? query,
          );
        }
      }

      // Return empty result on error
      return VideoSearchResult(
        videos: [],
        count: 0,
        limit: limit,
        query: query,
      );
    } catch (error) {
      print('❌ Error searching videos: $error');
      return VideoSearchResult(
        videos: [],
        count: 0,
        limit: limit,
        query: query,
      );
    }
  }
}
