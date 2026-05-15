import 'package:flutter/material.dart';
import 'package:hiffi/core/utils/image_utils.dart';

/// Video thumbnail with network load, or a faded [HiffiLogo] when missing / failed.
class HiffiVideoThumbnail extends StatelessWidget {
  const HiffiVideoThumbnail({
    super.key,
    this.thumbnailPath,
    this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.backgroundColor,
    this.logoOpacity = 0.28,
    this.showLoadingIndicator = true,
  }) : assert(
         thumbnailPath == null || imageUrl == null,
         'Provide thumbnailPath or imageUrl, not both',
       );

  /// Raw `video_thumbnail` from the API (resolved via [ImageUtils]).
  final String? thumbnailPath;

  /// Pre-resolved full URL; takes precedence over [thumbnailPath].
  final String? imageUrl;

  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final double logoOpacity;
  final bool showLoadingIndicator;

  String? _resolvedUrl() {
    if (imageUrl != null && imageUrl!.trim().isNotEmpty) {
      return imageUrl!.trim();
    }
    return ImageUtils.getVideoThumbnailUrl(thumbnailPath);
  }

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl();
    final bg = backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget child;
    if (url == null || url.isEmpty) {
      child = placeholder(
        context,
        backgroundColor: bg,
        logoOpacity: logoOpacity,
      );
    } else {
      child = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        headers: ImageUtils.getVideoThumbnailHeaders(),
        errorBuilder: (_, __, ___) => placeholder(
          context,
          backgroundColor: bg,
          logoOpacity: logoOpacity,
        ),
        loadingBuilder: showLoadingIndicator
            ? (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return placeholder(
                  context,
                  backgroundColor: bg,
                  logoOpacity: logoOpacity * 0.6,
                );
              }
            : null,
      );
    }

    if (width != null || height != null) {
      child = SizedBox(width: width, height: height, child: child);
    }

    if (borderRadius != null) {
      child = ClipRRect(borderRadius: borderRadius!, child: child);
    }

    return child;
  }

  /// Faded logo centered on a neutral thumbnail background.
  static Widget placeholder(
    BuildContext context, {
    Color? backgroundColor,
    double logoOpacity = 0.28,
    BorderRadius? borderRadius,
  }) {
    final bg = backgroundColor ??
        Theme.of(context).colorScheme.surfaceContainerHighest;

    Widget content = ColoredBox(
      color: bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final finiteW = w.isFinite && w > 0;
          final finiteH = h.isFinite && h > 0;
          final minSide = finiteW && finiteH
              ? (w < h ? w : h)
              : (finiteW ? w : (finiteH ? h : 120.0));
          final logoSize = (minSide * 0.42).clamp(28.0, 96.0);

          return Center(
            child: Opacity(
              opacity: logoOpacity,
              child: Image.asset(
                'assets/appbarlogo.png',
                height: logoSize,
                fit: BoxFit.contain,
              ),
            ),
          );
        },
      ),
    );

    final radius = borderRadius;
    if (radius != null) {
      content = ClipRRect(borderRadius: radius, child: content);
    }

    return content;
  }
}
