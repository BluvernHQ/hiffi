import 'package:firebase_analytics/firebase_analytics.dart';

import '../routes/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_estatisticas/umami_service.dart';

class AnalyticsService {
  AnalyticsService({required AppRouter appRouter})
      : _firebaseAnalytics = appRouter.analytics,
        _umamiService = appRouter.umamiService;

  final FirebaseAnalytics _firebaseAnalytics;
  final UmamiService _umamiService;

  FirebaseAnalytics get firebase => _firebaseAnalytics;
  UmamiService get umami => _umamiService;

  Future<void> logScreenView(
    BuildContext context, {
    required String screenName,
    String? screenClass,
  }) async {
    await _firebaseAnalytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
    );

    await _umamiService.enviarEvento(
      context,
      title: screenName,
      name: 'screen_view',
      data: {
        'screen_name': screenName,
        if (screenClass != null) 'screen_class': screenClass,
      },
    );
  }

  Future<void> logEvent(
    BuildContext context,
    String name, {
    String? title,
    Map<String, Object?>? parameters,
  }) async {
    await _firebaseAnalytics.logEvent(
      name: name,
      parameters: parameters == null
          ? null
          : parameters.map((key, value) => MapEntry(key, value ?? '')),
    );

    await _umamiService.enviarEvento(
      context,
      title: title ?? name,
      name: name,
      data: parameters,
    );
  }
}


