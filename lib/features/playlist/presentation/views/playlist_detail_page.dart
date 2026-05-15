import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/analytics_service.dart';
import '../../../../core/utils/network_error_utils.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../../core/widgets/offline_info_state.dart';
import '../../../../core/widgets/main_scaffold.dart';
import '../../../video/domain/models/video_model.dart';
import '../../domain/models/playlist_models.dart';
import '../viewmodels/playlist_view_model.dart';

class PlaylistDetailPage extends StatefulWidget {
  const PlaylistDetailPage({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  bool _loading = true;
  String? _error;
  final Set<String> _optimisticallyRemovedItems = <String>{};
  final Set<String> _hintAnimatingItems = <String>{};
  final Set<String> _dismissDeletesPlaylist = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _load();
      }
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<PlaylistViewModel>().loadPlaylistDetail(
        widget.playlistId,
      );
      if (!mounted) return;
      await context.read<AnalyticsService>().logEvent(
        context,
        'playlist_detail_viewed',
        parameters: {'playlist_id': widget.playlistId},
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlaylistViewModel>();
    final detail = vm.detail(widget.playlistId);
    return MainScaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: _goBack,
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        ),
        titleSpacing: 0,
        title: const Text(
          'Back to playlists',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
      ),
      child: _loading
          ? const _DetailPageShimmer()
          : _error != null
          ? _ErrorState(message: _error!, onBack: _goBack)
          : detail == null
          ? _NotFoundState(onBack: _goBack)
          : _buildDetail(context, vm, detail),
    );
  }

  void _goBack() => context.go('/playlists');

  Widget _buildDetail(
    BuildContext context,
    PlaylistViewModel vm,
    PlaylistDetail detail,
  ) {
    final visibleItems = detail.items
        .where((item) => !_optimisticallyRemovedItems.contains(_itemRemovalKey(detail.playlistId, item.videoId)))
        .toList();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _DetailHero(
              detail: detail,
              thumbnailKeys: detail.items
                  .map(
                    (item) =>
                        vm.cachedVideo(item.videoId)?.videoThumbnail ??
                        item.videoThumbnail ??
                        '',
                  )
                  .where((thumb) => thumb.trim().isNotEmpty)
                  .take(8)
                  .toList(),
              onPlay: visibleItems.isEmpty
                  ? null
                  : () => _playFrom(detail, 0),
              onEdit: () => _openEditDialog(context, vm, detail),
              onDelete: () => _confirmDelete(context, vm, detail.playlistId),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Playlist videos',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Pick any video to continue this playlist session.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 10)),
        if (visibleItems.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5E5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.playlist_add_rounded,
                      size: 46,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'This playlist is empty',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add videos from any watch page to start building this playlist.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.explore_rounded),
                      label: const Text('Discover videos'),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          SliverList.builder(
            itemCount: visibleItems.length,
            itemBuilder: (context, index) {
              final item = visibleItems[index];
              final video = vm.cachedVideo(item.videoId);
              final itemKey = _itemRemovalKey(detail.playlistId, item.videoId);
              final removing =
                  vm.isRemovingItem(detail.playlistId, item.videoId) ||
                  _hintAnimatingItems.contains(itemKey);
              final title = video?.videoTitle ?? item.videoTitle ?? item.videoId;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Dismissible(
                  key: ValueKey('${detail.playlistId}:${item.videoId}:$index'),
                  direction: removing
                      ? DismissDirection.none
                      : DismissDirection.endToStart,
                  background: const _SwipeRemoveBackground(),
                  confirmDismiss: (_) async {
                    final isLastItem = visibleItems.length == 1;
                    final decision = await _confirmRemoveOrDeleteLastSheet(
                      context,
                      videoTitle: title,
                      isLastItem: isLastItem,
                    );
                    if (decision == _RemoveDecision.deletePlaylist) {
                      _dismissDeletesPlaylist.add(itemKey);
                      return true;
                    }
                    if (decision == _RemoveDecision.removeOnly) {
                      _dismissDeletesPlaylist.remove(itemKey);
                      return true;
                    }
                    return false;
                  },
                  onDismissed: (_) async {
                    if (_dismissDeletesPlaylist.remove(itemKey)) {
                      // Remove from tree immediately after dismiss completes.
                      if (mounted) {
                        setState(() {
                          _optimisticallyRemovedItems.add(itemKey);
                        });
                      }
                      try {
                        await vm.deletePlaylist(detail.playlistId);
                        if (!mounted) return;
                        _goBack();
                        return;
                      } catch (e) {
                        if (!mounted) return;
                        // Roll back optimistic removal if deletion fails.
                        setState(() {
                          _optimisticallyRemovedItems.remove(itemKey);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Could not delete playlist. Please try again. ($e)',
                            ),
                          ),
                        );
                        return;
                      }
                    }
                    await _removePlaylistItem(
                      vm: vm,
                      playlistId: detail.playlistId,
                      videoId: item.videoId,
                    );
                  },
                  child: _PlaylistItemRow(
                    index: index,
                    total: visibleItems.length,
                    title: title,
                    thumbnail: _thumb(video),
                    removing: removing,
                    slideOutToLeft: _hintAnimatingItems.contains(itemKey),
                    onPlay: () => _playFrom(detail, index),
                    onOpen: () => _playFrom(detail, index),
                    onSwipeHintTap: removing
                        ? null
                        : () => _removeFromHintTap(
                            vm: vm,
                            detail: detail,
                            item: item,
                            videoTitle: title,
                          ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PlaylistViewModel vm,
    String playlistId,
  ) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delete playlist?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This removes the playlist and all item ordering. This cannot be undone.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDE3341),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true) return;
    await vm.deletePlaylist(playlistId);
    if (!mounted) return;
    _goBack();
  }

  void _playFrom(PlaylistDetail detail, int index) {
    final visibleItems = detail.items
        .where((item) => !_optimisticallyRemovedItems.contains(_itemRemovalKey(detail.playlistId, item.videoId)))
        .toList();
    if (index < 0 || index >= visibleItems.length) return;
    final targetId = visibleItems[index].videoId;
    context.go(
      '/watch/$targetId?playlist=${detail.playlistId}&pindex=$index',
    );
  }

  String _itemRemovalKey(String playlistId, String videoId) =>
      '$playlistId:$videoId';

  Future<void> _removePlaylistItem({
    required PlaylistViewModel vm,
    required String playlistId,
    required String videoId,
  }) async {
    final itemKey = _itemRemovalKey(playlistId, videoId);
    final detail = vm.detail(playlistId);
    final remainingCount = detail?.items
        .where(
          (item) => !_optimisticallyRemovedItems.contains(
            _itemRemovalKey(playlistId, item.videoId),
          ),
        )
        .length;
    final isLastItem = remainingCount == 1;

    if (isLastItem) {
      final confirmDelete = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delete playlist?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'This is the last video in the playlist. Removing it will also delete the playlist.',
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFDE3341),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Delete'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (confirmDelete != true) return;
      await vm.deletePlaylist(playlistId);
      if (!mounted) return;
      _goBack();
      return;
    }

    setState(() {
      _optimisticallyRemovedItems.add(itemKey);
    });
    try {
      await vm.removeItem(playlistId, videoId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _optimisticallyRemovedItems.remove(itemKey);
      });
    }
  }

  Future<void> _removeFromHintTap({
    required PlaylistViewModel vm,
    required PlaylistDetail detail,
    required PlaylistItem item,
    required String videoTitle,
  }) async {
    final visibleCount = detail.items
        .where(
          (it) =>
              !_optimisticallyRemovedItems.contains(
                _itemRemovalKey(detail.playlistId, it.videoId),
              ),
        )
        .length;
    final decision = await _confirmRemoveOrDeleteLastSheet(
      context,
      videoTitle: videoTitle,
      isLastItem: visibleCount == 1,
    );
    if (decision == _RemoveDecision.cancelled || !mounted) return;
    if (decision == _RemoveDecision.deletePlaylist) {
      await vm.deletePlaylist(detail.playlistId);
      if (!mounted) return;
      _goBack();
      return;
    }

    final itemKey = _itemRemovalKey(detail.playlistId, item.videoId);
    setState(() {
      _hintAnimatingItems.add(itemKey);
    });

    // Play a short left-slide animation to teach swipe-to-remove behavior.
    await Future.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    await _removePlaylistItem(
      vm: vm,
      playlistId: detail.playlistId,
      videoId: item.videoId,
    );
    if (!mounted) return;
    setState(() {
      _hintAnimatingItems.remove(itemKey);
    });
  }

  Future<_RemoveDecision> _confirmRemoveOrDeleteLastSheet(
    BuildContext context, {
    required String videoTitle,
    required bool isLastItem,
  }) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isLastItem ? 'Delete playlist?' : 'Remove from playlist?',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  isLastItem
                      ? 'This is the last video in the playlist. Removing it will also delete the playlist.'
                      : 'This removes "$videoTitle" from this playlist.',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFDE3341),
                          foregroundColor: Colors.white,
                        ),
                        child: Text(isLastItem ? 'Delete' : 'Remove'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirm != true) return _RemoveDecision.cancelled;
    return isLastItem ? _RemoveDecision.deletePlaylist : _RemoveDecision.removeOnly;
  }

  Widget _thumb(VideoModel? video) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: HiffiVideoThumbnail(
        thumbnailPath: video?.videoThumbnail,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
      ),
    );
  }

  Future<void> _openEditDialog(
    BuildContext context,
    PlaylistViewModel vm,
    PlaylistDetail detail,
  ) async {
    final title = TextEditingController(text: detail.title);
    final description = TextEditingController(text: detail.description ?? '');
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit playlist',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Title',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: title,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    hintText: 'Playlist title',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F8),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD8D8DC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD8D8DC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFED1C2F)),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return 'Playlist name is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: description,
                  maxLines: 3,
                  minLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Describe this playlist',
                    filled: true,
                    fillColor: const Color(0xFFF6F6F8),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD8D8DC)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFD8D8DC)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFED1C2F)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          side: const BorderSide(color: Color(0xFFD8D8DC)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          final valid =
                              formKey.currentState?.validate() ?? false;
                          if (!valid) return;
                          Navigator.of(ctx).pop(true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFED1C2F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (saved == true && title.text.trim().isNotEmpty) {
      await vm.updateMetadata(
        detail.playlistId,
        title: title.text.trim(),
        description: description.text.trim(),
      );
    }
  }
}

