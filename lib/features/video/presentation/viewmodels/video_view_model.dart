import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/services/network_connectivity_service.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';

class VideoViewModel extends ChangeNotifier {
  VideoViewModel({
    required VideoRepository videoRepository,
    NetworkConnectivityService? connectivityService,
  }) : _videoRepository = videoRepository,
       _connectivityService = connectivityService;

  final VideoRepository _videoRepository;
  final NetworkConnectivityService? _connectivityService;

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

    // Check for internet connectivity before making the call
    if (_connectivityService != null && !_connectivityService.isConnected) {
      _errorMessage = 'No internet connection';
      notifyListeners();
      return;
    }

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

  Future<void> deleteVideo(String videoId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _videoRepository.deleteVideo(videoId);
      // Remove from local list if present
      _videos.removeWhere((v) => v.videoId == videoId);
      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the view count for a specific video in the list
  /// This is called when a video view is registered (e.g., when user watches a video)
  /// Only updates if the new view count is greater than the current one to prevent duplicates
  void updateVideoViewCount(String videoId, int newViewCount) {
    final index = _videos.indexWhere((v) => v.videoId == videoId);
    if (index != -1) {
      final currentVideo = _videos[index];
      // Only update if the new count is greater (prevents duplicate increments)
      // This ensures we don't accidentally decrease the count or update with stale data
      if (newViewCount > currentVideo.videoViews) {
        _videos[index] = currentVideo.copyWith(videoViews: newViewCount);
        notifyListeners();
      }
    }
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
