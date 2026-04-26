import 'package:flutter/material.dart';

import '../../../video/domain/models/liked_video_item.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../../../core/exceptions/api_exception.dart';

class LikedVideosViewModel extends ChangeNotifier {
  LikedVideosViewModel({required VideoRepository videoRepository})
    : _videoRepository = videoRepository;

  final VideoRepository _videoRepository;

  List<LikedVideoItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _offset = 0;
  static const int _pageLimit = 20;
  bool _hasMore = true;
  bool _unauthorized = false;

  List<LikedVideoItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get unauthorized => _unauthorized;

  Future<void> loadVideos({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _offset = 0;
      _hasMore = true;
      _items = [];
      _unauthorized = false;
    }

    if (!_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _videoRepository.getLikedVideos(
        limit: _pageLimit,
        offset: _offset,
      );

      final incomingById = <String, LikedVideoItem>{};
      for (final row in result.videos) {
        incomingById[row.video.videoId] = row;
      }

      if (refresh) {
        _items = incomingById.values.toList();
      } else {
        final mergedById = <String, LikedVideoItem>{
          for (final row in _items) row.video.videoId: row,
          ...incomingById,
        };
        _items = mergedById.values.toList();
      }
      _items.sort((a, b) => b.upvotedAt.compareTo(a.upvotedAt));

      _offset += result.returnedSlotCount;
      final fullPage = result.returnedSlotCount >= _pageLimit;
      if (result.returnedSlotCount == 0 || !fullPage) {
        _hasMore = false;
      } else {
        _hasMore = true;
      }

      _errorMessage = null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        _unauthorized = true;
        _errorMessage = null;
      } else {
        _errorMessage = e.toString();
      }
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadVideos(refresh: true);

  void applyLikeState({
    required String videoId,
    required bool isLiked,
    DateTime? likedAt,
    VideoModel? likedVideo,
  }) {
    final index = _items.indexWhere((row) => row.video.videoId == videoId);
    if (isLiked) {
      if (index == -1) {
        if (likedVideo == null) return;
        _items.add(
          LikedVideoItem(
            video: likedVideo.copyWith(userVoteStatus: 'upvoted'),
            upvotedAt: likedAt ?? DateTime.now(),
          ),
        );
      } else {
        final existing = _items[index];
        final updatedVideo = existing.video.copyWith(userVoteStatus: 'upvoted');
        _items[index] = LikedVideoItem(
          video: updatedVideo,
          upvotedAt: likedAt ?? existing.upvotedAt,
        );
      }
      _items.sort((a, b) => b.upvotedAt.compareTo(a.upvotedAt));
    } else if (index != -1) {
      _items.removeAt(index);
    } else {
      return;
    }
    notifyListeners();
  }

  void clearUnauthorizedFlag() {
    if (_unauthorized) {
      _unauthorized = false;
      notifyListeners();
    }
  }
}
