import 'dart:convert';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_client.dart';
import '../models/video_model.dart';

abstract class VideoRepository {
  Future<List<VideoModel>> getVideos({required int page, required int limit});
}

class VideoRepositoryImpl implements VideoRepository {
  VideoRepositoryImpl({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<List<VideoModel>> getVideos({
    required int page,
    required int limit,
  }) async {
    // Note: This endpoint does NOT require authentication (no bearer token)
    // Backend expects POST with body, not GET with query params
    final response = await _apiClient.post(ApiConstants.videoList, {
      'page': page,
      'limit': limit,
    }, requiresAuth: false);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch videos: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final videosJson = json['videos'] as List<dynamic>? ?? [];
    return videosJson
        .map(
          (videoJson) => VideoModel.fromJson(videoJson as Map<String, dynamic>),
        )
        .toList();
  }
}
