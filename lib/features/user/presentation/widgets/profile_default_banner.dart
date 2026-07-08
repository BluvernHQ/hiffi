import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/profile_banner_theme.dart';

class ProfileDefaultBanner extends StatelessWidget {
  const ProfileDefaultBanner({
    super.key,
    required this.displayName,
    this.username,
    required this.height,
    this.fadeBackground = const Color(0xFFFAFAFA),
  });

  final String displayName;
  final String? username;
  final double height;
  final Color fadeBackground;

  @override
  Widget build(BuildContext context) {
    final name = displayName.trim().isEmpty
        ? (username?.trim().isNotEmpty == true ? username!.trim() : 'Artist')
        : displayName.trim();
    final theme = getBannerTheme(name, username);
    final palette = theme.palette;
    final formatted = formatBannerName(name);
    final handle = username?.trim().isNotEmpty == true
        ? '@${username!.trim().toLowerCase()}'
        : null;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: palette.baseBegin,
                  end: palette.baseEnd,
                  colors: palette.baseColors,
                ),
              ),
            ),
            _RadialGlowLayer(
              glowColor: palette.glow,
              centerX: palette.glowX,
              centerY: -0.05,
              scaleX: 0.85,
              scaleY: 1.1,
              stop: 0.58,
            ),
            _RadialGlowLayer(
              glowColor: palette.accentMuted.withValues(alpha: 0.4),
              centerX: theme.glowSideRight ? 0.12 : 0.88,
              centerY: 0.9,
              scaleX: 0.5,
              scaleY: 0.6,
              stop: 0.5,
            ),
            _BannerSoundWave(
              theme: theme,
              palette: palette,
              height: height,
            ),
            Positioned(
              right: 12,
              top: height * 0.08,
              child: _WatermarkText(
                text: formatted.primary.toUpperCase(),
                color: palette.watermark,
                height: height,
              ),
            ),
            if (handle != null || formatted.primary.isNotEmpty)
              Positioned(
                right: 14,
                top: height * 0.22,
                left: height * 0.38,
                child: _HeroArtistName(
                  handle: handle,
                  primary: formatted.primary,
                  secondary: formatted.secondary,
                  palette: palette,
                  height: height,
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
                      fadeBackground,
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
              height: height * 0.46,
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
      ),
    );
  }
}

class _RadialGlowLayer extends StatelessWidget {
  const _RadialGlowLayer({
    required this.glowColor,
    required this.centerX,
    required this.centerY,
    required this.scaleX,
    required this.scaleY,
    required this.stop,
  });

  final Color glowColor;
  final double centerX;
  final double centerY;
  final double scaleX;
  final double scaleY;
  final double stop;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Transform.scale(
        scaleX: scaleX,
        scaleY: scaleY,
        alignment: Alignment(centerX * 2 - 1, centerY * 2 - 1),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(centerX * 2 - 1, centerY * 2 - 1),
              radius: 1,
              colors: [glowColor, glowColor.withValues(alpha: 0)],
              stops: [0, stop],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerSoundWave extends StatelessWidget {
  const _BannerSoundWave({
    required this.theme,
    required this.palette,
    required this.height,
  });

  final BannerTheme theme;
  final BannerPalette palette;
  final double height;

  static const _barCount = 18;
  static const _barWidth = 5.0;
  static const _barGap = 3.5;

  @override
  Widget build(BuildContext context) {
    final heights = waveBarHeights(theme.waveSeed, _barCount);
    final maxBarHeight = height * 0.52;
    final waveWidth = math.min(
      MediaQuery.sizeOf(context).width * 0.48,
      220.0,
    );

    return Positioned(
      bottom: height * 0.08,
      right: theme.glowSideRight ? 10 : null,
      left: theme.glowSideRight ? null : MediaQuery.sizeOf(context).width * 0.4,
      child: SizedBox(
        width: waveWidth,
        height: maxBarHeight,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            for (var i = 0; i < _barCount; i++) ...[
              if (i > 0) const SizedBox(width: _barGap),
              Container(
                width: _barWidth,
                height: maxBarHeight * heights[i],
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(1.5),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      palette.accent.withValues(alpha: 0.35),
                      palette.accent.withValues(alpha: 0.03),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WatermarkText extends StatelessWidget {
  const _WatermarkText({
    required this.text,
    required this.color,
    required this.height,
  });

  final String text;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fontSize = (height * 0.42).clamp(28.0, 72.0);
    return Text(
      text,
      textAlign: TextAlign.right,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: color,
        height: 0.9,
      ),
    );
  }
}

class _HeroArtistName extends StatelessWidget {
  const _HeroArtistName({
    required this.handle,
    required this.primary,
    required this.secondary,
    required this.palette,
    required this.height,
  });

  final String? handle;
  final String primary;
  final String? secondary;
  final BannerPalette palette;
  final double height;

  @override
  Widget build(BuildContext context) {
    final primarySize = (height * 0.18).clamp(18.0, 36.0);
    final secondarySize = primarySize * 0.72;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (handle != null)
          Text(
            handle!,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: palette.accent.withValues(alpha: 0.72),
            ),
          ),
        if (handle != null) const SizedBox(height: 4),
        ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            colors: palette.nameGradient,
          ).createShader(bounds),
          child: Text(
            primary.toUpperCase(),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: primarySize,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (secondary != null) ...[
          const SizedBox(height: 2),
          Text(
            secondary!,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: secondarySize,
              fontWeight: FontWeight.w600,
              color: palette.secondaryColor,
            ),
          ),
        ],
      ],
    );
  }
}
