import 'package:flutter/material.dart';

import '../../../video/domain/models/watch_history_item.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../../../core/exceptions/api_exception.dart';

class WatchHistoryViewModel extends ChangeNotifier {
  WatchHistoryViewModel({required VideoRepository videoRepository})
    : _videoRepository = videoRepository;

  final VideoRepository _videoRepository;

  List<WatchHistoryItem> _items = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _offset = 0;
  static const int _pageLimit = 20;
  bool _hasMore = true;
  bool _unauthorized = false;

  List<WatchHistoryItem> get items => List.unmodifiable(_items);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;
  bool get unauthorized => _unauthorized;

  Future<void> loadHistory({bool refresh = false}) async {
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
      final result = await _videoRepository.getWatchHistory(
        limit: _pageLimit,
        offset: _offset,
      );

      if (refresh) {
        _items = result.videos;
      } else {
        _mergeHistoryPage(result.videos);
      }
      _items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

      // Prefer server-provided next offset; otherwise advance by raw row count (not parsed length).
      if (result.serverNextOffset != null) {
        _offset = result.serverNextOffset!;
      } else {
        _offset += result.returnedSlotCount;
      }

      // Do not use `count` to stop: many APIs return page size or wrong totals and we would
      // never load older history. Only stop on an empty or short page from the API.
      final fullPage = result.returnedSlotCount >= _pageLimit;
      if (result.returnedSlotCount == 0) {
        _hasMore = false;
      } else if (!fullPage) {
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

  Future<void> refresh() => loadHistory(refresh: true);

  void clearUnauthorizedFlag() {
    if (_unauthorized) {
      _unauthorized = false;
      notifyListeners();
    }
  }

  void _mergeHistoryPage(List<WatchHistoryItem> page) {
    final seen = <String>{
      for (final e in _items) '${e.video.videoId}|${e.viewedAt.toIso8601String()}',
    };
    for (final e in page) {
      final k = '${e.video.videoId}|${e.viewedAt.toIso8601String()}';
      if (seen.add(k)) {
        _items.add(e);
      }
    }
  }
}
