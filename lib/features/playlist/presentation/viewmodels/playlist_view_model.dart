import 'dart:async';

import 'package:flutter/material.dart';

import '../../../video/domain/models/video_model.dart';
import '../../../video/domain/repositories/video_repository.dart';
import '../../data/playlist_repository.dart';
import '../../domain/models/playlist_models.dart';

class PlaylistViewModel extends ChangeNotifier {
  PlaylistViewModel({
    required PlaylistRepository playlistRepository,
    required VideoRepository videoRepository,
  }) : _playlistRepository = playlistRepository,
       _videoRepository = videoRepository;

  final PlaylistRepository _playlistRepository;
  final VideoRepository _videoRepository;

  List<PlaylistSummary> _playlists = [];
  final Map<String, PlaylistDetail> _details = {};
  final Map<String, VideoModel> _videoCache = {};
  bool _isLoadingList = false;
  String? _listError;
  final Set<String> _removingItems = <String>{};
  final Set<String> _addingToPlaylist = <String>{};
  bool _creating = false;
  bool _deleting = false;
  Timer? _searchDebounce;

  List<PlaylistSummary> get playlists => List.unmodifiable(_playlists);
  bool get isLoadingList => _isLoadingList;
  String? get listError => _listError;
  bool get isCreating => _creating;
  bool get isDeleting => _deleting;

  bool isRemovingItem(String playlistId, String videoId) =>
      _removingItems.contains('$playlistId:$videoId');
  bool isAddingToPlaylist(String playlistId) =>
      _addingToPlaylist.contains(playlistId);

  PlaylistDetail? detail(String playlistId) => _details[playlistId];
  VideoModel? cachedVideo(String videoId) => _videoCache[videoId];

  Future<void> loadPlaylists() async {
    _isLoadingList = true;
    _listError = null;
    notifyListeners();
    try {
      _playlists = await _playlistRepository.getSelfPlaylists();
      for (final playlist in _playlists) {
        unawaited(loadPlaylistDetail(playlist.playlistId, silent: true));
      }
    } catch (e) {
      _listError = e.toString();
    } finally {
      _isLoadingList = false;
      notifyListeners();
    }
  }

  Future<PlaylistDetail?> loadPlaylistDetail(
    String playlistId, {
    bool silent = false,
  }) async {
    if (!silent) notifyListeners();
    try {
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
