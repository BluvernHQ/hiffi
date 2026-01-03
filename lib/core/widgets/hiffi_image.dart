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
      debugPrint('HiffiImage: imageUrl is null or empty');
      return errorWidget ?? _buildErrorWidget();
    }

    final headers = ImageUtils.getProfileImageHeaders(imageUrl);
    debugPrint(
      'HiffiImage loading: $imageUrl (headers: ${headers != null ? "present (x-api-key: ${headers['x-api-key']?.substring(0, 5)}...)" : "none"})',
    );

    Widget image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      httpHeaders: headers,
      placeholder: (context, url) {
        debugPrint('HiffiImage placeholder for: $url');
        return placeholder ?? _buildDefaultPlaceholder();
      },
      errorWidget: (context, url, error) {
        debugPrint('HiffiImage ERROR loading $url: $error');
        debugPrint('HiffiImage ERROR type: ${error.runtimeType}');
        // Always use the provided errorWidget if available, otherwise use default
        return errorWidget ?? _buildErrorWidget();
      },
      errorListener: (error) {
        debugPrint('HiffiImage errorListener: $error');
      },
      // Note: Cannot use both placeholder and progressIndicatorBuilder simultaneously
      // Using placeholder only - it handles both initial loading and progress states
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

  const HiffiAvatar({
    super.key,
    required this.imageUrl,
    this.size = 40,
    this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    // Debug: Log the raw input
    debugPrint(
      'HiffiAvatar: Raw imageUrl received: "$imageUrl" (type: ${imageUrl.runtimeType}, isEmpty: ${imageUrl?.isEmpty ?? true})',
    );

    // Trim and validate the URL
    final trimmedUrl = imageUrl != null && imageUrl!.trim().isNotEmpty
        ? imageUrl!.trim()
        : null;

    if (trimmedUrl == null) {
      debugPrint(
        'HiffiAvatar: No valid URL provided, showing fallback for: ${fallbackText ?? "unknown"}',
      );
    }

    final processedUrl = trimmedUrl != null
        ? ImageUtils.getProfileImageUrl(trimmedUrl)
        : null;

    // Debug print to help diagnose issues
    if (trimmedUrl != null) {
      if (processedUrl == null) {
        debugPrint(
          'HiffiAvatar: ❌ Profile image URL was filtered out or invalid: "$trimmedUrl"',
        );
        debugPrint(
          'HiffiAvatar: isValidImageUrl check: ${ImageUtils.isValidImageUrl(trimmedUrl)}',
        );
      } else {
        debugPrint(
          'HiffiAvatar: ✅ Processing profile image - Original: "$trimmedUrl" → Processed: "$processedUrl"',
        );
      }
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
