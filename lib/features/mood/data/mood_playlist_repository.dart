import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/services/api_client.dart';
import '../../playlist/domain/models/playlist_models.dart';
import '../../video/domain/models/video_model.dart';

class MoodPlaylistPage {
  const MoodPlaylistPage({
    required this.detail,
    required this.count,
    required this.limit,
    required this.offset,
    required this.videos,
  });

  final PlaylistDetail detail;
  final int count;
  final int limit;
  final int offset;
  final List<VideoModel> videos;
}

abstract class MoodPlaylistRepository {
  Future<MoodPlaylistPage> getMoodPlaylist(
    String vibe, {
    int limit = 10,
    int offset = 0,
  });
}

class MoodPlaylistRepositoryImpl implements MoodPlaylistRepository {
  MoodPlaylistRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  @override
  Future<MoodPlaylistPage> getMoodPlaylist(
    String vibe, {
    int limit = 10,
    int offset = 0,
  }) async {
    final trimmed = vibe.trim();
    if (trimmed.isEmpty) {
      throw ApiException('Mood query is missing', 400);
    }

    final response = await _apiClient.get(
      ApiConstants.moodPlaylist(trimmed, limit: limit, offset: offset),
      requiresAuth: false,
    );

    if (response.statusCode == 400) {
      throw ApiException('Mood query is missing or invalid.', 400);
    }
    if (response.statusCode != 200) {
      throw ApiException(
        _errorMessage(response.body) ?? 'Failed to load mood playlist',
        response.statusCode,
      );
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (payload['success'] != true || payload['data'] == null) {
      throw ApiException(
        _errorMessage(response.body) ?? 'Failed to load mood playlist',
        response.statusCode,
      );
    }

    final data = payload['data'] as Map<String, dynamic>;
    final detail = PlaylistDetail.fromPlaylistGetData(data);
    final videos = _videosFromItems(data['items'], detail.items);
    final returnedCount = videos.length;

    return MoodPlaylistPage(
      detail: detail,
      count: (data['count'] as num?)?.toInt() ?? returnedCount,
      limit: (data['limit'] as num?)?.toInt() ?? limit,
      offset: (data['offset'] as num?)?.toInt() ?? offset,
      videos: videos,
    );
  }

  List<VideoModel> _videosFromItems(
    dynamic rawItems,
    List<PlaylistItem> fallbackItems,
  ) {
    final videos = <VideoModel>[];
    if (rawItems is List<dynamic>) {
      for (final entry in rawItems) {
        if (entry is! Map<String, dynamic>) continue;
        final nested = entry['video'];
        if (nested is Map<String, dynamic>) {
          final video = _parseVideo(nested);
          if (video != null) videos.add(video);
          continue;
        }
        final item = PlaylistItem.fromJson(entry);
        final video = _videoFromItem(item);
        if (video != null) videos.add(video);
      }
    }
    if (videos.isNotEmpty) return videos;

    for (final item in fallbackItems) {
      final video = _videoFromItem(item);
      if (video != null) videos.add(video);
    }
    return videos;
  }

  VideoModel? _parseVideo(Map<String, dynamic> json) {
    final videoId = json['video_id'] as String? ?? '';
    if (videoId.isEmpty || json['video_title'] == null) return null;

    final enriched = Map<String, dynamic>.from(json);
    enriched['video_url'] = json['video_url'] ?? 'videos/$videoId';
    enriched['video_thumbnail'] =
        json['video_thumbnail'] ?? 'thumbnails/videos/$videoId.jpg';
    enriched['user_uid'] = json['user_uid'] ?? '';
    enriched['user_username'] = json['user_username'] ?? '';
    enriched['created_at'] =
        json['created_at'] ?? DateTime.now().toIso8601String();
    enriched['updated_at'] =
        json['updated_at'] ?? DateTime.now().toIso8601String();

    return VideoModel.fromJson(enriched);
  }

  VideoModel? _videoFromItem(PlaylistItem item) {
    if (item.videoId.isEmpty) return null;
    return VideoModel.preview(
      videoId: item.videoId,
      title: item.videoTitle ?? '',
      thumbnail: item.videoThumbnail ?? '',
    );
  }

  String? _errorMessage(String body) {
    if (body.isEmpty) return null;
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      final error = payload['error'];
      if (error is Map<String, dynamic>) {
        return error['message']?.toString();
      }
      return error?.toString() ?? payload['message']?.toString();
    } catch (_) {
      return null;
    }
  }
}
