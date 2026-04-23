import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/services/playlist_session_storage.dart';
import '../../../playlist/data/playlist_repository.dart';
import '../../../playlist/domain/models/playlist_models.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import 'video_player_page.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.videoId,
    this.playlistId,
    this.playlistIndex,
  });

  final String videoId;
  final String? playlistId;
  final int? playlistIndex;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late Future<VideoModel> _videoFuture;
  PlaylistSession? _playlistSession;

  @override
  void initState() {
    super.initState();
    _videoFuture = _loadVideo();
  }

  Future<VideoModel> _loadVideo() async {
    final videoRepository = context.read<VideoRepository>();
    await _hydratePlaylistContext();

    final videoInfo = await videoRepository.getVideoInfo(widget.videoId);
    final video = videoInfo.video;
    if (video == null) {
      throw Exception('Video not found for id ${widget.videoId}');
    }
    return video;
  }

  Future<void> _hydratePlaylistContext() async {
    final incomingPlaylistId = widget.playlistId;
    if (incomingPlaylistId == null || incomingPlaylistId.isEmpty) return;
    final storage = PlaylistSessionStorage();
    final persisted = await storage.read();
    if (persisted != null &&
        persisted.playlistId == incomingPlaylistId &&
        persisted.videoIds.contains(widget.videoId)) {
      final idx =
          widget.playlistIndex ?? persisted.videoIds.indexOf(widget.videoId);
      _playlistSession = persisted.copyWith(currentIndex: idx < 0 ? 0 : idx);
      await storage.save(_playlistSession!);
      return;
    }

    try {
      final repo = context.read<PlaylistRepository>();
      final detail = await repo.getPlaylist(incomingPlaylistId);
      final ids = detail.items.map((e) => e.videoId).toList();
      final index = widget.playlistIndex ?? ids.indexOf(widget.videoId);
      if (ids.isEmpty) return;
      _playlistSession = PlaylistSession(
        playlistId: detail.playlistId,
        title: detail.title,
        videoIds: ids,
        currentIndex: index < 0 ? 0 : index,
        autoplay: true,
      );
      await storage.save(_playlistSession!);
    } catch (_) {
      // Playlist hydration failure should not block watch experience.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VideoModel>(
      future: _videoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFFED1C2F)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Video unavailable')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'We couldn’t load this video.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      child: const Text('Back'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context.go('/home'),
                      child: const Text('Go to Home'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final video = snapshot.data!;
        return VideoPlayerPage(
          video: video,
          videoId: widget.videoId,
          returningFromAuth: false,
          playlistSession: _playlistSession,
        );
      },
    );
  }
}
