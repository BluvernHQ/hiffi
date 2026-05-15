import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../data/playlist_repository.dart';
import '../../domain/models/playlist_models.dart';

class PlaylistViewModel extends ChangeNotifier {
  PlaylistViewModel({
    required PlaylistRepository playlistRepository,
    required VideoRepository videoRepository,
    NetworkConnectivityService? connectivityService,
  }) : _playlistRepository = playlistRepository,
       _videoRepository = videoRepository,
       _connectivityService = connectivityService;

  final PlaylistRepository _playlistRepository;
  final VideoRepository _videoRepository;
  final NetworkConnectivityService? _connectivityService;

  List<PlaylistSummary> _playlists = [];
  List<PlaylistSummary> _curatedPlaylists = [];
  final Map<String, PlaylistDetail> _details = {};
  final Map<String, PlaylistDetail> _curatedDetails = {};
  final Map<String, VideoModel> _videoCache = {};
  bool _isLoadingList = false;
  bool _isLoadingCurated = false;
  DateTime? _curatedLastFetchedAt;
  String? _listError;
  String? _curatedError;
  final Set<String> _removingItems = <String>{};
  final Set<String> _addingToPlaylist = <String>{};
  bool _creating = false;
  bool _deleting = false;
  Timer? _searchDebounce;

  List<PlaylistSummary> get playlists => List.unmodifiable(_playlists);
  List<PlaylistSummary> get curatedPlaylists =>
      List.unmodifiable(_curatedPlaylists);
  bool get isLoadingList => _isLoadingList;
  bool get isLoadingCurated => _isLoadingCurated;
  DateTime? get curatedLastFetchedAt => _curatedLastFetchedAt;
  String? get listError => _listError;
  String? get curatedError => _curatedError;
  bool get isCreating => _creating;
  bool get isDeleting => _deleting;

  bool isRemovingItem(String playlistId, String videoId) =>
      _removingItems.contains('$playlistId:$videoId');
  bool isAddingToPlaylist(String playlistId) =>
      _addingToPlaylist.contains(playlistId);

  PlaylistDetail? detail(String playlistId) => _details[playlistId];
  PlaylistDetail? curatedDetail(String playlistId) =>
      _curatedDetails[playlistId];
  VideoModel? cachedVideo(String videoId) => _videoCache[videoId];

  Future<void> _requireConnection() async {
    final connectivity = _connectivityService;
    if (connectivity == null) return;
    await connectivity.ensureInitialized();
    if (!connectivity.isConnected) {
      throw NoInternetException();
    }
  }

