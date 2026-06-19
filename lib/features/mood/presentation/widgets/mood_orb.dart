import 'package:flutter/material.dart';

import '../../domain/models/mood_def.dart';

class MoodOrb extends StatelessWidget {
  const MoodOrb({
    super.key,
    required this.mood,
    required this.selected,
    required this.onTap,
    this.size = 72,
    this.showLabel = true,
  });

  final MoodDef mood;
  final bool selected;
  final VoidCallback onTap;
  final double size;
  final bool showLabel;

  static const double _labelFontSize = 11;
  static const double _labelHeight = 1.2;
  static const double _labelGap = 8;

  /// Orb diameter + single-line label block (matches picker row height).
  static double heightFor(double orbSize, {bool withLabel = true}) {
    if (!withLabel) return orbSize;
    return orbSize + _labelGap + (_labelFontSize * _labelHeight);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: showLabel ? double.infinity : size,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: selected ? 1.03 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: ClipOval(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        mood.imageAsset,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              colors: mood.gradientColors,
                              center: Alignment.topLeft,
                              radius: 1.1,
                            ),
                          ),
                        ),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.2, -0.35),
                            radius: 0.9,
                            colors: [
                              Colors.white.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: 0.45,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.35),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showLabel) ...[
              const SizedBox(height: _labelGap),
              SizedBox(
                height: _labelFontSize * _labelHeight,
                child: Text(
                  mood.label.toUpperCase(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize: _labelFontSize,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: labelColor,
                    height: _labelHeight,
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
