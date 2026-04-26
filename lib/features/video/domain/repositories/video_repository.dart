import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/api_client.dart';
import '../models/comment_model.dart';
import '../models/liked_video_item.dart';
import '../models/video_model.dart';
import '../models/watch_history_item.dart';

/// Response model for video info including URL and user interaction status
class VideoInfo {
  final String videoUrl;
  final bool upvoted;
  final bool downvoted;
  final bool following;
  final String? profilePicture;
  final VideoModel? video; // Full video object if available

  VideoInfo({
    required this.videoUrl,
    required this.upvoted,
    required this.downvoted,
    required this.following,
    this.profilePicture,
    this.video,
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
  Future<List<VideoModel>> getFollowingVideos({
    required int limit,
    required int offset,
    String? seed,
  });
  Future<LikedVideosResult> getLikedVideos({
    required int limit,
    required int offset,
  });
  Future<WatchHistoryResult> getWatchHistory({
    required int limit,
    required int offset,
  });
  Future<List<VideoModel>> getVideosByUsername({
    required String username,
    required int limit,
    required int offset,
  });
  Future<VideoInfo> getVideoInfo(String videoId);
  Future<String> getVideoUrl(
    String videoId,
  ); // Deprecated: use getVideoInfo instead
  Future<void> upvoteVideo(String videoId);
  Future<void> downvoteVideo(String videoId);
  Future<String?> getUserVoteStatus(String videoId);
  Future<void> postComment(String videoId, String comment);
  Future<CommentsResponse> getComments(
    String videoId, {
    required int page,
    required int limit,
  });
  Future<void> postReply(String commentId, String reply);
  Future<RepliesResponse> getReplies(
    String commentId, {
    required int page,
    required int limit,
  });
  Future<void> deleteVideo(String videoId);
  Future<void> deleteComment(String commentId);
  Future<void> deleteReply(String replyId);

  /// POST `/signals/watchhours` — best-effort; failures are swallowed.
  Future<void> postWatchHoursSignal({
    required String videoId,
    required double positionSeconds,
    required double durationSeconds,
    required double playbackRate,
    String? deviceId,
    String? sessionId,
    String? player,
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
    // API uses GET with query parameters: limit, offset, seed, search
    // Convert page to offset (offset = (page - 1) * limit)
    final offset = (page - 1) * limit;

    // Build query parameters
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    // Add search query if provided
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      queryParams['search'] = searchQuery.trim();
    }

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
              // Extract profile_picture and status from outer item (not from video object)
              final profilePicture =
                  itemMap['profile_picture'] as String? ??
                  itemMap['profilePicture'] as String? ??
                  itemMap['avatar_url'] as String? ??
                  itemMap['avatarUrl'] as String?;
              final status = itemMap['status'] as String?;

              // Add extra fields to videoJson before parsing
              final videoJsonWithExtras = Map<String, dynamic>.from(videoJson);
              if (profilePicture != null) {
                videoJsonWithExtras['profile_picture'] = profilePicture;
              }
              if (status != null) {
                videoJsonWithExtras['status'] = status;
              }

              final video = VideoModel.fromJson(videoJsonWithExtras);
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
              // Extract profile_picture and status from outer item (not from video object)
              final profilePicture =
                  itemMap['profile_picture'] as String? ??
                  itemMap['profilePicture'] as String? ??
                  itemMap['avatar_url'] as String? ??
                  itemMap['avatarUrl'] as String?;
              final status = itemMap['status'] as String?;
              final userUsername =
                  itemMap['user_username'] as String? ??
                  itemMap['username'] as String?;

              // Add extra fields to videoJson before parsing
              final videoJsonWithExtras = Map<String, dynamic>.from(videoJson);
              if (profilePicture != null && profilePicture.isNotEmpty) {
                videoJsonWithExtras['profile_picture'] = profilePicture;
              }
              if (status != null) {
                videoJsonWithExtras['status'] = status;
              }
              if (userUsername != null) {
                videoJsonWithExtras['user_username'] = userUsername;
              }

              final video = VideoModel.fromJson(videoJsonWithExtras);
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
  Future<List<VideoModel>> getFollowingVideos({
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

    final endpoint = '${ApiConstants.videoListFollowing}?$queryString';

    // Authentication is required for /videos/list/following
    final response = await _apiClient.get(endpoint, requiresAuth: true);

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch following videos: ${response.statusCode}',
      );
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
              // Extract profile_picture and status from outer item (not from video object)
              final profilePicture =
                  itemMap['profile_picture'] as String? ??
                  itemMap['profilePicture'] as String? ??
                  itemMap['avatar_url'] as String? ??
                  itemMap['avatarUrl'] as String?;
              final status = itemMap['status'] as String?;
              final userUsername =
                  itemMap['user_username'] as String? ??
                  itemMap['username'] as String?;

              // Add extra fields to videoJson before parsing
              final videoJsonWithExtras = Map<String, dynamic>.from(videoJson);
              if (profilePicture != null && profilePicture.isNotEmpty) {
                videoJsonWithExtras['profile_picture'] = profilePicture;
              }
              if (status != null) {
                videoJsonWithExtras['status'] = status;
              }
              if (userUsername != null) {
                videoJsonWithExtras['user_username'] = userUsername;
              }

              final video = VideoModel.fromJson(videoJsonWithExtras);
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
  Future<LikedVideosResult> getLikedVideos({
    required int limit,
    required int offset,
  }) async {
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

    final endpoint = '${ApiConstants.videoListLiked}?$queryString';
    print(
      '❤️ Liked videos request: GET ${ApiConstants.baseUrl}$endpoint '
      '(limit=$limit, offset=$offset)',
    );
    final response = await _apiClient.get(endpoint, requiresAuth: true);

    if (response.statusCode == 401) {
      throw ApiException(
        'Session expired. Please sign in again.',
        401,
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch liked videos: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json['success'] != true) {
      final message =
          json['error'] as String? ??
          json['message'] as String? ??
          'Failed to load liked videos';
      throw Exception(message);
    }

    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Unexpected response: missing data');
    }

    final totalCount = (data['count'] as num?)?.toInt() ?? 0;
    final dataLimit = (data['limit'] as num?)?.toInt() ?? limit;
    final dataOffset = (data['offset'] as num?)?.toInt() ?? offset;
    final videosJson = data['videos'] as List<dynamic>? ?? [];
    final items = <LikedVideoItem>[];
    final seenVideoIds = <String>{};

    for (final raw in videosJson) {
      try {
        final itemMap = raw as Map<String, dynamic>;
        final videoJson = itemMap['video'] as Map<String, dynamic>?;
        if (videoJson == null) continue;

        final profilePicture =
            itemMap['profile_picture'] as String? ??
            itemMap['profilePicture'] as String? ??
            itemMap['avatar_url'] as String? ??
            itemMap['avatarUrl'] as String?;
        final status = itemMap['status'] as String?;
        final userUsername =
            itemMap['user_username'] as String? ??
            itemMap['username'] as String?;

        final videoJsonWithExtras = Map<String, dynamic>.from(videoJson);
        if (profilePicture != null && profilePicture.isNotEmpty) {
          videoJsonWithExtras['profile_picture'] = profilePicture;
        }
        if (status != null) {
          videoJsonWithExtras['status'] = status;
        }
        if (userUsername != null) {
          videoJsonWithExtras['user_username'] = userUsername;
        }

        // Liked list contract: each row is effectively upvoted for this user.
        videoJsonWithExtras['upvoted'] = true;
        videoJsonWithExtras['downvoted'] = false;
        videoJsonWithExtras['user_vote_status'] = 'upvoted';
        final video = VideoModel.fromJson(videoJsonWithExtras);
        if (seenVideoIds.contains(video.videoId)) {
          continue;
        }
        seenVideoIds.add(video.videoId);
        final upvotedAtStr =
            itemMap['upvoted_at'] as String? ??
            itemMap['upvotedAt'] as String?;
        final upvotedAt = upvotedAtStr != null
            ? DateTime.parse(upvotedAtStr)
            : video.updatedAt;

        items.add(LikedVideoItem(video: video, upvotedAt: upvotedAt));
      } catch (e) {
        print('⚠️ Error parsing liked video: $e');
      }
    }

    return LikedVideosResult(
      count: totalCount,
      limit: dataLimit,
      offset: dataOffset,
      videos: items,
      returnedSlotCount: videosJson.length,
    );
  }

  @override
  Future<WatchHistoryResult> getWatchHistory({
    required int limit,
    required int offset,
  }) async {
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

    final endpoint = '${ApiConstants.videoListHistory}?$queryString';
    final response = await _apiClient.get(endpoint, requiresAuth: true);

    if (response.statusCode == 401) {
      throw ApiException(
        'Session expired. Please sign in again.',
        401,
      );
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Failed to fetch watch history: ${response.statusCode}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (json['success'] != true) {
      final message =
          json['error'] as String? ??
          json['message'] as String? ??
          'Failed to load watch history';
      throw Exception(message);
    }

    final data = json['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Unexpected response: missing data');
    }

    final totalCount = (data['count'] as num?)?.toInt() ?? 0;
    final dataLimit = (data['limit'] as num?)?.toInt() ?? limit;
    final dataOffset = (data['offset'] as num?)?.toInt() ?? offset;
    final videosJson = data['videos'] as List<dynamic>? ?? [];
    final items = <WatchHistoryItem>[];

    int? nextOffsetFromApi;
    for (final key in [
      'next_offset',
      'nextOffset',
      'next_skip',
      'nextSkip',
    ]) {
      final v = data[key];
      if (v is int) {
        nextOffsetFromApi = v;
        break;
      }
      if (v is num) {
        nextOffsetFromApi = v.toInt();
        break;
      }
    }

    for (final raw in videosJson) {
      try {
        final itemMap = raw as Map<String, dynamic>;
        final videoJson = itemMap['video'] as Map<String, dynamic>?;
        if (videoJson == null) continue;

        final profilePicture =
            itemMap['profile_picture'] as String? ??
            itemMap['profilePicture'] as String? ??
            itemMap['avatar_url'] as String? ??
            itemMap['avatarUrl'] as String?;
        final status = itemMap['status'] as String?;
        final userUsername =
            itemMap['user_username'] as String? ??
            itemMap['username'] as String?;

        final videoJsonWithExtras = Map<String, dynamic>.from(videoJson);
        if (profilePicture != null && profilePicture.isNotEmpty) {
          videoJsonWithExtras['profile_picture'] = profilePicture;
        }
        if (status != null) {
          videoJsonWithExtras['status'] = status;
        }
        if (userUsername != null) {
          videoJsonWithExtras['user_username'] = userUsername;
        }

        final video = VideoModel.fromJson(videoJsonWithExtras);
        final viewedAtStr =
            itemMap['viewed_at'] as String? ??
            itemMap['viewedAt'] as String?;
        final lastSeenUnix = itemMap['last_seen_unix'];
        final DateTime viewedAt;
        if (viewedAtStr != null) {
          viewedAt = DateTime.parse(viewedAtStr);
        } else if (lastSeenUnix is int) {
          viewedAt = DateTime.fromMillisecondsSinceEpoch(
            lastSeenUnix * 1000,
            isUtc: true,
          );
        } else if (lastSeenUnix is num) {
          viewedAt = DateTime.fromMillisecondsSinceEpoch(
            lastSeenUnix.toInt() * 1000,
            isUtc: true,
          );
        } else {
          viewedAt = video.updatedAt;
        }

        final posRaw = itemMap['position_seconds'];
        final double? positionSeconds = posRaw is num ? posRaw.toDouble() : null;

        items.add(
          WatchHistoryItem(
            video: video,
            viewedAt: viewedAt,
            positionSeconds: positionSeconds,
          ),
        );
      } catch (e) {
        print('⚠️ Error parsing watch history item: $e');
      }
    }

    return WatchHistoryResult(
      count: totalCount,
      limit: dataLimit,
      offset: dataOffset,
      videos: items,
      returnedSlotCount: videosJson.length,
      serverNextOffset: nextOffsetFromApi,
    );
  }

  @override
  Future<List<VideoModel>> getVideosByUsername({
    required String username,
    required int limit,
    required int offset,
  }) async {
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

    final endpoint =
        '${ApiConstants.listVideosByUsername(username)}?$queryString';

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
              // Extract profile_picture and status from outer item (not from video object)
              final profilePicture =
                  itemMap['profile_picture'] as String? ??
                  itemMap['profilePicture'] as String? ??
                  itemMap['avatar_url'] as String? ??
                  itemMap['avatarUrl'] as String?;
              final status = itemMap['status'] as String?;
              final userUsername =
                  itemMap['user_username'] as String? ??
                  itemMap['username'] as String?;

              // Add extra fields to videoJson before parsing
              final videoJsonWithExtras = Map<String, dynamic>.from(videoJson);
              if (profilePicture != null && profilePicture.isNotEmpty) {
                videoJsonWithExtras['profile_picture'] = profilePicture;
              }
              if (status != null) {
                videoJsonWithExtras['status'] = status;
              }
              if (userUsername != null) {
                videoJsonWithExtras['user_username'] = userUsername;
              }

              final video = VideoModel.fromJson(videoJsonWithExtras);
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

    // New API format: {"success": true, "data": {"video_url": "...", "upvoted": false, "downvoted": false, "following": false, "profile_picture": "", "video": {...}}}
    if (json['success'] == true) {
      final data = json['data'] as Map<String, dynamic>?;
      if (data != null) {
        final videoUrlFromApi = data['video_url'] as String?;
        if (videoUrlFromApi != null && videoUrlFromApi.isNotEmpty) {
          // Parse the nested video object if available
          VideoModel? videoModel;
          final videoJson = data['video'] as Map<String, dynamic>?;
          if (videoJson != null) {
            try {
              // Merge profile_picture and status from data level into video object for VideoModel
              final videoData = Map<String, dynamic>.from(videoJson);
              final profilePicture =
                  data['profile_picture'] as String? ??
                  data['profilePicture'] as String? ??
                  data['avatar_url'] as String? ??
                  data['avatarUrl'] as String?;
              if (profilePicture != null) {
                videoData['profile_picture'] = profilePicture;
              }
              if (data['status'] != null) {
                videoData['status'] = data['status'];
              }
              videoModel = VideoModel.fromJson(videoData);
            } catch (e) {
              // If parsing fails, continue without video object
              // This maintains backward compatibility
            }
          }

          final bool upvoted =
              data['upvoted'] as bool? ??
              videoJson?['upvoted'] as bool? ??
              false;
          final bool downvoted =
              data['downvoted'] as bool? ??
              videoJson?['downvoted'] as bool? ??
              false;

          return VideoInfo(
            videoUrl: videoUrlFromApi,
            upvoted: upvoted,
            downvoted: downvoted,
            following: data['following'] as bool? ?? false,
            profilePicture:
                data['profile_picture'] as String? ??
                data['profilePicture'] as String? ??
                data['avatar_url'] as String? ??
                data['avatarUrl'] as String?,
            video: videoModel,
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
          profilePicture: null,
          video: null,
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
        profilePicture: null,
        video: null,
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
    var response = await _apiClient.post(
      ApiConstants.upvoteVideo(videoId),
      {},
      requiresAuth: true,
    );

    // Some backend environments still expose legacy /social endpoints.
    if (response.statusCode == 404) {
      response = await _apiClient.post(
        ApiConstants.upvoteVideoLegacy(videoId),
        {},
        requiresAuth: true,
      );
    }

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
    var response = await _apiClient.post(
      ApiConstants.downvoteVideo(videoId),
      {},
      requiresAuth: true,
    );

    // Some backend environments still expose legacy /social endpoints.
    if (response.statusCode == 404) {
      response = await _apiClient.post(
        ApiConstants.downvoteVideoLegacy(videoId),
        {},
        requiresAuth: true,
      );
    }

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
  Future<CommentsResponse> getComments(
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
    return CommentsResponse.fromJson(json);
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
  Future<RepliesResponse> getReplies(
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

    return RepliesResponse.fromJson(json);
  }

  @override
  Future<void> deleteVideo(String videoId) async {
    final response = await _apiClient.delete(
      ApiConstants.deleteVideo(videoId),
      requiresAuth: true,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete video: ${response.statusCode}');
    }

    final responseBody = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;
    if (responseBody != null && responseBody['success'] == false) {
      final error = responseBody['error'] as String? ?? 'Unknown error';
      throw Exception('Delete video failed: $error');
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    final response = await _apiClient.delete(
      ApiConstants.deleteComment(commentId),
      requiresAuth: true,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete comment: ${response.statusCode}');
    }

    final responseBody = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;
    if (responseBody != null && responseBody['success'] == false) {
      final error = responseBody['error'] as String? ?? 'Unknown error';
      throw Exception('Delete comment failed: $error');
    }
  }

  @override
  Future<void> deleteReply(String replyId) async {
    final response = await _apiClient.delete(
      ApiConstants.deleteReply(replyId),
      requiresAuth: true,
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete reply: ${response.statusCode}');
    }

    final responseBody = response.body.isNotEmpty
        ? jsonDecode(response.body)
        : null;
    if (responseBody != null && responseBody['success'] == false) {
      final error = responseBody['error'] as String? ?? 'Unknown error';
      throw Exception('Delete reply failed: $error');
    }
  }

  @override
  Future<void> postWatchHoursSignal({
    required String videoId,
    required double positionSeconds,
    required double durationSeconds,
    required double playbackRate,
    String? deviceId,
    String? sessionId,
    String? player,
  }) async {
    try {
      final body = <String, dynamic>{
        'video_id': videoId,
        'position_seconds': positionSeconds,
        'duration_seconds': durationSeconds,
        'playback_rate': playbackRate,
        'client_timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      };
      if (deviceId != null && deviceId.isNotEmpty) {
        body['device_id'] = deviceId;
      }
      if (sessionId != null && sessionId.isNotEmpty) {
        body['session_id'] = sessionId;
      }
      if (player != null && player.isNotEmpty) {
        body['player'] = player;
      }

      final response = await _apiClient.post(
        ApiConstants.signalsWatchhours,
        body,
        requiresAuth: true,
      );
      if (response.statusCode != 200 && response.statusCode != 204) {
        developer.log(
          'watchhours signal HTTP ${response.statusCode}',
          name: 'hiffi.signals',
        );
      }
    } on NoInternetException {
      // Expected when offline; do not log as error.
    } catch (e, st) {
      developer.log(
        'watchhours signal skipped: $e',
        name: 'hiffi.signals',
        error: e,
        stackTrace: st,
      );
    }
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
