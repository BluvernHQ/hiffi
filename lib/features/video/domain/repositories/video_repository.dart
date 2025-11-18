import 'dart:convert';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_client.dart';
import '../models/comment_model.dart';
import '../models/video_model.dart';

abstract class VideoRepository {
  Future<List<VideoModel>> getVideos({required int page, required int limit});
  Future<String> getVideoUrl(String videoUrl);
  Future<void> upvoteVideo(String videoId);
  Future<void> downvoteVideo(String videoId);
  Future<String?> getUserVoteStatus(String videoId);
  Future<void> postComment(String videoId, String comment);
  Future<List<CommentModel>> getComments(
    String videoId, {
    required int page,
    required int limit,
  });
  Future<void> postReply(String commentId, String reply);
  Future<List<ReplyModel>> getReplies(
    String commentId, {
    required int page,
    required int limit,
  });
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

  @override
  Future<String> getVideoUrl(String videoUrl) async {
    // Note: This endpoint does NOT require authentication (no bearer token)
    final response = await _apiClient.get(
      ApiConstants.getVideoUrl(videoUrl),
      requiresAuth: false,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch video URL: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final videoUrlFromApi = json['video_url'] as String?;

    if (videoUrlFromApi == null || videoUrlFromApi.isEmpty) {
      throw Exception('Video URL not found in response');
    }

    return videoUrlFromApi;
  }

  @override
  Future<void> upvoteVideo(String videoId) async {
    final response = await _apiClient.post(
      ApiConstants.upvoteVideo(videoId),
      {},
      requiresAuth: true,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upvote video: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String?;

    if (status != 'success') {
      throw Exception('Upvote failed: ${json['message'] ?? 'Unknown error'}');
    }
  }

  @override
  Future<void> downvoteVideo(String videoId) async {
    final response = await _apiClient.post(
      ApiConstants.downvoteVideo(videoId),
      {},
      requiresAuth: true,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to downvote video: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String?;

    if (status != 'success') {
      throw Exception('Downvote failed: ${json['message'] ?? 'Unknown error'}');
    }
  }

  @override
  Future<String?> getUserVoteStatus(String videoId) async {
    // Try to get vote status from a dedicated endpoint if available
    // For now, we'll check if the video model already has this info
    // If not, we can add a dedicated endpoint later
    // This is a placeholder - the actual implementation depends on the API
    try {
      // If there's a dedicated endpoint, use it here
      // For now, return null and rely on the video model's userVoteStatus field
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> postComment(String videoId, String comment) async {
    final response = await _apiClient.post(ApiConstants.postComment(videoId), {
      'comment': comment,
    }, requiresAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to post comment: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String?;

    if (status != 'success') {
      throw Exception(
        'Post comment failed: ${json['message'] ?? 'Unknown error'}',
      );
    }
  }

  @override
  Future<List<CommentModel>> getComments(
    String videoId, {
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.post(ApiConstants.getComments(videoId), {
      'page': page,
      'limit': limit,
    }, requiresAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch comments: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final commentsJson = json['comments'] as List<dynamic>? ?? [];

    return commentsJson
        .map(
          (commentJson) =>
              CommentModel.fromJson(commentJson as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> postReply(String commentId, String reply) async {
    final response = await _apiClient.post(ApiConstants.postReply(commentId), {
      'reply': reply,
    }, requiresAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to post reply: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final status = json['status'] as String?;

    if (status != 'success') {
      throw Exception(
        'Post reply failed: ${json['message'] ?? 'Unknown error'}',
      );
    }
  }

  @override
  Future<List<ReplyModel>> getReplies(
    String commentId, {
    required int page,
    required int limit,
  }) async {
    final response = await _apiClient.post(ApiConstants.getReplies(commentId), {
      'page': page,
      'limit': limit,
    }, requiresAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch replies: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final repliesJson = json['replies'] as List<dynamic>? ?? [];

    return repliesJson
        .map(
          (replyJson) => ReplyModel.fromJson(replyJson as Map<String, dynamic>),
        )
        .toList();
  }
}
