import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../connectivity/connectivity_controller.dart';
import 'app_connectivity_banner.dart';
import 'global_upload_overlay.dart';

/// Wraps the navigator with the global connectivity banner and upload overlay.
class AppConnectivityOverlay extends StatelessWidget {
  const AppConnectivityOverlay({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityController>();
    final showBanner = connectivity.showBanner;
    final statusBarTop = MediaQuery.paddingOf(context).top;
    final bannerInset = showBanner
        ? statusBarTop + ConnectivityController.bannerContentHeight
        : statusBarTop;

    return Stack(
      children: [
        if (child != null)
          MediaQuery(
            data: MediaQuery.of(context).copyWith(
              padding: MediaQuery.of(context).padding.copyWith(top: bannerInset),
            ),
            child: child!,
          ),
        const Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AppConnectivityBanner(),
        ),
        const GlobalUploadOverlay(),
      ],
    );
  }
}
