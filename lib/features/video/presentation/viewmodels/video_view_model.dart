import 'dart:math';

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
  String? _searchQuery;
  String? _currentSeed; // Seed for current pagination session

  List<VideoModel> get videos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  String? get searchQuery => _searchQuery;

  Future<void> loadVideos({bool refresh = false, String? searchQuery}) async {
    if (_isLoading) return;

    // If search query changed, reset pagination
    if (searchQuery != _searchQuery) {
      refresh = true;
      _searchQuery = searchQuery;
    }

    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      _videos = [];
      // Generate new random seed on refresh
      _currentSeed = _generateRandomSeed();
    }

    if (!_hasMore) return;

    // Generate seed if not already set (first load)
    if (_currentSeed == null) {
      _currentSeed = _generateRandomSeed();
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final newVideos = await _videoRepository.getVideos(
        page: _currentPage,
        limit: _pageLimit,
        searchQuery: _searchQuery,
        seed: _currentSeed, // Use same seed for pagination, new seed on refresh
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

  Future<void> refresh() =>
      loadVideos(refresh: true, searchQuery: _searchQuery);

  Future<void> search(String query) {
    if (query.trim().isEmpty) {
      // Clear search and load all videos
      _searchQuery = null;
      return refresh();
    }
    return loadVideos(refresh: true, searchQuery: query);
  }

  void clearSearch() {
    _searchQuery = null;
    refresh();
  }

  /// Generates a random alphanumeric seed for video pagination
  String _generateRandomSeed() {
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
