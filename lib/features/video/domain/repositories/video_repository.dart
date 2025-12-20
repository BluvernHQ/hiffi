import 'dart:convert';
import 'dart:math';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/services/api_client.dart';
import '../models/comment_model.dart';
import '../models/video_model.dart';

/// Response model for video info including URL and user interaction status
class VideoInfo {
  final String videoUrl;
  final bool upvoted;
  final bool downvoted;
  final bool following;

  VideoInfo({
    required this.videoUrl,
    required this.upvoted,
    required this.downvoted,
    required this.following,
  });
}

abstract class VideoRepository {
  Future<List<VideoModel>> getVideos({
    required int page,
    required int limit,
    String? searchQuery,
    String? seed,
  });
  Future<List<VideoModel>> getUserVideos({
    required int limit,
    required int offset,
    String? seed,
  });
  Future<VideoInfo> getVideoInfo(String videoId);
  Future<String> getVideoUrl(
    String videoId,
  ); // Deprecated: use getVideoInfo instead
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
    String? searchQuery,
    String? seed,
  }) async {
    // API uses GET with query parameters: limit, offset, seed
    // Convert page to offset (offset = (page - 1) * limit)
    final offset = (page - 1) * limit;

    // Build query parameters
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    // Use provided seed or generate a random one for deterministic random pagination
    final seedToUse = seed ?? _generateRandomSeed();
    queryParams['seed'] = seedToUse;

    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final endpoint = '${ApiConstants.videoList}?$queryString';

    // Authentication is optional - provides additional info if authenticated
    final response = await _apiClient.get(endpoint, optionalAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch videos: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // API returns: {"success": true, "data": {"videos": [{"video": {...}, "following": true}]}}
    if (json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final videosJson = data['videos'] as List<dynamic>? ?? [];
        final videos = <VideoModel>[];

        for (final item in videosJson) {
          try {
            final itemMap = item as Map<String, dynamic>;
            // Extract video object from nested structure
            final videoJson = itemMap['video'] as Map<String, dynamic>?;

            if (videoJson != null) {
              // Extract profile_picture from outer item (not from video object)
              final profilePicture = itemMap['profile_picture'] as String?;

              // Add profile_picture to videoJson before parsing
              final videoJsonWithProfile = Map<String, dynamic>.from(videoJson);
              if (profilePicture != null) {
                videoJsonWithProfile['profile_picture'] = profilePicture;
              }

              final video = VideoModel.fromJson(videoJsonWithProfile);
              videos.add(video);
              // Note: Following status is available in itemMap['following'] if needed in the future
            } else {
              // Fallback: treat entire item as video object if no nested 'video' key
              final video = VideoModel.fromJson(itemMap);
              videos.add(video);
            }
          } catch (e) {
            // Log error but continue parsing other videos
            print('⚠️ Error parsing video: $e');
            print('   Item: $item');
          }
        }

        return videos;
      }
    }

    // Fallback for old format: {"status": "success", "videos": [...]}
    if (json['status'] == 'success' || json['videos'] != null) {
      final videosJson = json['videos'] as List<dynamic>? ?? [];
      return videosJson
          .map(
            (videoJson) =>
                VideoModel.fromJson(videoJson as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception('Unexpected response format: ${json.keys}');
  }

  @override
  Future<List<VideoModel>> getUserVideos({
    required int limit,
    required int offset,
    String? seed,
  }) async {
    // Build query parameters
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    // Use provided seed or generate a random one for deterministic random pagination
    final seedToUse = seed ?? _generateRandomSeed();
    queryParams['seed'] = seedToUse;

    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final endpoint = '${ApiConstants.videoListSelf}?$queryString';

    // Authentication is required for /videos/list/self
    final response = await _apiClient.get(endpoint, requiresAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch user videos: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // API returns: {"success": true, "data": {"videos": [{"video": {...}, "following": true}]}}
    if (json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final videosJson = data['videos'] as List<dynamic>? ?? [];
        final videos = <VideoModel>[];

        for (final item in videosJson) {
          try {
            final itemMap = item as Map<String, dynamic>;
            // Extract video object from nested structure
            final videoJson = itemMap['video'] as Map<String, dynamic>?;

            if (videoJson != null) {
              // Extract profile_picture from outer item (not from video object)
              final profilePicture = itemMap['profile_picture'] as String?;

              // Add profile_picture to videoJson before parsing
              final videoJsonWithProfile = Map<String, dynamic>.from(videoJson);
              if (profilePicture != null) {
                videoJsonWithProfile['profile_picture'] = profilePicture;
              }

              final video = VideoModel.fromJson(videoJsonWithProfile);
              videos.add(video);
            } else {
              // Fallback: treat entire item as video object if no nested 'video' key
              final video = VideoModel.fromJson(itemMap);
              videos.add(video);
            }
          } catch (e) {
            // Log error but continue parsing other videos
            print('⚠️ Error parsing video: $e');
            print('   Item: $item');
          }
        }

        return videos;
      }
    }

    // Fallback for old format: {"status": "success", "videos": [...]}
    if (json['status'] == 'success' || json['videos'] != null) {
      final videosJson = json['videos'] as List<dynamic>? ?? [];
      return videosJson
          .map(
            (videoJson) =>
                VideoModel.fromJson(videoJson as Map<String, dynamic>),
          )
          .toList();
    }

    throw Exception('Unexpected response format: ${json.keys}');
  }

  @override
  Future<VideoInfo> getVideoInfo(String videoId) async {
    // API endpoint: GET /videos/{videoID}
    // Authentication is optional - provides additional info if authenticated
    final response = await _apiClient.get(
      ApiConstants.getVideo(videoId),
      optionalAuth: true,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch video info: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // API returns: {"success": true, "data": {"video_url": "...", "upvoted": false, "downvoted": false, "following": false}}
    if (json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final videoUrlFromApi = data['video_url'] as String?;
        if (videoUrlFromApi != null && videoUrlFromApi.isNotEmpty) {
          return VideoInfo(
            videoUrl: videoUrlFromApi,
            upvoted: data['upvoted'] as bool? ?? false,
            downvoted: data['downvoted'] as bool? ?? false,
            following: data['following'] as bool? ?? false,
          );
        }
      }
    }

    // Fallback for old format: {"status": "success", "video_url": "..."}
    if (json['status'] == 'success') {
      final videoUrlFromApi = json['video_url'] as String?;
      if (videoUrlFromApi != null && videoUrlFromApi.isNotEmpty) {
        return VideoInfo(
          videoUrl: videoUrlFromApi,
          upvoted: false,
          downvoted: false,
          following: false,
        );
      }
    }

    // Fallback: try direct video_url field (shouldn't happen with new API)
    final videoUrlFromApi = json['video_url'] as String?;
    if (videoUrlFromApi != null && videoUrlFromApi.isNotEmpty) {
      return VideoInfo(
        videoUrl: videoUrlFromApi,
        upvoted: false,
        downvoted: false,
        following: false,
      );
    }

    throw Exception('Video URL not found in response: ${json.keys}');
  }

  @override
  Future<String> getVideoUrl(String videoId) async {
    // Deprecated: Use getVideoInfo instead
    final videoInfo = await getVideoInfo(videoId);
    return videoInfo.videoUrl;
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

    // API returns: {"success": true, "data": {"message": "Video upvoted"}}
    if (json['success'] != true) {
      final error = json['error'] as String? ?? 'Unknown error';
      throw Exception('Upvote failed: $error');
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

    // API returns: {"success": true, "data": {"message": "Video downvoted"}}
    if (json['success'] != true) {
      final error = json['error'] as String? ?? 'Unknown error';
      throw Exception('Downvote failed: $error');
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

    // API returns: {"success": true, "data": {"message": "Video commented"}}
    if (json['success'] != true) {
      final error = json['error'] as String? ?? 'Unknown error';
      throw Exception('Post comment failed: $error');
    }
  }

  @override
  Future<List<CommentModel>> getComments(
    String videoId, {
    required int page,
    required int limit,
  }) async {
    // Convert page to offset (offset = (page - 1) * limit)
    final offset = (page - 1) * limit;

    // Build query parameters
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final endpoint = '${ApiConstants.getComments(videoId)}?$queryString';

    // API: GET /social/videos/comments/{videoID}?limit=20&offset=0
    // Authentication is optional but recommended
    final response = await _apiClient.get(endpoint, optionalAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch comments: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // API returns: {"success": true, "data": {"comments": [...], "limit": 20, "offset": 0, "count": 150}}
    if (json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final commentsJson = data['comments'] as List<dynamic>? ?? [];
        return commentsJson
            .map(
              (commentJson) =>
                  CommentModel.fromJson(commentJson as Map<String, dynamic>),
            )
            .toList();
      }
    }

    // Fallback for old format
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

    // API returns: {"success": true, "data": {"message": "Reply added"}} or "Reply updated"
    if (json['success'] != true) {
      final error = json['error'] as String? ?? 'Unknown error';
      throw Exception('Post reply failed: $error');
    }
  }

  @override
  Future<List<ReplyModel>> getReplies(
    String commentId, {
    required int page,
    required int limit,
  }) async {
    // Convert page to offset (offset = (page - 1) * limit)
    final offset = (page - 1) * limit;

    // Build query parameters
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final endpoint = '${ApiConstants.getReplies(commentId)}?$queryString';

    // API: GET /social/videos/replies/{commentID}?limit=20&offset=0
    // Authentication is optional but recommended
    final response = await _apiClient.get(endpoint, optionalAuth: true);

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch replies: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    // API returns: {"success": true, "data": {"replies": [...], "limit": 20, "offset": 0, "count": 25}}
    if (json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final repliesJson = data['replies'] as List<dynamic>? ?? [];
        return repliesJson
            .map(
              (replyJson) =>
                  ReplyModel.fromJson(replyJson as Map<String, dynamic>),
            )
            .toList();
      }
    }

    // Fallback for old format
    final repliesJson = json['replies'] as List<dynamic>? ?? [];
    return repliesJson
        .map(
          (replyJson) => ReplyModel.fromJson(replyJson as Map<String, dynamic>),
        )
        .toList();
  }

  /// Generates a random alphanumeric seed for video pagination
  static String _generateRandomSeed() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(
        32, // 32 character seed
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
  }
}
