import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/services/analytics_service.dart';
import '../../domain/models/playlist_models.dart';
import '../viewmodels/playlist_view_model.dart';

class AddToPlaylistSheet extends StatefulWidget {
  const AddToPlaylistSheet({super.key, required this.videoId, this.videoTitle});

  final String videoId;
  final String? videoTitle;

  @override
  State<AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<AddToPlaylistSheet> {
  String _query = '';
  List<PlaylistSummary> _filtered = [];
  bool _creatingMode = false;
  bool _initialLoading = true;
  final _title = TextEditingController();
  final _description = TextEditingController();
  final Set<String> _addedInSession = <String>{};
  final Set<String> _existingMembership = <String>{};

  void _resetCreateForm() {
    _title.clear();
    _description.clear();
  }

  void _openCreateMode() {
    _resetCreateForm();
    setState(() => _creatingMode = true);
  }

  void _closeCreateMode() {
    _resetCreateForm();
    setState(() => _creatingMode = false);
  }

  Future<void> _hydrateExistingMembership(PlaylistViewModel vm) async {
    final found = <String>{};
    for (final playlist in vm.playlists) {
      try {
        var detail = vm.detail(playlist.playlistId);
        detail ??= await vm.loadPlaylistDetail(playlist.playlistId, silent: true);
        if (detail == null) continue;
        final containsVideo = detail.items.any(
          (item) => item.videoId == widget.videoId,
        );
        if (containsVideo) {
          found.add(playlist.playlistId);
        }
      } catch (_) {
        // Best-effort hydration; do not block sheet rendering.
      }
    }
    if (!mounted) return;
    setState(() {
      _existingMembership
        ..clear()
        ..addAll(found);
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final analytics = context.read<AnalyticsService>();
      await analytics.logEvent(
        context,
        'add_to_playlist_opened',
        parameters: {'video_id': widget.videoId},
      );
      final vm = context.read<PlaylistViewModel>();
      try {
        await vm.loadPlaylists();
        await _hydrateExistingMembership(vm);
        if (!mounted) return;
        setState(() {
          _filtered = vm.playlists;
        });
      } finally {
        if (mounted) {
          setState(() {
            _initialLoading = false;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PlaylistViewModel>();
    final media = MediaQuery.of(context);
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight = media.size.height - media.padding.top;
    final maxHeight = availableHeight * (_creatingMode ? 0.9 : 0.64);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: _creatingMode ? _buildCreate(vm) : _buildPicker(vm),
          ),
        ),
      ),
    );
  }

  Widget _buildPicker(PlaylistViewModel vm) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 390;
    final ctaSize = compact ? 15.0 : 16.0;
    final emptyTitleSize = compact ? 19.0 : 20.0;
    final emptyBodySize = compact ? 13.0 : 14.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 46,
          height: 4,
          decoration: BoxDecoration(
            color: const Color(0xFFE6E6E9),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 10, 8),
          child: Row(
            children: [
              const Spacer(),
              const Text(
                'Save to playlist',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE3E3E7)),
                  ),
                  child: const Icon(Icons.close, color: Color(0xFF606068)),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search, color: Color(0xFF9A9AA1)),
              hintText: 'Search playlists',
              hintStyle: const TextStyle(color: Color(0xFF9A9AA1)),
              filled: true,
              fillColor: const Color(0xFFFAFAFB),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE3E3E7)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFE3E3E7)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFED1C2F)),
              ),
            ),
            onChanged: (value) {
              _query = value;
              vm.debounceSearch(() async {
                if (!mounted) return;
                setState(() => _filtered = vm.filterPlaylists(_query));
                await context.read<AnalyticsService>().logEvent(
                  context,
                  'add_to_playlist_search',
                  parameters: {'query': _query},
                );
              });
            },
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openCreateMode,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFED1C2F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                'New playlist',
                style: TextStyle(
                  fontSize: ctaSize,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'YOUR PLAYLISTS',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF8C8C92),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _initialLoading || (vm.isLoadingList && _filtered.isEmpty)
                ? const _PlaylistPickerShimmer()
                : _filtered.isEmpty
                ? SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE3E3E7)),
                      ),
                      padding: const EdgeInsets.fromLTRB(18, 26, 18, 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: 44,
                            color: Color(0xFF8C8C92),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'No playlists yet',
                            style: TextStyle(
                              fontSize: emptyTitleSize,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF29292E),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Create one with the button above - this video will\nbe added automatically.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: emptyBodySize,
                              height: 1.35,
                              color: Color(0xFF8C8C92),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _filtered[index];
                      final adding = vm.isAddingToPlaylist(item.playlistId);
                      final removing = vm.isRemovingItem(
                        item.playlistId,
                        widget.videoId,
                      );
                      final added =
                          _addedInSession.contains(item.playlistId) ||
                          _existingMembership.contains(item.playlistId);
                      return Material(
                        color: const Color(0xFFFAFAFB),
                        borderRadius: BorderRadius.circular(12),
                        child: ListTile(
                          title: Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            '${item.itemCount ?? 0} video${(item.itemCount ?? 0) == 1 ? '' : 's'}',
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: adding || removing
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : added
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(
                                        0xFFED1C2F,
                                      ).withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.add,
                                    color: Color(0xFFED1C2F),
                                    size: 18,
                                  ),
                                ),
                          onTap: adding || removing
                              ? null
                              : () async {
                                  if (added) {
                                    setState(() {
                                      _addedInSession.remove(item.playlistId);
                                      _existingMembership.remove(item.playlistId);
                                    });
                                    try {
                                      await vm.removeItem(
                                        item.playlistId,
                                        widget.videoId,
                                      );
                                      if (!mounted) return;
                                      await context
                                          .read<AnalyticsService>()
                                          .logEvent(
                                            context,
                                            'playlist_item_removed',
                                            parameters: {
                                              'playlist_id': item.playlistId,
                                              'video_id': widget.videoId,
                                              'source': 'watch',
                                            },
                                          );
                                    } catch (_) {
                                      if (!mounted) return;
                                      // Rollback optimistic removal on failure.
                                      setState(() {
                                        _existingMembership.add(item.playlistId);
                                      });
                                    }
                                  } else {
                                    setState(
                                      () => _addedInSession.add(item.playlistId),
                                    );
                                    try {
                                      await vm.addToPlaylist(
                                        item.playlistId,
                                        widget.videoId,
                                      );
                                      if (!mounted) return;
                                      await context
                                          .read<AnalyticsService>()
                                          .logEvent(
                                            context,
                                            'playlist_item_added',
                                            parameters: {
                                              'playlist_id': item.playlistId,
                                              'video_id': widget.videoId,
                                              'source': 'watch',
                                            },
                                          );
                                    } catch (_) {
                                      if (!mounted) return;
                                      // Rollback optimistic add on failure.
                                      setState(() {
                                        _addedInSession.remove(item.playlistId);
                                      });
                                    }
                                  }
                                },
                        ),
                      );
                    },
                  ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE7E7EB))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              const Spacer(),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFED1C2F),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Done',
                  style: TextStyle(fontSize: compact ? 16 : 17),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCreate(PlaylistViewModel vm) {
    final canCreate = _title.text.trim().isNotEmpty && !vm.isCreating;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 46,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E6E9),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
          child: Row(
            children: [
              IconButton(
                onPressed: _closeCreateMode,
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: Color(0xFF66666E),
                ),
              ),
              const Text(
                'New playlist',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              InkWell(
                onTap: () {
                  _resetCreateForm();
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE3E3E7)),
                  ),
                  child: const Icon(Icons.close, color: Color(0xFF606068)),
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
          child: Text(
            'This video becomes the first item. Add more\nanytime from any watch page.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF595961),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFE7E7EB)),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              16,
              14,
              16,
              12 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'TITLE',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A7A82),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _title,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'e.g. Late night listens',
                    hintStyle: const TextStyle(color: Color(0xFF97979E)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE3E3E7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE3E3E7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFED1C2F)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'DESCRIPTION  (optional)',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A7A82),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _description,
                  minLines: 1,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'What\'s this list for?',
                    hintStyle: const TextStyle(color: Color(0xFF97979E)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE3E3E7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFE3E3E7)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFFED1C2F)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: canCreate
                        ? () async {
                            final detail = await vm.createPlaylist(
                              title: _title.text.trim(),
                              description: _description.text.trim(),
                              videoId: widget.videoId,
                            );
                            if (!mounted) return;
                            try {
                              await context.read<AnalyticsService>().logEvent(
                                context,
                                'playlist_created',
                                parameters: {
                                  'playlist_id': detail.playlistId,
                                  'video_id': widget.videoId,
                                  'source': 'watch',
                                },
                              );
                            } catch (_) {
                              // Analytics must not interrupt the add-to-playlist flow.
                            }

                            if (!mounted) return;
                            await vm.loadPlaylists();
                            if (!mounted) return;
                            final refreshed = vm.filterPlaylists(_query);
                            setState(() {
                              _addedInSession.add(detail.playlistId);
                              _filtered = refreshed;
                              _creatingMode = false;
                            });
                            _resetCreateForm();
                          }
                        : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFED1C2F),
                      disabledBackgroundColor: const Color(0xFFF4A2AC),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: vm.isCreating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.add, size: 20),
                    label: Text(
                      vm.isCreating ? 'Creating...' : 'Create playlist',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFE7E7EB))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: _closeCreateMode,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5D5D65),
                  side: const BorderSide(color: Color(0xFFE3E3E7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(78, 38),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaylistPickerShimmer extends StatelessWidget {
  const _PlaylistPickerShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE7E7EA),
      highlightColor: const Color(0xFFF7F7FA),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => Container(
          height: 62,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
