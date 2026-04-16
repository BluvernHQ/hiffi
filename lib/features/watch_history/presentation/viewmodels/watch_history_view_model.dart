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
  int _totalCount = 0;
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

      _totalCount = result.count;

      if (refresh) {
        _items = result.videos;
      } else {
        _items = [..._items, ...result.videos];
      }
      _items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));

      _offset += result.videos.length;
      // Full page ⇒ likely more pages. Only stop on short page, empty, or when count is
      // present and we've reached it (avoids breaking when API count is wrong or = page size).
      if (result.videos.isEmpty) {
        _hasMore = false;
      } else if (result.videos.length < _pageLimit) {
        _hasMore = false;
      } else {
        _hasMore = true;
        if (_totalCount > 0 && _offset >= _totalCount) {
          _hasMore = false;
        }
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
}
