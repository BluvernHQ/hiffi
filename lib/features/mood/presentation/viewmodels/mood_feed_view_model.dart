import 'package:flutter/foundation.dart';

import '../../../../core/services/mood_active_storage.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/services/playlist_session_storage.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../playlist/domain/models/playlist_models.dart';
import '../../../video/domain/models/video_model.dart';
import '../../data/mood_playlist_repository.dart';
import '../../domain/models/mood_def.dart';
import '../../domain/models/mood_feed_cache.dart';

class MoodFeedViewModel extends ChangeNotifier {
  MoodFeedViewModel({
    required MoodPlaylistRepository moodPlaylistRepository,
    NetworkConnectivityService? connectivityService,
  }) : _moodPlaylistRepository = moodPlaylistRepository,
       _connectivityService = connectivityService;

  final MoodPlaylistRepository _moodPlaylistRepository;
  final NetworkConnectivityService? _connectivityService;

  static const int videosPerPage = 10;

  String? _activeMoodQuery;
  bool _pickerOpen = true;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _moodEmpty = false;
  List<VideoModel> _videos = [];
  int _offset = 0;
  bool _hasMore = true;

  final Map<String, MoodFeedCache> _caches = {};

  String? get activeMoodQuery => _activeMoodQuery;
  bool get pickerOpen => _pickerOpen;
  bool get isMoodActive => _activeMoodQuery != null;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get errorMessage => _errorMessage;
  bool get moodEmpty => _moodEmpty;
  List<VideoModel> get videos => List.unmodifiable(_videos);
  bool get hasMore => _hasMore;

  MoodDef? get activeMood => moodByQuery(_activeMoodQuery);

  Future<void> restoreFromStorage() async {
    final stored = await MoodActiveStorage.read();
    if (stored == null || stored.isEmpty) return;
    await applyMood(stored, silent: true);
  }

  Future<void> applyMood(String query, {bool silent = false}) async {
    final mood = moodByQuery(query);
    if (mood == null) return;

    final previousMood = _activeMoodQuery;
    _snapshotCurrentFeed();

    _activeMoodQuery = mood.query;
    _pickerOpen = false;
    _errorMessage = null;
    _moodEmpty = false;

    final cached = _caches[mood.query];
    if (cached != null) {
      _videos = List<VideoModel>.from(cached.videos);
      _offset = cached.offset;
      _hasMore = cached.hasMore;
      _moodEmpty = cached.moodEmpty;
      await MoodActiveStorage.write(mood.query);
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      if (await isDeviceOffline(_connectivityService)) {
        _errorMessage = offlineUserMessage;
        _videos = [];
        _offset = 0;
        _hasMore = false;
        _moodEmpty = true;
        await MoodActiveStorage.write(mood.query);
        return;
      }

      await _fetchMoodPage(mood.vibe, refresh: true);
      await MoodActiveStorage.write(mood.query);
    } catch (error) {
      _errorMessage = userFriendlyErrorMessage(error);
      _revertMood(previousMood);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearActiveMood() async {
    if (_activeMoodQuery != null) {
      _snapshotCurrentFeed();
    }
    _activeMoodQuery = null;
    _pickerOpen = true;
    _videos = [];
    _offset = 0;
    _hasMore = true;
    _moodEmpty = false;
    _errorMessage = null;
    await MoodActiveStorage.write(null);
    notifyListeners();
  }

  Future<void> refreshActiveMood() async {
    final query = _activeMoodQuery;
    if (query == null) return;
    final mood = moodByQuery(query);
    if (mood == null) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (await isDeviceOffline(_connectivityService)) {
        _errorMessage = offlineUserMessage;
        return;
      }
      await _fetchMoodPage(mood.vibe, refresh: true);
    } catch (error) {
      _errorMessage = userFriendlyErrorMessage(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMore() async {
    final mood = activeMood;
    if (mood == null || _isLoading || _isLoadingMore || !_hasMore) return;
    if (await isDeviceOffline(_connectivityService)) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      await _fetchMoodPage(mood.vibe, refresh: false);
    } catch (error) {
      _errorMessage = userFriendlyErrorMessage(error);
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  PlaylistSession? buildSessionAt(int index) {
    final mood = activeMood;
    if (mood == null || _videos.isEmpty) return null;
    if (index < 0 || index >= _videos.length) return null;

    final session = PlaylistSession(
      playlistId: moodPlaylistId(mood.query),
      title: mood.label,
      videoIds: _videos.map((v) => v.videoId).toList(),
      currentIndex: index,
      autoplay: true,
    );
    return session.isValid ? session : null;
  }

  Future<void> persistSession(PlaylistSession session) async {
    await PlaylistSessionStorage().save(session);
  }

  void _snapshotCurrentFeed() {
    final query = _activeMoodQuery;
    if (query == null) return;
    _caches[query] = MoodFeedCache(
      videos: List<VideoModel>.from(_videos),
      offset: _offset,
      hasMore: _hasMore,
      moodEmpty: _moodEmpty,
    );
  }

  void _revertMood(String? previousMood) {
    _activeMoodQuery = previousMood;
    _pickerOpen = previousMood == null;
    if (previousMood == null) {
      _videos = [];
      _offset = 0;
      _hasMore = true;
      _moodEmpty = false;
      return;
    }

    final cached = _caches[previousMood];
    if (cached != null) {
      _videos = List<VideoModel>.from(cached.videos);
      _offset = cached.offset;
      _hasMore = cached.hasMore;
      _moodEmpty = cached.moodEmpty;
    }
  }

  Future<void> _fetchMoodPage(String vibe, {required bool refresh}) async {
    final requestOffset = refresh ? 0 : _offset;
    final page = await _moodPlaylistRepository.getMoodPlaylist(
      vibe,
      limit: videosPerPage,
      offset: requestOffset,
    );

    final merged = refresh
        ? page.videos
        : _mergeVideos(_videos, page.videos);

    _videos = merged;
    _offset = requestOffset + page.videos.length;
    _hasMore = page.videos.length >= videosPerPage;
    _moodEmpty = merged.isEmpty;

    final query = _activeMoodQuery;
    if (query != null) {
      _caches[query] = MoodFeedCache(
        videos: List<VideoModel>.from(_videos),
        offset: _offset,
        hasMore: _hasMore,
        moodEmpty: _moodEmpty,
      );
    }
  }

  List<VideoModel> _mergeVideos(
    List<VideoModel> existing,
    List<VideoModel> incoming,
  ) {
    final seen = existing.map((v) => v.videoId).toSet();
    final merged = List<VideoModel>.from(existing);
    for (final video in incoming) {
      if (!seen.contains(video.videoId)) {
        merged.add(video);
        seen.add(video.videoId);
      }
    }
    return merged;
  }
}