  Future<void> loadPlaylists() async {
    _isLoadingList = true;
    _listError = null;
    notifyListeners();
    try {
      final connectivity = _connectivityService;
      if (connectivity != null) {
        await connectivity.ensureInitialized();
        if (!connectivity.isConnected) {
          _listError = offlineUserMessage;
          return;
        }
      }
      _playlists = await _playlistRepository.getSelfPlaylists();
      for (final playlist in _playlists) {
        unawaited(loadPlaylistDetail(playlist.playlistId, silent: true));
      }
    } catch (e) {
      _listError = isOfflineError(e) ? offlineUserMessage : e.toString();
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  Future<void> loadCuratedPlaylists({
    bool silent = false,
    bool force = false,
  }) async {
    if (_isLoadingCurated) return;
    if (!force && !isCuratedStale()) return;
    _isLoadingCurated = true;
    _curatedError = null;
    if (!silent) notifyListeners();
    try {
      final curated = await _playlistRepository.getCuratedPlaylists();
      _curatedPlaylists = curated;
      _curatedLastFetchedAt = DateTime.now();
      for (final playlist in curated.take(6)) {
        unawaited(loadCuratedPlaylistDetail(playlist.playlistId, silent: true));
      }
    } catch (e) {
      _curatedError = e.toString();
    } finally {
      _isLoadingCurated = false;
      notifyListeners();
    }
  }

  bool isCuratedStale({Duration ttl = const Duration(seconds: 90)}) {
    final lastFetched = _curatedLastFetchedAt;
    if (lastFetched == null) return true;
    return DateTime.now().difference(lastFetched) > ttl;
  }

  Future<PlaylistDetail?> loadPlaylistDetail(
    String playlistId, {
    bool silent = false,
  }) async {
    if (!silent) notifyListeners();
    try {
      await _requireConnection();
      final detail = await _playlistRepository.getPlaylist(playlistId);
      _details[playlistId] = detail;
      _upsertSummary(
        PlaylistSummary(
          playlistId: detail.playlistId,
          title: detail.title,
          description: detail.description,
          itemCount: detail.itemCount,
          updatedAt: detail.updatedAt,
          createdAt: detail.createdAt,
        ),
      );
      await _primeVideoMetadata(detail.items.map((e) => e.videoId).take(12));
      notifyListeners();
      return detail;
    } catch (_) {
      rethrow;
    }
  }

  Future<PlaylistDetail?> loadCuratedPlaylistDetail(
    String playlistId, {
    bool silent = false,
  }) async {
    if (!silent) notifyListeners();
    try {
      final detail = await _playlistRepository.getCuratedPlaylist(playlistId);
      _curatedDetails[playlistId] = detail;
      await _primeVideoMetadata(detail.items.map((e) => e.videoId).take(12));
      notifyListeners();
      return detail;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> _primeVideoMetadata(Iterable<String> videoIds) async {
    final ids = videoIds.where((e) => !_videoCache.containsKey(e)).toList();
    for (final id in ids) {
      try {
        final info = await _videoRepository.getVideoInfo(id);
        if (info.video != null) {
          _videoCache[id] = info.video!;
        }
      } catch (_) {}
    }
  }

  Future<PlaylistDetail> createPlaylist({
    required String title,
    String? description,
    required String videoId,
  }) async {
    _creating = true;
    notifyListeners();
    try {
      await _requireConnection();
      final detail = await _playlistRepository.createPlaylist(
        title: title,
        description: description,
        videoId: videoId,
      );
      _details[detail.playlistId] = detail;
      _upsertSummary(
        PlaylistSummary(
          playlistId: detail.playlistId,
          title: detail.title,
          description: detail.description,
          itemCount: detail.itemCount,
          updatedAt: detail.updatedAt,
          createdAt: detail.createdAt,
        ),
        moveToTop: true,
      );
      return detail;
    } finally {
      _creating = false;
      notifyListeners();
    }
  }

  Future<void> addToPlaylist(String playlistId, String videoId) async {
    if (_addingToPlaylist.contains(playlistId)) return;
    _addingToPlaylist.add(playlistId);
    notifyListeners();
    try {
      await _requireConnection();
      await _playlistRepository.addItem(playlistId, videoId);
      await loadPlaylistDetail(playlistId, silent: true);
      _moveSummaryToTop(playlistId);
    } finally {
      _addingToPlaylist.remove(playlistId);
      notifyListeners();
    }
  }

  Future<void> removeItem(String playlistId, String videoId) async {
    final key = '$playlistId:$videoId';
    if (_removingItems.contains(key)) return;
    _removingItems.add(key);
    notifyListeners();
    try {
      await _requireConnection();
      await _playlistRepository.removeItem(playlistId, videoId);
      await loadPlaylistDetail(playlistId, silent: true);
      _moveSummaryToTop(playlistId);
    } finally {
      _removingItems.remove(key);
      notifyListeners();
    }
  }

  Future<void> updateMetadata(
    String playlistId, {
    required String title,
    String? description,
  }) async {
    await _playlistRepository.updatePlaylist(
      playlistId,
      title: title,
      description: description,
    );
    await loadPlaylistDetail(playlistId, silent: true);
    _moveSummaryToTop(playlistId);
    notifyListeners();
  }

  /// Reorders playlist items to match [videoIdsInOrder] (see API `items/reorder`).
  Future<void> reorderPlaylistItems(
    String playlistId,
    List<String> videoIdsInOrder,
  ) async {
    await _playlistRepository.reorderItems(playlistId, videoIdsInOrder);
    await loadPlaylistDetail(playlistId, silent: true);
    _moveSummaryToTop(playlistId);
    notifyListeners();
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (_deleting) return;
    _deleting = true;
    notifyListeners();
    try {
      await _requireConnection();
      await _playlistRepository.deletePlaylist(playlistId);
      _playlists.removeWhere((p) => p.playlistId == playlistId);
      _details.remove(playlistId);
    } finally {
      _deleting = false;
      notifyListeners();
    }
  }

  List<PlaylistSummary> filterPlaylists(String query) {
    if (query.trim().isEmpty) return playlists;
    final q = query.trim().toLowerCase();
    return playlists.where((p) => p.title.toLowerCase().contains(q)).toList();
  }

  void debounceSearch(VoidCallback action) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 280), action);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  PlaylistSummary? _summaryById(String playlistId) {
    for (final summary in _playlists) {
      if (summary.playlistId == playlistId) return summary;
    }
    return null;
  }

  void _upsertSummary(PlaylistSummary? summary, {bool moveToTop = false}) {
    if (summary == null) return;
    _playlists.removeWhere((e) => e.playlistId == summary.playlistId);
    if (moveToTop) {
      _playlists.insert(0, summary);
    } else {
      _playlists.add(summary);
      _playlists.sort(
        (a, b) => (b.updatedAt ?? '').compareTo(a.updatedAt ?? ''),
      );
    }
  }

  void _moveSummaryToTop(String playlistId) {
    final item = _summaryById(playlistId);
    if (item == null) return;
    _upsertSummary(item, moveToTop: true);
  }
}
