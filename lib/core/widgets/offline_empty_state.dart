import 'package:flutter/material.dart';

/// Full-page or in-section offline empty state.
enum OfflineEmptyVariant { page, section }

class OfflineEmptyState extends StatelessWidget {
  const OfflineEmptyState({
    super.key,
    this.variant = OfflineEmptyVariant.page,
    this.title = "You're Offline",
    this.description =
        'Connect to the internet to load the latest content.',
    this.actionLabel = 'Try Again',
    this.onTryAgain,
    this.isRetrying = false,
  });

  final OfflineEmptyVariant variant;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback? onTryAgain;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final isPage = variant == OfflineEmptyVariant.page;
    final iconSize = isPage ? 128.0 : 96.0;
    final iconInner = isPage ? 56.0 : 44.0;
    final titleSize = isPage ? 20.0 : 16.0;
    final buttonWidth = isPage ? 200.0 : 160.0;
    final buttonHeight = isPage ? 46.0 : 42.0;
    final primary = Theme.of(context).colorScheme.primary;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: isPage ? 420 : 360),
        child: Padding(
          padding: EdgeInsets.all(isPage ? 24 : 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.14),
                      primary.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: iconInner,
                  color: primary,
                ),
              ),
              SizedBox(height: isPage ? 24 : 16),
              Text(
                title,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF29292E),
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isPage ? 10 : 8),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFF6B6B6B),
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              if (onTryAgain != null) ...[
                SizedBox(height: isPage ? 28 : 20),
                SizedBox(
                  width: buttonWidth,
                  height: buttonHeight,
                  child: ElevatedButton(
                    onPressed: isRetrying ? null : onTryAgain,
                    child: isRetrying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(actionLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
