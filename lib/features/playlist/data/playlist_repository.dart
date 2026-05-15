import 'dart:convert';

import '../../../core/constants/api_constants.dart';
import '../../../core/exceptions/api_exception.dart';
import '../../../core/services/api_client.dart';
import '../domain/models/playlist_models.dart';

/// Owner-only playlist API (`/playlists`). All calls require auth.
///
/// List/detail responses use `limit` / `offset` / `count` pagination like other
/// Hiffi list endpoints. This client fetches **all pages** for list + detail
/// unless you introduce a paged UI later.
abstract class PlaylistRepository {
  /// `GET /playlists/curated` — public curated playlists.
  Future<List<PlaylistSummary>> getCuratedPlaylists();

  /// `GET /playlists/curated/{playlistID}` — public curated playlist detail.
  Future<PlaylistDetail> getCuratedPlaylist(String playlistId);

  /// `GET /playlists/list/self` — all pages merged, server order preserved.
  Future<List<PlaylistSummary>> getSelfPlaylists();

  /// `GET /playlists/{playlistID}` — all item pages merged.
  Future<PlaylistDetail> getPlaylist(String playlistId);

  /// `POST /playlists/create` then `GET` detail (create payload is not full playlist).
  Future<PlaylistDetail> createPlaylist({
    required String title,
    String? description,
    required String videoId,
  });

  /// `PUT /playlists/{playlistID}` — response is `{ updated: true }` only.
  Future<void> updatePlaylist(
    String playlistId, {
    String? title,
    String? description,
  });

  /// `DELETE /playlists/{playlistID}`.
  Future<void> deletePlaylist(String playlistId);

  /// `POST /playlists/{playlistID}/items/add`.
  Future<void> addItem(String playlistId, String videoId);

  /// `DELETE /playlists/{playlistID}/items/{videoID}`.
  Future<void> removeItem(String playlistId, String videoId);

  /// `PUT /playlists/{playlistID}/items/reorder` — body uses ordered `video_ids`.
  /// Align with backend if the contract differs.
  Future<void> reorderItems(String playlistId, List<String> videoIdsInOrder);
}

class PlaylistRepositoryImpl implements PlaylistRepository {
  PlaylistRepositoryImpl({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  static const int _maxPageLimit = 100;

  @override
  Future<List<PlaylistSummary>> getCuratedPlaylists() async {
    final merged = <PlaylistSummary>[];
    var offset = 0;
    while (true) {
      final endpoint =
          '${ApiConstants.playlistCuratedList}?limit=$_maxPageLimit&offset=$offset';
      final response = await _apiClient.get(endpoint, requiresAuth: false);
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch curated playlists (${response.statusCode})',
        );
      }
      final payload = _decode(response.body);
      _ensureSuccessOrThrow(payload);
      final data = _extractData(payload);
      final raw = _coerceJsonList(data['items']).isNotEmpty
          ? _coerceJsonList(data['items'])
          : _coerceJsonList(data['playlists']);
      final page = raw
          .whereType<Map<String, dynamic>>()
          .map(PlaylistSummary.fromJson)
          .where((p) => p.playlistId.isNotEmpty)
          .toList();
      merged.addAll(page);
      if (page.length < _maxPageLimit) break;
      offset += _maxPageLimit;
    }
    return merged;
  }

