import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models/video_model.dart';
import '../../domain/repositories/video_repository.dart';
import 'video_player_page.dart';

class WatchScreen extends StatefulWidget {
  const WatchScreen({super.key, required this.videoId});

  final String videoId;

  @override
  State<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends State<WatchScreen> {
  late Future<VideoModel> _videoFuture;

  @override
  void initState() {
    super.initState();
    _videoFuture = _loadVideo();
  }

  Future<VideoModel> _loadVideo() async {
    final videoRepository = context.read<VideoRepository>();

    final videoInfo = await videoRepository.getVideoInfo(widget.videoId);
    final video = videoInfo.video;
    if (video == null) {
      throw Exception('Video not found for id ${widget.videoId}');
    }
    return video;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<VideoModel>(
      future: _videoFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFED1C2F),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Video unavailable'),
            ),
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
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
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
        );
      },
    );
  }
}