enum _RemoveDecision { cancelled, removeOnly, deletePlaylist }

class _DetailHero extends StatefulWidget {
  const _DetailHero({
    required this.detail,
    required this.thumbnailKeys,
    required this.onPlay,
    required this.onEdit,
    required this.onDelete,
  });

  final PlaylistDetail detail;
  final List<String> thumbnailKeys;
  final VoidCallback? onPlay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<_DetailHero> createState() => _DetailHeroState();
}

class _DetailHeroState extends State<_DetailHero> {
  late _HeroArtwork _artwork;
  int _paletteVersion = 0;

  @override
  void initState() {
    super.initState();
    _artwork = _HeroArtwork.fallback(
      playlistId: widget.detail.playlistId,
      title: widget.detail.title,
    );
    _refreshArtwork();
  }

  @override
  void didUpdateWidget(covariant _DetailHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changedIdentity =
        oldWidget.detail.playlistId != widget.detail.playlistId ||
        oldWidget.detail.title != widget.detail.title;
    final changedThumbs =
        oldWidget.thumbnailKeys.join('|') != widget.thumbnailKeys.join('|');
    if (changedIdentity || changedThumbs) {
      _artwork = _HeroArtwork.fallback(
        playlistId: widget.detail.playlistId,
        title: widget.detail.title,
      );
      _refreshArtwork();
    }
  }

