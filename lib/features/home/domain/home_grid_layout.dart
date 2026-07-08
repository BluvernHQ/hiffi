import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/utils/responsive.dart';

double calculateHomeGridAspectRatio(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final columns = responsiveGridColumns(context).toDouble();
  final horizontalPadding = 12.w * 2;
  final spacing = 12.w;
  final cardWidth =
      (screenWidth - horizontalPadding - spacing * (columns - 1)) / columns;

  final thumbnailHeight = cardWidth * (9 / 16);

  final textSectionHeight =
      responsiveGridTextSectionHeight(context) + 8.h;

  final totalHeight = thumbnailHeight + textSectionHeight;

  return cardWidth / totalHeight;
}
