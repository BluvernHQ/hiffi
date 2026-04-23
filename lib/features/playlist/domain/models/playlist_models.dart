class PlaylistSummary {
  const PlaylistSummary({
    required this.playlistId,
    required this.title,
    this.description,
    this.itemCount,
    this.updatedAt,
    this.createdAt,
  });

  final String playlistId;
  final String title;
  final String? description;

  /// Not returned by `GET /playlists/list/self`; may be set after loading detail.
  final int? itemCount;
  final String? updatedAt;
  final String? createdAt;

  factory PlaylistSummary.fromJson(Map<String, dynamic> json) {
    final parsedCount =
        (json['item_count'] as num?)?.toInt() ??
        (json['total_videos'] as num?)?.toInt() ??
        (json['totalVideos'] as num?)?.toInt();
    return PlaylistSummary(
      playlistId: (json['playlist_id'] ?? json['playlistId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      itemCount: parsedCount,
      updatedAt: json['updated_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  PlaylistSummary copyWith({
    String? title,
    String? description,
    int? itemCount,
    String? updatedAt,
    String? createdAt,
  }) {
    return PlaylistSummary(
      playlistId: playlistId,
      title: title ?? this.title,
      description: description ?? this.description,
      itemCount: itemCount ?? this.itemCount,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class PlaylistItem {
  const PlaylistItem({
    required this.videoId,
    required this.position,
    this.addedAt,
    this.videoTitle,
    this.videoThumbnail,
  });

  final String videoId;
  final int position;
  final String? addedAt;
  final String? videoTitle;
  final String? videoThumbnail;

  factory PlaylistItem.fromJson(Map<String, dynamic> json) {
    final nestedVideo = json['video'] as Map<String, dynamic>?;
    final nestedId = nestedVideo?['video_id'] ?? nestedVideo?['videoId'];
    return PlaylistItem(
      videoId: (json['video_id'] ?? json['videoId'] ?? nestedId ?? '').toString(),
      position: (json['position'] as num?)?.toInt() ?? 0,
      addedAt: json['added_at']?.toString(),
      videoTitle:
          json['video_title']?.toString() ??
          nestedVideo?['video_title']?.toString(),
      videoThumbnail:
          json['video_thumbnail']?.toString() ??
          nestedVideo?['video_thumbnail']?.toString(),
    );
  }
}

class PlaylistDetail {
  const PlaylistDetail({
    required this.playlistId,
    required this.title,
    this.description,
    required this.items,
    this.updatedAt,
    this.createdAt,
  });

  final String playlistId;
  final String title;
  final String? description;
  final List<PlaylistItem> items;
  final String? updatedAt;
  final String? createdAt;

  int get itemCount => items.length;

  /// `GET /playlists/{id}` shape: `data.playlist` + `data.items` (+ pagination fields).
  factory PlaylistDetail.fromPlaylistGetData(Map<String, dynamic> data) {
    final playlist = data['playlist'] as Map<String, dynamic>?;
    if (playlist != null) {
      final rawItems = data['items'] as List<dynamic>? ?? const [];
      final items =
          rawItems
              .whereType<Map<String, dynamic>>()
              .map(PlaylistItem.fromJson)
              .toList()
            ..sort((a, b) => a.position.compareTo(b.position));
      return PlaylistDetail(
        playlistId: (playlist['playlist_id'] ?? playlist['playlistId'] ?? '')
            .toString(),
        title: (playlist['title'] ?? '').toString(),
        description: playlist['description']?.toString(),
        items: items,
        updatedAt: playlist['updated_at']?.toString(),
        createdAt: playlist['created_at']?.toString(),
      );
    }
    return PlaylistDetail.fromJson(data);
  }

  /// Flat / legacy shape where playlist fields and `items` sit on one object.
  factory PlaylistDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = (json['items'] as List<dynamic>? ?? const []);
    final items =
        rawItems
            .whereType<Map<String, dynamic>>()
            .map(PlaylistItem.fromJson)
            .toList()
          ..sort((a, b) => a.position.compareTo(b.position));
    return PlaylistDetail(
      playlistId: (json['playlist_id'] ?? json['playlistId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      items: items,
      updatedAt: json['updated_at']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class PlaylistSession {
  const PlaylistSession({
    required this.playlistId,
    this.title,
    required this.videoIds,
    required this.currentIndex,
    required this.autoplay,
  });

  final String playlistId;
  final String? title;
  final List<String> videoIds;
  final int currentIndex;
  final bool autoplay;

  bool get isValid =>
      playlistId.isNotEmpty &&
      videoIds.isNotEmpty &&
      currentIndex >= 0 &&
      currentIndex < videoIds.length;

  Map<String, dynamic> toJson() {
    return {
      'playlistId': playlistId,
      'title': title,
      'videoIds': videoIds,
      'currentIndex': currentIndex,
      'autoplay': autoplay,
    };
  }

  factory PlaylistSession.fromJson(Map<String, dynamic> json) {
    return PlaylistSession(
      playlistId: (json['playlistId'] ?? '').toString(),
      title: json['title']?.toString(),
      videoIds: (json['videoIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      autoplay: json['autoplay'] as bool? ?? true,
    );
  }

  PlaylistSession copyWith({
    String? title,
    List<String>? videoIds,
    int? currentIndex,
    bool? autoplay,
  }) {
    return PlaylistSession(
      playlistId: playlistId,
      title: title ?? this.title,
      videoIds: videoIds ?? this.videoIds,
      currentIndex: currentIndex ?? this.currentIndex,
      autoplay: autoplay ?? this.autoplay,
    );
  }
}
