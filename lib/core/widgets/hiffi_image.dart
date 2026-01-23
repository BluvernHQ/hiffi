import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hiffi/core/utils/image_utils.dart';
import 'package:shimmer/shimmer.dart';

/// A wrapper around [CachedNetworkImage] that automatically injects
/// the required authentication headers for Hiffi media assets.
class HiffiImage extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;
  final ShapeBorder? shape;

  const HiffiImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
    this.shape,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return errorWidget ?? _buildErrorWidget();
    }

    final headers = ImageUtils.getProfileImageHeaders(imageUrl);

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: headers,
      placeholder: (context, url) => placeholder ?? _buildDefaultPlaceholder(),
      errorWidget: (context, url, error) => errorWidget ?? _buildErrorWidget(),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }

    if (shape != null) {
      if (shape is CircleBorder) {
        return ClipOval(child: image);
      }
      // Handle other shapes if needed
    }

    return image;
  }

  Widget _buildDefaultPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: borderRadius,
          shape: shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: borderRadius,
        shape: shape is CircleBorder ? BoxShape.circle : BoxShape.rectangle,
      ),
      child: const Icon(Icons.error_outline, color: Colors.grey),
    );
  }
}

/// A specialized version of [HiffiImage] for circular avatars.
class HiffiAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final String? fallbackText;
  final int? cacheBust;

  const HiffiAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.fallbackText,
    this.cacheBust,
  });

  @override
  Widget build(BuildContext context) {
    // Trim and validate the URL
    final trimmedUrl =
        imageUrl != null &&
            imageUrl!.trim().isNotEmpty &&
            imageUrl!.trim().toLowerCase() != 'null'
        ? imageUrl!.trim()
        : null;

    final processedUrl = trimmedUrl != null
        ? ImageUtils.getProfileImageUrl(trimmedUrl, cacheBust: cacheBust)
        : null;

    if (trimmedUrl != null && processedUrl == null) {
      debugPrint(
        'HiffiAvatar: profilePicture "$imageUrl" was filtered out as invalid',
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B35).withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: processedUrl != null
          ? HiffiImage(
              imageUrl: processedUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              shape: const CircleBorder(),
              errorWidget: _buildFallback(),
              placeholder: _buildPlaceholder(),
            )
          : _buildFallback(),
    );
  }

  Widget _buildFallback() {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Center(
        child: Text(
          fallbackText![0].toUpperCase(),
          style: TextStyle(
            color: const Color(0xFFFF6B35),
            fontWeight: FontWeight.bold,
            fontSize: size * 0.4,
          ),
        ),
      );
    }
    return Icon(Icons.person, size: size * 0.6, color: const Color(0xFFFF6B35));
  }

  Widget _buildPlaceholder() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
