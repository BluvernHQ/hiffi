import 'package:flutter/material.dart';

/// Breakpoints for responsive layout (iPad, tablet, desktop).
/// - Mobile: < 600
/// - Tablet: 600–900 (e.g. iPad portrait ~768)
/// - Desktop / large tablet: >= 900 (e.g. iPad landscape ~1024)
const double kMobileBreakpoint = 600;
const double kTabletBreakpoint = 900;

/// Max content width when on tablet/iPad so content doesn't stretch too much.
/// Use a high percentage of screen width (94%) with a cap so side margins stay small.
const double kMaxContentWidth = 960;

/// Horizontal padding for content on tablet/iPad. Kept modest to reduce left/right space.
const double kResponsiveHorizontalPadding = 16;

/// Returns true if the shortest side (typically width in portrait) is >= [kMobileBreakpoint].
bool isTabletOrLarger(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= kMobileBreakpoint;
}

/// Returns true if the shortest side is >= [kTabletBreakpoint] (e.g. iPad landscape).
bool isDesktopOrLarger(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  return width >= kTabletBreakpoint;
}

/// Returns the number of grid columns for video/content grids:
/// 2 on mobile, 3 on tablet, 4 on large tablet/desktop.
int responsiveGridColumns(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  if (width >= kTabletBreakpoint) return 4;
  if (width >= kMobileBreakpoint) return 3;
  return 2;
}

/// Returns horizontal padding for the current screen size (larger on tablet).
EdgeInsets responsiveHorizontalPadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final padding = width >= kMobileBreakpoint
      ? kResponsiveHorizontalPadding
      : 16.0;
  return EdgeInsets.symmetric(horizontal: padding);
}

/// Font size for video grid card titles. Slightly smaller on tablet so text fits.
double responsiveGridTitleFontSize(BuildContext context) {
  return isTabletOrLarger(context) ? 12.0 : 13.0;
}

/// Font size for video grid card subtitles (e.g. username). Slightly larger on tablet for readability.
double responsiveGridSubtitleFontSize(BuildContext context) {
  return isTabletOrLarger(context) ? 12.0 : 11.0;
}

/// Height of the text section below thumbnail in grid cards.
/// Enough for 2-line title with ellipsis + channel row (YouTube-style).
double responsiveGridTextSectionHeight(BuildContext context) {
  return isTabletOrLarger(context) ? 64.0 : 68.0;
}

/// Avatar size for grid card creator. Slightly larger on tablet for balance.
double responsiveGridAvatarSize(BuildContext context) {
  return isTabletOrLarger(context) ? 22.0 : 20.0;
}

/// Wraps [child] in a centered container with [kMaxContentWidth] when on tablet/iPad,
/// so content can use more width and side margins stay smaller.
class ResponsiveMaxWidth extends StatelessWidget {
  const ResponsiveMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = kMaxContentWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= maxWidth) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
