import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/services/api_client.dart';
import '../../user/domain/models/user_model.dart';
import '../../video/domain/models/video_model.dart';

/// Response model for user search results.
class UserSearchResult {
  final List<UserModel> users;
  final int count;
  final int limit;
  final int offset;
  final String query;

  UserSearchResult({
    required this.users,
    required this.count,
    required this.limit,
    required this.offset,
    required this.query,
  });
}

/// Response model for video search results.
class VideoSearchResult {
  final List<VideoModel> videos;
  final int count;
  final int limit;
  final int offset;
  final String query;

  VideoSearchResult({
    required this.videos,
    required this.count,
    required this.limit,
    required this.offset,
    required this.query,
  });
}

abstract class SearchRepository {
  Future<UserSearchResult> searchUsers(
    String query, {
    int offset = 0,
    int limit = 20,
  });

  Future<VideoSearchResult> searchVideos(
    String query, {
    int offset = 0,
    int limit = 20,
  });
}

class ApiSearchRepository implements SearchRepository {
  ApiSearchRepository({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<UserSearchResult> searchUsers(
    String query, {
    int offset = 0,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return UserSearchResult(
        users: [],
        count: 0,
        limit: limit,
        offset: offset,
        query: query,
      );
    }

    final response = await _apiClient.get(
      ApiConstants.searchUsers(trimmed, limit: limit, offset: offset),
      requiresAuth: false,
    );

    if (response.statusCode == 400) {
      throw ApiException('Search query is missing or invalid.', 400);
    }
    if (response.statusCode != 200) {
      final message = _errorMessage(response.body) ?? 'Search failed';
      throw ApiException(message, response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true || body['data'] == null) {
      throw ApiException(
        _errorMessage(response.body) ?? 'Search failed',
        response.statusCode,
      );
    }

    final data = body['data'] as Map<String, dynamic>;
    final usersList = data['users'] as List<dynamic>? ?? [];
    final users = usersList
        .whereType<Map<String, dynamic>>()
        .map(_parseSearchUser)
        .toList();

    return UserSearchResult(
      users: users,
      count: (data['count'] as num?)?.toInt() ?? users.length,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      query: data['query'] as String? ?? trimmed,
    );
  }

  @override
  Future<VideoSearchResult> searchVideos(
    String query, {
    int offset = 0,
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return VideoSearchResult(
        videos: [],
        count: 0,
        limit: limit,
        offset: offset,
        query: query,
      );
    }

    final response = await _apiClient.get(
      ApiConstants.searchVideos(trimmed, limit: limit, offset: offset),
      requiresAuth: false,
    );

    if (response.statusCode == 400) {
      throw ApiException('Search query is missing or invalid.', 400);
    }
    if (response.statusCode != 200) {
      final message = _errorMessage(response.body) ?? 'Search failed';
      throw ApiException(message, response.statusCode);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['success'] != true || body['data'] == null) {
      throw ApiException(
        _errorMessage(response.body) ?? 'Search failed',
        response.statusCode,
      );
    }

    final data = body['data'] as Map<String, dynamic>;
    final videosList = data['videos'] as List<dynamic>? ?? [];
    final videos = <VideoModel>[];
    for (final videoJson in videosList) {
      if (videoJson is! Map<String, dynamic>) continue;
      final video = _parseSearchVideo(videoJson);
      if (video != null) videos.add(video);
    }

    return VideoSearchResult(
      videos: videos,
      count: (data['count'] as num?)?.toInt() ?? videos.length,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      query: data['query'] as String? ?? trimmed,
    );
  }

  UserModel _parseSearchUser(Map<String, dynamic> json) {
    // Preserve backend relevance score without passing unknown keys to UserModel.
    final _ = (json['_score'] as num?)?.toDouble();
    return UserModel.fromJson(json);
  }

  VideoModel? _parseSearchVideo(Map<String, dynamic> videoMap) {
    // Preserve backend relevance score without passing unknown keys to VideoModel.
    final _ = (videoMap['_score'] as num?)?.toDouble();

    final enrichedVideoMap = Map<String, dynamic>.from(videoMap);
    final videoId = videoMap['video_id'] as String? ?? '';
    enrichedVideoMap['video_url'] =
        videoMap['video_url'] ?? 'videos/$videoId';
    enrichedVideoMap['video_thumbnail'] =
        videoMap['video_thumbnail'] ?? 'thumbnails/videos/$videoId.jpg';
    enrichedVideoMap['user_uid'] = videoMap['user_uid'] ?? '';
    enrichedVideoMap['user_username'] = videoMap['user_username'] ?? '';
    enrichedVideoMap['created_at'] =
        videoMap['created_at'] ?? DateTime.now().toIso8601String();
    enrichedVideoMap['updated_at'] =
        videoMap['updated_at'] ?? DateTime.now().toIso8601String();

    if (videoId.isEmpty || enrichedVideoMap['video_title'] == null) {
      return null;
    }

    return VideoModel.fromJson(enrichedVideoMap);
  }

  String? _errorMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString();
      }
      return payload['message']?.toString();
    } catch (_) {
      return null;
    }
  }
}
