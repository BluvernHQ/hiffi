import 'package:flutter/material.dart';

/// Displays the app bar logo image directly with no proxy or interpretation.
class HiffiLogo extends StatelessWidget {
  final double? size;
  final double? width;

  const HiffiLogo({
    super.key,
    this.size = 32,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final double displaySize = size ?? 32;
    return Image.asset(
      'assets/appbarlogo.png',
      height: displaySize,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