  Future<void> _refreshArtwork() async {
    final token = ++_paletteVersion;
    final tones = await _ThumbnailToneExtractor.extract(widget.thumbnailKeys);
    if (!mounted || token != _paletteVersion) return;
    setState(() {
      _artwork = tones.isNotEmpty
          ? _HeroArtwork.fromPalette(tones)
          : _HeroArtwork.fallback(
              playlistId: widget.detail.playlistId,
              title: widget.detail.title,
            );
    });
  }

  @override
  Widget build(BuildContext context) {
    const heroRadius = 14.0;
    const heroButtonRadius = 12.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(heroRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(heroRadius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_artwork.a, _artwork.b, _artwork.c],
            stops: const [0, 0.52, 1],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.68, -0.52),
                    radius: 1.28,
                    colors: [_artwork.glowOne, Colors.transparent],
                    stops: const [0, 0.72],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.68, 0.64),
                    radius: 1.24,
                    colors: [_artwork.glowTwo, Colors.transparent],
                    stops: const [0, 0.72],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.24),
                      Colors.white.withValues(alpha: 0.0),
                      Colors.white.withValues(alpha: 0.12),
                    ],
                    stops: const [0.04, 0.42, 0.95],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _HeroDotTexturePainter()),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Color.fromRGBO(2, 6, 23, 0.22),
                      Color.fromRGBO(2, 6, 23, 0.56),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.detail.title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.detail.description?.isNotEmpty == true
                        ? widget.detail.description!
                        : 'A curated sequence ready to play through.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _MetaChip(label: '${widget.detail.itemCount} videos'),
                      Text(
                        'Updated ${_relativeTime(widget.detail.updatedAt)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      FilledButton.icon(
                        onPressed: widget.onPlay,
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play playlist'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          disabledBackgroundColor: Colors.white.withValues(
                            alpha: 0.45,
                          ),
                          disabledForegroundColor: Colors.black38,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(heroButtonRadius),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') widget.onEdit();
                          if (value == 'delete') widget.onDelete();
                        },
                        offset: const Offset(0, 10),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        itemBuilder: (_) => [
                          const PopupMenuItem<String>(
                            value: 'edit',
                            height: 36,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: Color(0xFF1A1A1A),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Edit playlist',
                                  style: TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const PopupMenuItem<String>(
                            value: 'delete',
                            height: 36,
                            padding: EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 17,
                                  color: Color(0xFFDE3341),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Delete playlist',
                                  style: TextStyle(
                                    color: Color(0xFFDE3341),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistItemRow extends StatelessWidget {
  const _PlaylistItemRow({
    required this.index,
    required this.total,
    required this.title,
    required this.thumbnail,
    required this.removing,
    required this.slideOutToLeft,
    required this.onPlay,
    required this.onOpen,
    required this.onSwipeHintTap,
  });

  final int index;
  final int total;
  final String title;
  final Widget thumbnail;
  final bool removing;
  final bool slideOutToLeft;
  final VoidCallback onPlay;
  final VoidCallback onOpen;
  final VoidCallback? onSwipeHintTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          const Positioned.fill(child: _SwipeRemoveBackground()),
          AnimatedSlide(
            offset: slideOutToLeft ? const Offset(-1.15, 0) : Offset.zero,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut,
            child: Material(
              color: const Color(0xFFF6F6F8),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onOpen,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 8, 10),
                  child: Row(
                    children: [
                      _IndexBadge(value: index + 1),
                      const SizedBox(width: 10),
                      thumbnail,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              index == 0
                                  ? 'Start of playlist'
                                  : 'Track ${index + 1} of $total',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: removing ? null : onPlay,
                        icon: removing
                            ? const _ShimmerDot()
                            : const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Play'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFED1C2F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _SwipeHintGlyph(onTap: onSwipeHintTap),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeRemoveBackground extends StatelessWidget {
  const _SwipeRemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFDE3341),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 18),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text(
            'Remove',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Non-text affordance that suggests swipe-left removal.
class _SwipeHintGlyph extends StatelessWidget {
  const _SwipeHintGlyph({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 26,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.chevron_left_rounded,
          size: 20,
          color: Colors.black38,
        ),
      ),
    );
  }
}

class _DetailPageShimmer extends StatelessWidget {
  const _DetailPageShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Container(
                width: 132,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                height: 170,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Container(
                width: 110,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 10)),
          SliverList.builder(
            itemCount: 4,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Container(
                height: 82,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerDot extends StatelessWidget {
  const _ShimmerDot();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white54,
      highlightColor: Colors.white,
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _IndexBadge extends StatelessWidget {
  const _IndexBadge({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFFEDEDEF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8D8DC)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _NotFoundState extends StatelessWidget {
  const _NotFoundState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Playlist not found'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onBack, child: const Text('Back to playlists')),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onBack});

  final String message;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final isOffline = isOfflineErrorMessage(message);
    if (isOffline) {
      return OfflineInfoState(
        message:
            'Connect to the internet to open and manage this playlist.',
        actionLabel: 'Back to playlists',
        onAction: onBack,
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isOffline
                  ? 'You are offline right now.\nConnect to the internet to open this playlist.'
                  : message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onBack, child: const Text('Back to playlists')),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(String? iso) {
  if (iso == null || iso.trim().isEmpty) return 'recently';
  final parsed = DateTime.tryParse(iso)?.toLocal();
  if (parsed == null) return 'recently';
  final diff = DateTime.now().difference(parsed);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  final weeks = (diff.inDays / 7).floor();
  if (weeks < 5) return '${weeks}w ago';
  final months = (diff.inDays / 30).floor();
  if (months < 12) return '$months mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

class _HeroArtwork {
  const _HeroArtwork({
    required this.a,
    required this.b,
    required this.c,
    required this.glowOne,
    required this.glowTwo,
  });

  final Color a;
  final Color b;
  final Color c;
  final Color glowOne;
  final Color glowTwo;

  factory _HeroArtwork.fallback({
    required String playlistId,
    required String title,
  }) {
    final seed = _seedFrom('$playlistId:$title');
    final hueA = (seed % 360).toDouble();
    final hueB = (seed * 1.57) % 360;
    final hueC = (seed * 2.17) % 360;

    final satA = 64 + (seed % 10);
    final satB = 58 + (seed % 12);
    final satC = 54 + (seed % 10);
    final lightA = 42 + (seed % 7);
    final lightB = 33 + (seed % 6);
    final lightC = 24 + (seed % 6);
    return _HeroArtwork(
      a: _toneHsl(hueA, satA.toDouble(), lightA.toDouble()),
      b: _toneHsl(hueB, satB.toDouble(), lightB.toDouble()),
      c: _toneHsl(hueC, satC.toDouble(), lightC.toDouble()),
      glowOne: _toneHsl(hueB, satB.toDouble(), (lightB + 14).toDouble())
          .withValues(alpha: 0.30),
      glowTwo: _toneHsl(hueA, satA.toDouble(), (lightA + 10).toDouble())
          .withValues(alpha: 0.24),
    );
  }

  factory _HeroArtwork.fromPalette(List<_Tone> tones) {
    final normalized = _normalizePalette(tones);
    final a = normalized[0];
    final b = normalized[1];
    final c = normalized[2];
    return _HeroArtwork(
      a: _toneHsl(a.h, a.s, a.l),
      b: _toneHsl(b.h, b.s, b.l),
      c: _toneHsl(c.h, c.s, c.l),
      glowOne: _toneHsl(b.h, b.s, (b.l + 12).clamp(0, 100).toDouble())
          .withValues(alpha: 0.30),
      glowTwo: _toneHsl(a.h, a.s, (a.l + 10).clamp(0, 100).toDouble())
          .withValues(alpha: 0.24),
    );
  }
}

class _HeroDotTexturePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 6.0;
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (double y = 3; y < size.height; y += spacing) {
      final shift = ((y / spacing).floor().isEven) ? 0.0 : 3.0;
      for (double x = 3 + shift; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ThumbnailToneExtractor {
  static Future<List<_Tone>> extract(List<String> thumbnailKeys) async {
    final tones = <_Tone>[];
    final headers = ImageUtils.getVideoThumbnailHeaders();
    for (final key in thumbnailKeys.take(8)) {
      final url = ImageUtils.getVideoThumbnailUrl(key);
      if (url == null || url.isEmpty) continue;
      try {
        final response = await http.get(Uri.parse(url), headers: headers);
        if (response.statusCode != 200) continue;
        final tone = await _sampleTone(response.bodyBytes);
        if (tone != null && !_isDuplicate(tones, tone)) {
          tones.add(tone);
        }
      } catch (_) {
        // Skip failed thumbnails; fallback artwork handles low-signal cases.
      }
      if (tones.length >= 3) break;
    }
    return _ensureThreeTones(tones);
  }

  static Future<_Tone?> _sampleTone(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 24,
      targetHeight: 24,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;
    final rgba = data.buffer.asUint8List();
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    var count = 0;
    for (var i = 0; i <= rgba.length - 4; i += 16) {
      final alpha = rgba[i + 3];
      if (alpha < 120) continue;
      r += rgba[i];
      g += rgba[i + 1];
      b += rgba[i + 2];
      count++;
    }
    if (count == 0) return null;
    return _rgbToHsl(r / count, g / count, b / count);
  }
}

class _Tone {
  const _Tone(this.h, this.s, this.l);
  final double h;
  final double s;
  final double l;
}

_Tone _rgbToHsl(double red, double green, double blue) {
  final r = (red / 255).clamp(0.0, 1.0);
  final g = (green / 255).clamp(0.0, 1.0);
  final b = (blue / 255).clamp(0.0, 1.0);
  final max = [r, g, b].reduce((x, y) => x > y ? x : y);
  final min = [r, g, b].reduce((x, y) => x < y ? x : y);
  final delta = max - min;
  var hue = 0.0;
  if (delta != 0) {
    if (max == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (max == g) {
      hue = 60 * (((b - r) / delta) + 2);
    } else {
      hue = 60 * (((r - g) / delta) + 4);
    }
  }
  if (hue < 0) hue += 360;
  final light = (max + min) / 2;
  final sat = delta == 0 ? 0.0 : delta / (1 - (2 * light - 1).abs());
  return _Tone(hue, sat * 100, light * 100);
}

bool _isDuplicate(List<_Tone> existing, _Tone next) {
  for (final tone in existing) {
    final hueDiff = (tone.h - next.h).abs();
    final wrappedHueDiff = hueDiff > 180 ? 360 - hueDiff : hueDiff;
    if (wrappedHueDiff < 12 &&
        (tone.s - next.s).abs() < 9 &&
        (tone.l - next.l).abs() < 9) {
      return true;
    }
  }
  return false;
}

List<_Tone> _ensureThreeTones(List<_Tone> tones) {
  if (tones.isEmpty) return const [];
  if (tones.length == 1) {
    final base = tones.first;
    return [
      base,
      _Tone((base.h + 24) % 360, (base.s - 4).clamp(0, 100).toDouble(), base.l),
      _Tone((base.h + 338) % 360, (base.s + 3).clamp(0, 100).toDouble(), base.l),
    ];
  }
  if (tones.length == 2) {
    final a = tones[0];
    final b = tones[1];
    return [a, b, _Tone(((a.h + b.h) / 2) % 360, (a.s + b.s) / 2, (a.l + b.l) / 2)];
  }
  return tones.take(3).toList();
}

List<_Tone> _normalizePalette(List<_Tone> tones) {
  final t = _ensureThreeTones(tones);
  final a = t[0];
  final b = t[1];
  final c = t[2];
  return [
    _Tone(a.h, _clamp(a.s + 10, 52, 78), _clamp(a.l + 9, 42, 68)),
    _Tone(b.h, _clamp(b.s + 8, 48, 74), _clamp(b.l + 3, 34, 58)),
    _Tone(c.h, _clamp(c.s + 8, 44, 70), _clamp(c.l - 4, 28, 48)),
  ];
}

double _clamp(double value, double min, double max) {
  if (value < min) return min;
  if (value > max) return max;
  return value;
}

int _seedFrom(String value) {
  var hash = 0;
  for (final code in value.codeUnits) {
    hash = ((hash << 5) - hash + code) & 0x7fffffff;
  }
  return hash.abs();
}

Color _toneHsl(double hue, double sat, double light) {
  return HSLColor.fromAHSL(
    1,
    hue % 360,
    (sat / 100).clamp(0.0, 1.0),
    (light / 100).clamp(0.0, 1.0),
  ).toColor();
}
