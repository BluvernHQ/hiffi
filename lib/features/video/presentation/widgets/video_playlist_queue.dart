import 'package:flutter/material.dart';

import '../../../../core/widgets/hiffi_video_thumbnail.dart';
import '../../../playlist/domain/models/playlist_models.dart';
import '../../domain/models/video_model.dart';

const int kActivePlaylistVisibleItemsDefault = 3;
const double kActivePlaylistRowHeightBase = 56;
const double kActivePlaylistRowGapBase = 6;

class VideoPlaylistQueue extends StatelessWidget {
  const VideoPlaylistQueue({
    required this.session,
    required this.currentVideoId,
    required this.videoLookup,
    required this.onTapItem,
    this.isOffline = false,
  });

  final PlaylistSession session;
  final String currentVideoId;
  final Map<String, VideoModel> videoLookup;
  final void Function(String videoId, int index) onTapItem;
  final bool isOffline;

  @override
  Widget build(BuildContext context) {
    final resolvedCurrentIndex = session.videoIds.indexOf(currentVideoId);
    final activeIndex = resolvedCurrentIndex >= 0
        ? resolvedCurrentIndex
        : session.currentIndex.clamp(0, session.videoIds.length - 1);

    if (isOffline) {
      return _buildOfflineQueue(context, activeIndex);
    }

    final mediaQuery = MediaQuery.of(context);
    final shortestSide = mediaQuery.size.shortestSide;
    final textScale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, 1.15).toDouble();
    final visibleItemsCap = shortestSide < 360
        ? 2
        : kActivePlaylistVisibleItemsDefault;
    final rowHeight = (kActivePlaylistRowHeightBase * textScale).clamp(
      56.0,
      66.0,
    );
    final rowGap = shortestSide < 360 ? 4.0 : kActivePlaylistRowGapBase;

    final queueEntries = session.videoIds.asMap().entries.toList();
    final visibleRows = queueEntries.length < visibleItemsCap
        ? queueEntries.length
        : visibleItemsCap;
    final queueHeight =
        (visibleRows * rowHeight) + ((visibleRows - 1) * rowGap);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFFFF8F9),
          border: Border.all(color: const Color(0xFFF4C8CE)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'ACTIVE PLAYLIST',
                  style: TextStyle(
                    color: Color(0xFFED1C2F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6E6EB)),
                  ),
                  child: Text(
                    '${activeIndex + 1}/${session.videoIds.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B6B6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              session.title ?? 'Playlist',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: queueHeight,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                primary: false,
                itemCount: queueEntries.length,
                physics: queueEntries.length > visibleItemsCap
                    ? const BouncingScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemBuilder: (context, rowIndex) {
                  final index = queueEntries[rowIndex].key;
                  final id = queueEntries[rowIndex].value;
                  final isCurrent = id == currentVideoId;
                  final isImmediateNext = index == activeIndex + 1;
                  final label = isCurrent
                      ? 'Now playing'
                      : isImmediateNext
                      ? 'Up next'
                      : '';
                  return SizedBox(
                    height: rowHeight,
                    child: InkWell(
                      onTap: () => onTapItem(id, index),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? const Color(0xFFFFEEF1)
                              : const Color(0xFFF3F3F6),
                          borderRadius: BorderRadius.circular(10),
                          border: isCurrent
                              ? Border.all(color: const Color(0xFFF2B2BC))
                              : null,
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: SizedBox(
                                width: 56,
                                height: 32,
                                child: _queueThumb(id),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _queueTitle(id),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isCurrent
                                          ? const Color(0xFFB54558)
                                          : const Color(0xFF6B6B6B),
                                      fontWeight: isCurrent
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => SizedBox(height: rowGap),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineQueue(BuildContext context, int activeIndex) {
    final total = session.videoIds.length;
    final remaining = total > 1 ? total - 1 : 0;
    final title = _queueTitle(currentVideoId);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFFFFF8F9),
          border: Border.all(color: const Color(0xFFF4C8CE)),
        ),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'ACTIVE PLAYLIST',
                  style: TextStyle(
                    color: Color(0xFFED1C2F),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFFE6E6EB)),
                  ),
                  child: Text(
                    '${activeIndex + 1} of $total',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B6B6B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              session.title ?? 'Playlist',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEF1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF2B2BC)),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: SizedBox(
                      width: 56,
                      height: 32,
                      child: _queueThumb(currentVideoId),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Now playing',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFB54558),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (remaining > 0) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE6E6EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        remaining == 1
                            ? '1 more video in this playlist will appear when you\'re back online.'
                            : '$remaining more videos in this playlist will appear when you\'re back online.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _queueThumb(String id) {
    return HiffiVideoThumbnail(
      thumbnailPath: videoLookup[id]?.videoThumbnail,
      fit: BoxFit.cover,
      backgroundColor: const Color(0xFFE8E8EB),
    );
  }

  String _queueTitle(String id) {
    final title = videoLookup[id]?.videoTitle ?? '';
    final trimmed = title.trim();
    if (trimmed.isNotEmpty && trimmed.toLowerCase() != 'video') {
      return trimmed;
    }
    return 'Loading…';
  }
}