  @override
  Future<PlaylistDetail> getCuratedPlaylist(String playlistId) async {
    final allItems = <PlaylistItem>[];
    late PlaylistDetail header;
    var offset = 0;
    var isFirstPage = true;
    while (true) {
      final endpoint =
          '${ApiConstants.playlistCuratedDetail(playlistId)}?limit=$_maxPageLimit&offset=$offset';
      final response = await _apiClient.get(endpoint, requiresAuth: false);
      if (response.statusCode == 404) {
        throw ApiException('Curated playlist not found', 404);
      }
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch curated playlist (${response.statusCode})',
        );
      }
      final payload = _decode(response.body);
      _ensureSuccessOrThrow(payload);
      final data = _extractData(payload);
      final pageDetail = PlaylistDetail.fromPlaylistGetData(data);
      if (isFirstPage) {
        header = pageDetail;
        isFirstPage = false;
      }
      allItems.addAll(pageDetail.items);
      if (pageDetail.items.length < _maxPageLimit) break;
      offset += _maxPageLimit;
    }
    final deduped = _mergeItemsByPosition(allItems);
    return PlaylistDetail(
      playlistId: header.playlistId,
      title: header.title,
      description: header.description,
      items: deduped,
      updatedAt: header.updatedAt,
      createdAt: header.createdAt,
    );
  }

  @override
  Future<List<PlaylistSummary>> getSelfPlaylists() async {
    final merged = <PlaylistSummary>[];
    var offset = 0;
    while (true) {
      final endpoint =
          '${ApiConstants.playlistListSelf}?limit=$_maxPageLimit&offset=$offset';
      final response = await _apiClient.get(endpoint, requiresAuth: true);
      _throwIfAuth(response.statusCode);
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch playlists (${response.statusCode})');
      }
      final payload = _decode(response.body);
      _ensureSuccessOrThrow(payload);
      final data = _extractData(payload);
      final raw = _coerceJsonList(data['items']).isNotEmpty
          ? _coerceJsonList(data['items'])
          : _coerceJsonList(data['playlists']);
      final page = raw
          .whereType<Map<String, dynamic>>()
          .map(PlaylistSummary.fromJson)
          .where((p) => p.playlistId.isNotEmpty)
          .toList();
      merged.addAll(page);
      if (page.length < _maxPageLimit) break;
      offset += _maxPageLimit;
    }
    return merged;
  }

  @override
  Future<PlaylistDetail> getPlaylist(String playlistId) async {
    final allItems = <PlaylistItem>[];
    late PlaylistDetail header;
    var offset = 0;
    var isFirstPage = true;
    while (true) {
      final endpoint =
          '${ApiConstants.playlistDetail(playlistId)}?limit=$_maxPageLimit&offset=$offset';
      final response = await _apiClient.get(endpoint, requiresAuth: true);
      _throwIfAuth(response.statusCode);
      if (response.statusCode == 404) {
        throw ApiException('Playlist not found', 404);
      }
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch playlist (${response.statusCode})');
      }
      final payload = _decode(response.body);
      _ensureSuccessOrThrow(payload);
      final data = _extractData(payload);
      final pageDetail = PlaylistDetail.fromPlaylistGetData(data);
      if (isFirstPage) {
        header = pageDetail;
        isFirstPage = false;
      }
      allItems.addAll(pageDetail.items);
      if (pageDetail.items.length < _maxPageLimit) break;
      offset += _maxPageLimit;
    }
    final deduped = _mergeItemsByPosition(allItems);
    return PlaylistDetail(
      playlistId: header.playlistId,
      title: header.title,
      description: header.description,
      items: deduped,
      updatedAt: header.updatedAt,
      createdAt: header.createdAt,
    );
  }

  @override
  Future<PlaylistDetail> createPlaylist({
    required String title,
    String? description,
    required String videoId,
  }) async {
    final body = <String, dynamic>{'title': title, 'video_id': videoId};
    if (description != null && description.trim().isNotEmpty) {
      body['description'] = description.trim();
    }
    final response = await _apiClient.post(
      ApiConstants.playlistCreate,
      body,
      requiresAuth: true,
    );
    _throwIfAuth(response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to create playlist (${response.statusCode})');
    }
    final payload = _decode(response.body);
    _ensureSuccessOrThrow(payload);
    final data = _extractData(payload);
    final id = (data['playlist_id'] ?? data['playlistId'] ?? '').toString();
    if (id.isEmpty) {
      throw Exception('Create playlist: missing playlist_id in response');
    }
    return getPlaylist(id);
  }

  @override
  Future<void> updatePlaylist(
    String playlistId, {
    String? title,
    String? description,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    final response = await _apiClient.put(
      ApiConstants.playlistDetail(playlistId),
      body,
      requiresAuth: true,
    );
    _throwIfAuth(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to update playlist (${response.statusCode})');
    }
    final payload = _decode(response.body);
    _ensureSuccessOrThrow(payload);
    final data = _extractData(payload);
    if (data.containsKey('updated') && data['updated'] != true) {
      throw Exception('Update playlist was not confirmed by API');
    }
  }

  @override
  Future<void> deletePlaylist(String playlistId) async {
    final response = await _apiClient.delete(
      ApiConstants.playlistDetail(playlistId),
      requiresAuth: true,
    );
    _throwIfAuth(response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete playlist (${response.statusCode})');
    }
    if (response.body.isEmpty) return;
    final payload = _decode(response.body);
    _ensureSuccessOrThrow(payload);
    final data = _extractData(payload);
    if (data.containsKey('deleted') && data['deleted'] != true) {
      throw Exception('Delete playlist was not confirmed by API');
    }
  }

  @override
  Future<void> addItem(String playlistId, String videoId) async {
    final response = await _apiClient.post(
      ApiConstants.playlistAddItem(playlistId),
      {'video_id': videoId},
      requiresAuth: true,
    );
    _throwIfAuth(response.statusCode);
    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception('Failed to add video (${response.statusCode})');
    }
    if (response.body.isEmpty) return;
    final payload = _decode(response.body);
    _ensureSuccessOrThrow(payload);
    final data = _extractData(payload);
    if (data.containsKey('added') && data['added'] != true) {
      throw Exception('Add to playlist was not confirmed by API');
    }
  }

  @override
  Future<void> removeItem(String playlistId, String videoId) async {
    final response = await _apiClient.delete(
      ApiConstants.playlistRemoveItem(playlistId, videoId),
      requiresAuth: true,
    );
    _throwIfAuth(response.statusCode);
    if (response.statusCode == 500) {
      // Backend sometimes fails DELETE even though remove is supported.
      // Best-effort fallback to a POST-style remove endpoint.
      final fallback = await _apiClient.post(
        '/playlists/$playlistId/items/remove',
        {'video_id': videoId},
        requiresAuth: true,
      );
      _throwIfAuth(fallback.statusCode);
      if (fallback.statusCode == 200 || fallback.statusCode == 204) return;
    }
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to remove video (${response.statusCode})');
    }
    if (response.body.isEmpty) return;
    final payload = _decode(response.body);
    _ensureSuccessOrThrow(payload);
    final data = _extractData(payload);
    if (data.containsKey('removed') && data['removed'] != true) {
      throw Exception('Remove from playlist was not confirmed by API');
    }
  }

  @override
  Future<void> reorderItems(
    String playlistId,
    List<String> videoIdsInOrder,
  ) async {
    if (videoIdsInOrder.isEmpty) {
      throw ArgumentError('videoIdsInOrder must not be empty');
    }
    final response = await _apiClient.put(
      ApiConstants.playlistReorderItems(playlistId),
      {'video_ids': videoIdsInOrder},
      requiresAuth: true,
    );
    _throwIfAuth(response.statusCode);
    if (response.statusCode != 200) {
      throw Exception('Failed to reorder playlist (${response.statusCode})');
    }
    if (response.body.isEmpty) return;
    final payload = _decode(response.body);
    if (payload.isNotEmpty) {
      _ensureSuccessOrThrow(payload);
    }
  }

  void _throwIfAuth(int statusCode) {
    if (statusCode == 401) {
      throw ApiException('Session expired. Please sign in again.', 401);
    }
  }

  Map<String, dynamic> _decode(String body) {
    if (body.isEmpty) return <String, dynamic>{};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Map<String, dynamic> _extractData(Map<String, dynamic> payload) {
    final data = payload['data'];
    if (data is Map<String, dynamic>) return data;
    return payload;
  }

  void _ensureSuccessOrThrow(Map<String, dynamic> payload) {
    final ok = payload['success'] == true || payload['status'] == 'success';
    if (ok) return;
    final message =
        payload['message']?.toString() ??
        payload['error']?.toString() ??
        'Request failed';
    throw Exception(message);
  }

  /// Same [video_id] at same [position] should not appear across pages; keep stable order.
  List<dynamic> _coerceJsonList(Object? value) {
    if (value is List<dynamic>) return value;
    if (value is List) return value;
    return const [];
  }

  List<PlaylistItem> _mergeItemsByPosition(List<PlaylistItem> items) {
    items.sort((a, b) => a.position.compareTo(b.position));
    final seen = <String>{};
    final out = <PlaylistItem>[];
    for (final item in items) {
      if (item.videoId.isEmpty) continue;
      if (seen.add(item.videoId)) {
        out.add(item);
      }
    }
    return out;
  }
}
