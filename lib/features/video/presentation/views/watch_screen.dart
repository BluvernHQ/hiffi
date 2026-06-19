import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/exceptions/api_exception.dart';
import '../../../../core/services/network_connectivity_service.dart';
import '../../../../core/services/playlist_session_storage.dart';
import '../../../../core/widgets/network_page_shell.dart';
import '../../../playlist/data/playlist_repository.dart';
import '../../../playlist/domain/models/playlist_models.dart';
import '../../../playlist/presentation/viewmodels/playlist_view_model.dart';
import '../../../mood/data/mood_playlist_repository.dart';
import '../../../mood/domain/models/mood_def.dart';
import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import 'video_player_page.dart';

class _WatchReady {
  const _WatchReady({required this.video, this.playlistSession});

  final VideoModel video;
  final PlaylistSession? playlistSession;
}

class WatchScreen extends StatefulWidget {
  const WatchScreen({
    super.key,
    required this.videoId,
    this.playlistId,
    this.playlistIndex,
    this.isCuratedPlaylist = false,
    this.initialVideo,
    this.initialPlaylistSession,
  });

  final String videoId;
  final String? playlistId;
  final int? playlistIndex;
  final bool isCuratedPlaylist;
  final VideoModel? initialVideo;
  final PlaylistSession? initialPlaylistSession;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late final Future<_WatchReady> _readyFuture;

  @override
  void initState() {
    super.initState();
    _readyFuture = _initialize();
  }

  void _retryLoad() {
    setState(() {
      _readyFuture = _initialize();
    });
  }

  Future<bool> _isDeviceOnline() async {
    final connectivity = context.read<NetworkConnectivityService>();
    await connectivity.ensureInitialized();
    return connectivity.isConnected;
  }

  Future<_WatchReady> _initialize() async {
    await _hydratePlaylistContext();
    var video = widget.initialVideo;

    if (await _isDeviceOnline()) {
      try {
        final videoInfo = await context
            .read<VideoRepository>()
            .getVideoInfo(widget.videoId);
        if (videoInfo.video != null) {
          video = videoInfo.video;
        }
      } catch (_) {
        // Keep preview/cached video when refresh fails.
      }
    }

    if (video == null) {
      throw NoInternetException();
    }

    return _WatchReady(video: video, playlistSession: _playlistSession);
  }

  PlaylistSession? _playlistSession;

  Future<void> _hydratePlaylistContext() async {
    _playlistSession = widget.initialPlaylistSession;

    final incomingPlaylistId = widget.playlistId;
    if (incomingPlaylistId == null || incomingPlaylistId.isEmpty) return;
    if (_playlistSession != null && _playlistSession!.isValid) {
      await PlaylistSessionStorage().save(_playlistSession!);
      return;
    }

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

    final vm = context.read<PlaylistViewModel>();
    final cachedDetail = widget.isCuratedPlaylist
        ? vm.curatedDetail(incomingPlaylistId)
        : vm.detail(incomingPlaylistId);
    if (cachedDetail != null && cachedDetail.items.isNotEmpty) {
      _applyPlaylistDetail(cachedDetail);
      await storage.save(_playlistSession!);
      return;
    }

    if (!await _isDeviceOnline()) return;

    try {
      final moodVibe = moodVibeFromPlaylistId(incomingPlaylistId);
      if (moodVibe != null) {
        final moodRepo = context.read<MoodPlaylistRepository>();
        final page = await moodRepo.getMoodPlaylist(
          moodVibe,
          limit: 100,
          offset: 0,
        );
        _applyPlaylistDetail(page.detail);
        await storage.save(_playlistSession!);
        return;
      }

      final repo = context.read<PlaylistRepository>();
      final detail = widget.isCuratedPlaylist
          ? await repo.getCuratedPlaylist(incomingPlaylistId)
          : await repo.getPlaylist(incomingPlaylistId);
      _applyPlaylistDetail(detail);
      await storage.save(_playlistSession!);
    } catch (_) {
      // Playlist hydration failure should not block watch experience.
    }
  }

  void _applyPlaylistDetail(PlaylistDetail detail) {
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
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_WatchReady>(
      future: _readyFuture,
      builder: (context, snapshot) {
        final isWaiting = snapshot.connectionState == ConnectionState.waiting;
        final hasError = snapshot.hasError;
        final ready = snapshot.data;

        return NetworkPageShell(
          hasCachedContent: widget.initialVideo != null,
          isLoading: isWaiting && widget.initialVideo == null,
          emptyDescription: 'Connect to the internet to watch this video.',
          onRetry: () async => _retryLoad(),
          child: isWaiting
              ? const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(color: Color(0xFFED1C2F)),
                  ),
                )
              : hasError
              ? Scaffold(
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
                            "We couldn't load this video.",
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: _retryLoad,
                            child: const Text('Try Again'),
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
                )
              : VideoPlayerPage(
                  video: ready!.video,
                  videoId: widget.videoId,
                  returningFromAuth: false,
                  playlistSession: ready.playlistSession,
                ),
        );
      },
    );
  }
}
