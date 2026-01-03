import 'dart:math';

import 'package:flutter/material.dart';

import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';

class FollowingViewModel extends ChangeNotifier {
  FollowingViewModel({required VideoRepository videoRepository})
    : _videoRepository = videoRepository;

  final VideoRepository _videoRepository;

  List<VideoModel> _videos = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _currentOffset = 0;
  static const int _pageLimit = 10;
  bool _hasMore = true;
  String? _currentSeed; // Seed for current pagination session

  List<VideoModel> get videos => List.unmodifiable(_videos);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  Future<void> loadVideos({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      _currentOffset = 0;
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
      final newVideos = await _videoRepository.getFollowingVideos(
        limit: _pageLimit,
        offset: _currentOffset,
        seed: _currentSeed, // Use same seed for pagination, new seed on refresh
      );

      if (refresh) {
        _videos = newVideos;
      } else {
        _videos.addAll(newVideos);
      }

      _hasMore = newVideos.length >= _pageLimit;
      _currentOffset += newVideos.length;

      _errorMessage = null;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => loadVideos(refresh: true);

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
