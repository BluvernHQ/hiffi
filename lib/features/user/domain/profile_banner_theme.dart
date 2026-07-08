import 'dart:math' as math;

import 'package:flutter/material.dart';

const hiffiRed = Color(0xFFE8192C);
const hiffiBlack = Color(0xFF171717);

/// Deterministic banner palette — same identity always yields the same theme.
class BannerPalette {
  const BannerPalette({
    required this.baseColors,
    required this.baseBegin,
    required this.baseEnd,
    required this.glow,
    required this.glowX,
    required this.accent,
    required this.accentMuted,
    required this.secondaryColor,
    required this.watermark,
    required this.nameGradient,
  });

  final List<Color> baseColors;
  final Alignment baseBegin;
  final Alignment baseEnd;
  final Color glow;
  final double glowX;
  final Color accent;
  final Color accentMuted;
  final Color secondaryColor;
  final Color watermark;
  final List<Color> nameGradient;
}

class BannerTheme {
  const BannerTheme({
    required this.palette,
    required this.glowSideRight,
    required this.waveSeed,
  });

  final BannerPalette palette;
  final bool glowSideRight;
  final int waveSeed;
}

const _palettes = <BannerPalette>[
  BannerPalette(
    baseColors: [Color(0xFFFFF8F5), Color(0xFFFFEDE8)],
    baseBegin: Alignment.topLeft,
    baseEnd: Alignment.bottomRight,
    glow: Color(0x40E8192C),
    glowX: 0.82,
    accent: hiffiRed,
    accentMuted: Color(0x66FF4D5E),
    secondaryColor: Color(0xFF6B4A4E),
    watermark: Color(0x12E8192C),
    nameGradient: [hiffiBlack, Color(0xFF4A4A4A), hiffiRed],
  ),
  BannerPalette(
    baseColors: [Color(0xFFFFF5F0), Color(0xFFFFE4DC)],
    baseBegin: Alignment.topCenter,
    baseEnd: Alignment.bottomCenter,
    glow: Color(0x38E8192C),
    glowX: 0.18,
    accent: hiffiRed,
    accentMuted: Color(0x55FF6B7A),
    secondaryColor: Color(0xFF5C4548),
    watermark: Color(0x10E8192C),
    nameGradient: [hiffiBlack, Color(0xFF525252), Color(0xFFC41E2E)],
  ),
  BannerPalette(
    baseColors: [Color(0xFFFFF9F6), Color(0xFFFFF0EB)],
    baseBegin: Alignment.centerLeft,
    baseEnd: Alignment.centerRight,
    glow: Color(0x42E8192C),
    glowX: 0.78,
    accent: Color(0xFFD41426),
    accentMuted: Color(0x60FF808C),
    secondaryColor: Color(0xFF704F52),
    watermark: Color(0x0FE8192C),
    nameGradient: [hiffiBlack, Color(0xFF3D3D3D), hiffiRed],
  ),
  BannerPalette(
    baseColors: [Color(0xFFFFFAF8), Color(0xFFFFE8E3)],
    baseBegin: Alignment.topRight,
    baseEnd: Alignment.bottomLeft,
    glow: Color(0x36E8192C),
    glowX: 0.22,
    accent: hiffiRed,
    accentMuted: Color(0x4DFF5C6C),
    secondaryColor: Color(0xFF624548),
    watermark: Color(0x11E8192C),
    nameGradient: [Color(0xFF1A1A1A), Color(0xFF5C5C5C), Color(0xFFE8192C)],
  ),
  BannerPalette(
    baseColors: [Color(0xFFFFF7F4), Color(0xFFFFE6E0)],
    baseBegin: Alignment.topLeft,
    baseEnd: Alignment.bottomRight,
    glow: Color(0x3EE8192C),
    glowX: 0.85,
    accent: Color(0xFFEB1A2D),
    accentMuted: Color(0x58FF707E),
    secondaryColor: Color(0xFF6E5053),
    watermark: Color(0x0EE8192C),
    nameGradient: [hiffiBlack, Color(0xFF454545), hiffiRed],
  ),
  BannerPalette(
    baseColors: [Color(0xFFFFFBF9), Color(0xFFFFEFE9)],
    baseBegin: Alignment.bottomLeft,
    baseEnd: Alignment.topRight,
    glow: Color(0x34E8192C),
    glowX: 0.15,
    accent: hiffiRed,
    accentMuted: Color(0x52FF6270),
    secondaryColor: Color(0xFF5A4245),
    watermark: Color(0x10E8192C),
    nameGradient: [hiffiBlack, Color(0xFF505050), Color(0xFFCC1829)],
  ),
];

String profileBannerKey(String displayName, String? username) {
  final name = displayName.trim().toLowerCase();
  final normalizedName = name.isEmpty ? 'artist' : name;
  final handle = username?.trim().toLowerCase() ?? '';
  return handle.isNotEmpty ? '$handle::$normalizedName' : normalizedName;
}

/// djb2-style hash — matches web `hashString` behavior for palette selection.
int hashString(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash + unit) & 0x7fffffff;
  }
  return hash;
}

BannerTheme getBannerTheme(String displayName, String? username) {
  final key = profileBannerKey(displayName, username);
  final hash = hashString(key);
  final hash2 = hashString('$key:wave');
  return BannerTheme(
    palette: _palettes[hash % _palettes.length],
    glowSideRight: hash.isEven,
    waveSeed: hash2 % 97,
  );
}

List<double> waveBarHeights(int seed, int count) {
  return List<double>.generate(count, (index) {
    final wave = math.sin((index + seed) * 0.5) * 0.5 + 0.5;
    return 0.25 + wave * 0.5;
  });
}

({String primary, String? secondary}) formatBannerName(String displayName) {
  final trimmed = displayName.trim().isEmpty ? 'Artist' : displayName.trim();
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length >= 2 && trimmed.length > 12) {
    final primary = parts.first;
    var secondary = parts.sublist(1).join(' ');
    if (secondary.length > 18) {
      secondary = '${secondary.substring(0, 16)}…';
    }
    return (primary: primary, secondary: secondary);
  }
  if (trimmed.length > 20) {
    return (primary: '${trimmed.substring(0, 18)}…', secondary: null);
  }
  return (primary: trimmed, secondary: null);
}

double profileBannerHeightForWidth(double width) {
  if (width >= 1024) return 256;
  if (width >= 768) return 192;
  if (width >= 640) return 160;
  return 128;
}
