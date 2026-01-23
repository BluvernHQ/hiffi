import 'package:flutter/material.dart';

class HiffiLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? textColor;
  final double fontSize;

  const HiffiLogo({
    super.key,
    this.size = 32,
    this.showText = true,
    this.textColor,
    this.fontSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.3),
          child: Image.asset(
            'assets/appicon.png',
            width: size,
            height: size,
            fit: BoxFit.cover,
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.4),
          Text(
            'Hiffi',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: textColor ?? theme.colorScheme.onSurface,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}
