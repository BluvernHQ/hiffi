import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';

import '../../../../core/utils/compact_count.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../../../core/widgets/shimmer_widgets.dart';
import '../../domain/models/video_model.dart';

class VideoPlayerMetadataSection extends StatelessWidget {
  const VideoPlayerMetadataSection({
    super.key,
    required this.video,
    required this.isUpvoted,
    required this.upvoteCount,
    required this.isFollowing,
    required this.isLoadingFollowStatus,
    required this.showFollowButton,
    required this.isDescriptionExpanded,
    required this.formatCount,
    required this.onToggleLike,
    required this.onAddToPlaylist,
    required this.onShare,
    required this.onCreatorTap,
    required this.onFollow,
    required this.onToggleDescription,
    required this.onOpenDescriptionLink,
  });

  final VideoModel video;
  final bool isUpvoted;
  final int upvoteCount;
  final bool isFollowing;
  final bool isLoadingFollowStatus;
  final bool showFollowButton;
  final bool isDescriptionExpanded;
  final String Function(int count) formatCount;
  final VoidCallback onToggleLike;
  final VoidCallback onAddToPlaylist;
  final VoidCallback onShare;
  final VoidCallback onCreatorTap;
  final VoidCallback onFollow;
  final VoidCallback onToggleDescription;
  final Future<void> Function(String url) onOpenDescriptionLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.videoTitle,
                          style: const TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (shouldShowEngagementCount(video.videoViews)) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${formatCount(video.videoViews)} views',
                            style: const TextStyle(
                              color: Color(0xFF6B6B6B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onToggleLike,
                          borderRadius: BorderRadius.circular(22),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isUpvoted
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 22,
                                  color: isUpvoted
                                      ? const Color(0xFFED1C2F)
                                      : const Color(0xFF6B6B6B),
                                ),
                                if (shouldShowEngagementCount(upvoteCount)) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    formatCount(upvoteCount),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isUpvoted
                                          ? const Color(0xFFED1C2F)
                                          : const Color(0xFF6B6B6B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.bookmark_border),
                        color: const Color(0xFF6B6B6B),
                        tooltip: 'Save to playlist',
                        onPressed: onAddToPlaylist,
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        color: const Color(0xFF6B6B6B),
                        tooltip: 'Share',
                        onPressed: onShare,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onCreatorTap,
                child: HiffiAvatar(
                  imageUrl: video.profilePicture,
                  size: 40,
                  fallbackText: video.userUsername,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onCreatorTap,
                    child: Text(
                      video.userUsername.isNotEmpty
                          ? video.userUsername
                          : 'Unknown User',
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              if (showFollowButton)
                isLoadingFollowStatus
                    ? const InlineShimmer(width: 16, height: 16)
                    : ElevatedButton(
                        onPressed: onFollow,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? const Color(0xFFF5F5F5)
                              : const Color(0xFFED1C2F),
                          foregroundColor:
                              isFollowing ? Colors.black87 : Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          minimumSize: const Size(0, 36),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
            ],
          ),
        ),
        if (video.videoDescription.isNotEmpty || video.videoTags.isNotEmpty)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (video.videoDescription.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Linkify(
                        text: video.videoDescription,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          height: 1.5,
                        ),
                        linkStyle: const TextStyle(
                          color: Color(0xFFED1C2F),
                          fontSize: 14,
                          height: 1.5,
                          decoration: TextDecoration.underline,
                          decorationColor: Color(0xFFED1C2F),
                        ),
                        options: const LinkifyOptions(
                          humanize: false,
                          removeWww: false,
                        ),
                        onOpen: (link) => onOpenDescriptionLink(link.url),
                        maxLines: isDescriptionExpanded ? null : 2,
                        overflow: isDescriptionExpanded
                            ? null
                            : TextOverflow.ellipsis,
                      ),
                      if (video.videoDescription.length > 100)
                        TextButton(
                          onPressed: onToggleDescription,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 28),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isDescriptionExpanded ? 'Show less' : 'Show more',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFFED1C2F),
                            ),
                          ),
                        ),
                    ],
                  ),
                if (video.videoTags.isNotEmpty) ...[
                  if (video.videoDescription.isNotEmpty)
                    const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: video.videoTags
                        .map(
                          (tag) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFED1C2F).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFED1C2F).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFED1C2F),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
