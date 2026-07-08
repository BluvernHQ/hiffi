import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// General shimmer loading widget
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Shimmer for user profile page — mirrors banner, avatar overlap, stats, and videos.
class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});

  static const _pageBackground = Color(0xFFFAFAFA);
  static const _avatarRadius = 40.0;
  static const _bone = Colors.white;

  static double _bannerHeightFor(double width) {
    if (width >= 1024) return 256;
    if (width >= 768) return 192;
    if (width >= 640) return 160;
    return 128;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final bannerHeight = _bannerHeightFor(width);
    const avatarSize = _avatarRadius * 2;

    return ColoredBox(
      color: _pageBackground,
      child: Shimmer.fromColors(
        baseColor: const Color(0xFFE6E6E6),
        highlightColor: const Color(0xFFF8F8F8),
        period: const Duration(milliseconds: 1100),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: bannerHeight + _avatarRadius,
                width: double.infinity,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: bannerHeight,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(color: _bone),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: bannerHeight - _avatarRadius,
                      child: Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          color: _bone,
                          shape: BoxShape.circle,
                          border: Border.all(color: _pageBackground, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _boneBox(width: width * 0.55, height: 22, radius: 6),
                    const SizedBox(height: 10),
                    _boneBox(width: 108, height: 14, radius: 4),
                    const SizedBox(height: 10),
                    _boneBox(width: 132, height: 12, radius: 4),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _boneBox(height: 44, radius: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _boneBox(height: 44, radius: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _boneBox(
                      width: double.infinity,
                      height: 76,
                      radius: 16,
                      border: const Border.fromBorderSide(
                        BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _boneBox(
                      width: double.infinity,
                      height: 96,
                      radius: 16,
                      border: const Border.fromBorderSide(
                        BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _boneBox(width: 120, height: 16, radius: 4),
                    const SizedBox(height: 12),
                    _boneBox(
                      width: double.infinity,
                      height: 148,
                      radius: 16,
                      border: const Border.fromBorderSide(
                        BorderSide(color: Color(0xFFE8E8E8)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 112,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (_, __) => _boneBox(
                          width: 200,
                          height: 112,
                          radius: 12,
                        ),
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
  }

  static Widget _boneBox({
    double? width,
    required double height,
    double radius = 8,
    BoxBorder? border,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _bone,
        borderRadius: BorderRadius.circular(radius),
        border: border,
      ),
    );
  }
}

/// Shimmer for video card in grid/list
class VideoCardShimmer extends StatelessWidget {
  final bool isGrid;

  const VideoCardShimmer({super.key, this.isGrid = true});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Title
            Container(
              width: double.infinity,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            // Username and views
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton row matching [History] list tiles (thumb + title + meta).
class _HistoryListRowPlaceholder extends StatelessWidget {
  const _HistoryListRowPlaceholder({required this.maxWidth});

  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final thumbW = (maxWidth * 0.40).clamp(132.0, 220.0);
    final thumbH = thumbW * 9 / 16;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: thumbW,
            height: thumbH,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: maxWidth * 0.42,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shimmer placeholder for the History screen (list rows + optional section header).
class HistoryListShimmer extends StatelessWidget {
  const HistoryListShimmer({super.key, this.itemCount = 8});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    height: 16,
                    width: w * 0.22,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ),
              ),
              ...List.generate(
                itemCount,
                (_) => _HistoryListRowPlaceholder(maxWidth: w),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Compact shimmer for history pagination (single row silhouette).
class HistoryPaginationShimmer extends StatelessWidget {
  const HistoryPaginationShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: _HistoryListRowPlaceholder(maxWidth: constraints.maxWidth),
        );
      },
    );
  }
}

/// Shimmer for video list loading
class VideoListShimmer extends StatelessWidget {
  final int itemCount;
  final bool isGrid;

  const VideoListShimmer({super.key, this.itemCount = 6, this.isGrid = true});

  @override
  Widget build(BuildContext context) {
    if (isGrid) {
      return GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: itemCount,
        itemBuilder: (context, index) => const VideoCardShimmer(),
      );
    } else {
      return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: itemCount,
        itemBuilder: (context, index) => const VideoCardShimmer(isGrid: false),
      );
    }
  }
}

/// Shimmer for the video player horizontal suggested-videos strip (matches card width/layout).
class SuggestedVideosStripShimmer extends StatelessWidget {
  const SuggestedVideosStripShimmer({super.key, this.cardCount = 5});

  final int cardCount;

  static const double _cardWidth = 160;
  /// Matches suggested video card column height (no extra dead space under cards).
  static const double _stripHeight = 168;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 22,
            width: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: _stripHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: cardCount,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, __) => SizedBox(
                width: _cardWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: _cardWidth - 8,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 14,
                      width: _cardWidth - 28,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small shimmer for inline loading (buttons, etc.)
class InlineShimmer extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const InlineShimmer({
    super.key,
    this.width = 20,
    this.height = 20,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: borderRadius ?? BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// Shimmer for video player placeholder
class VideoPlayerShimmer extends StatelessWidget {
  const VideoPlayerShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[900]!,
      highlightColor: Colors.grey[700]!,
      child: Container(
        width: double.infinity,
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
