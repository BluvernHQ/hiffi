import 'package:flutter/material.dart';

import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';

class VideoViewModel extends ChangeNotifier {
  VideoViewModel({required VideoRepository videoRepository})
    : _videoRepository = videoRepository;

  final VideoRepository _videoRepository;

  List<VideoModel> _videos = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentPage = 1;
  static const int _pageLimit = 10;
  bool _hasMore = true;

  List<VideoModel> get videos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> loadVideos({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _videos = [];
    }

    if (!_hasMore) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newVideos = await _videoRepository.getVideos(
        page: _currentPage,
        limit: _pageLimit,
      );

      if (refresh) {
        _videos = newVideos;
      } else {
        _videos.addAll(newVideos);
      }

      _hasMore = newVideos.length >= _pageLimit;
      _currentPage++;

      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadVideos(refresh: true);
}
