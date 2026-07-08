import 'package:flutter/material.dart';

import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/hiffi_image.dart';
import '../../domain/profile_banner_theme.dart';
import 'profile_default_banner.dart';

/// Cover banner: custom image when [coverUrl] is set, otherwise procedural default.
class ProfileCoverBanner extends StatelessWidget {
  const ProfileCoverBanner({
    super.key,
    this.coverUrl,
    this.coverAlt = '',
    required this.displayName,
    this.username,
    this.height,
    this.fadeBackground = const Color(0xFFFAFAFA),
  });

  final String? coverUrl;
  final String coverAlt;
  final String displayName;
  final String? username;
  final double? height;
  final Color fadeBackground;

  @override
  Widget build(BuildContext context) {
    final resolvedHeight =
        height ?? profileBannerHeightForWidth(MediaQuery.sizeOf(context).width);
    final resolvedCover = ImageUtils.getCoverImageUrl(coverUrl);

    if (resolvedCover != null && resolvedCover.isNotEmpty) {
      return SizedBox(
        height: resolvedHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            HiffiImage(
              imageUrl: resolvedCover,
              fit: BoxFit.cover,
              width: double.infinity,
              height: resolvedHeight,
              errorWidget: ProfileDefaultBanner(
                displayName: displayName,
                username: username,
                height: resolvedHeight,
                fadeBackground: fadeBackground,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: MediaQuery.sizeOf(context).width * 0.42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      fadeBackground.withValues(alpha: 0.85),
                      fadeBackground.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: resolvedHeight * 0.46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      fadeBackground,
                      fadeBackground.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ProfileDefaultBanner(
      displayName: displayName,
      username: username,
      height: resolvedHeight,
      fadeBackground: fadeBackground,
    );
  }
}
