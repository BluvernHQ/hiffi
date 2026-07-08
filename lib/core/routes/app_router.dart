import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter_estatisticas/umami_navigation_observer.dart';
import 'package:flutter_estatisticas/umami_service.dart';

import '../services/referral_storage_service.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/auth_page.dart';
import '../../features/auth/presentation/views/referral_entry_page.dart';
import '../../features/home/presentation/views/home_page.dart';
import '../../features/following/presentation/views/following_page.dart';
import '../../features/liked/presentation/views/liked_videos_page.dart';
import '../../features/watch_history/presentation/views/watch_history_page.dart';

import '../../features/upload/presentation/views/video_upload_page.dart';
import '../../features/user/presentation/views/become_creator_page.dart';
import '../../features/user/presentation/views/hiffi_studio_page.dart';
import '../../features/migration/presentation/views/migrate_content_page.dart';
import '../../features/user/presentation/views/user_profile_page.dart';
import '../../features/video/domain/models/video_model.dart';
import '../../features/video/presentation/views/video_player_page.dart';
import 'video_player_route_extra.dart';
import 'watch_route_extra.dart';
import '../../features/video/presentation/views/watch_screen.dart';
import '../../features/search/presentation/views/search_results_page.dart';
import '../../features/playlist/domain/models/playlist_models.dart';
import '../../features/playlist/presentation/views/playlists_page.dart';
import '../../features/playlist/presentation/views/playlist_detail_page.dart';
import '../../features/content/presentation/views/content_webview_page.dart';
import '../../features/content/presentation/views/help_legal_page.dart';
import '../../features/flags/presentation/views/my_reports_page.dart';
import '../../features/flags/presentation/views/my_report_detail_page.dart';

class AppRouter {
  static const String webBaseUrl = 'https://www.hiffi.com';

  static const Map<String, ({String title, String path})> contentPages = {
    'terms-of-use': (title: 'Terms of Use', path: '/terms-of-use'),
    'payment-terms': (title: 'Payment Terms', path: '/payment-terms'),
    'privacy-policy': (title: 'Privacy Policy', path: '/privacy-policy'),
    'faq': (title: 'FAQ', path: '/faq'),
    'support': (title: 'Support', path: '/support'),
  };

  static Uri? contentUriForSlug(String slug) {
    final config = contentPages[slug];
    if (config == null) return null;
    return Uri.parse('$webBaseUrl${config.path}');
  }

  /// For [RouteAware] on [VideoPlayerPage] (PiP eligibility when another route covers the player).
  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  AppRouter({
    required AuthRepository authRepository,
    FirebaseAnalytics? analytics,
    UmamiService? umamiService,
  }) : _authRepository = authRepository,
       _analytics = analytics ?? FirebaseAnalytics.instance,
       _umamiService =
           umamiService ??
           UmamiService(
             endpoint: 'https://analytics.superlabs.co',
             website: 'b7a2884e-fdec-4b9f-9ff8-29c5a4e63454',
             hostname: 'hiffi.com',
           ),
       _navigatorKey = GlobalKey<NavigatorState>() {
    _refreshListenable = RouterRefreshStream(
      _authRepository.authStateChanges(),
    );

    router = GoRouter(
      navigatorKey: _navigatorKey,
      initialLocation: '/home',
      refreshListenable: _refreshListenable,
      debugLogDiagnostics: true,
      observers: [
        routeObserver,
        FirebaseAnalyticsObserver(analytics: _analytics),
        UmamiNavigationObserver(_umamiService),
      ],
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (context, state) {
            // Get return route from query parameters
            final returnRoute = state.uri.queryParameters['returnTo'];
            return AuthPage(
              initialMode: AuthMode.signIn,
              returnRoute: returnRoute,
            );
          },
        ),
        GoRoute(
          path: '/signup',
          name: 'signup',
          builder: (context, state) {
            final returnRoute = state.uri.queryParameters['returnTo'];
            final ref = state.uri.queryParameters['ref']?.trim();
            if (ref != null && ref.isNotEmpty) {
              ReferralStorageService.saveReferral(username: ref);
            }
            return AuthPage(
              initialMode: AuthMode.signUp,
              returnRoute: returnRoute,
            );
          },
        ),
        GoRoute(
          path: '/r/:username',
          name: 'referral_entry',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return ReferralEntryPage(username: username);
          },
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          path: '/following',
          name: 'following',
          builder: (context, state) => const FollowingPage(),
        ),
        GoRoute(
          path: '/liked',
          name: 'liked_videos',
          builder: (context, state) => const LikedVideosPage(),
        ),
        GoRoute(
          path: '/watch-history',
          name: 'watch_history',
          builder: (context, state) => const WatchHistoryPage(),
        ),

        GoRoute(
          path: '/upload/video',
          name: 'video_upload',
          builder: (context, state) => const VideoUploadPage(),
        ),
        GoRoute(
          path: '/become-creator',
          name: 'become_creator',
          builder: (context, state) => const BecomeCreatorPage(),
        ),
        GoRoute(
          path: '/studio',
          name: 'hiffi_studio',
          builder: (context, state) => const HiffiStudioPage(),
          routes: [
            GoRoute(
              path: 'migrate',
              name: 'studio_migrate',
              builder: (context, state) {
                final scrollToStatus =
                    state.uri.queryParameters['status'] == '1';
                return MigrateContentPage(scrollToStatusOnLoad: scrollToStatus);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/users/:username',
          name: 'user_profile',
          builder: (context, state) {
            final username = state.pathParameters['username'] ?? '';
            return UserProfilePage(username: username);
          },
        ),
        GoRoute(
          path: '/video/:videoId',
          name: 'video_detail',
          builder: (context, state) {
            final videoId = state.pathParameters['videoId'] ?? '';
            // Try to get video from extra first, then from cache
            final extra = state.extra;
            VideoModel? video;
            Duration? initialResumePosition;
            if (extra is VideoPlayerRouteExtra) {
              video = extra.video;
              initialResumePosition = extra.initialResumePosition;
            } else {
              video = extra as VideoModel?;
            }
            bool returningFromAuth = false;

            if (video == null) {
              // Try to get from VideoPlayerPage cache (e.g., after returning from auth
              // or popping back from a pushed route like a creator profile).
              final cachedVideo = VideoPlayerPage.getCachedVideo(videoId);
              if (cachedVideo != null) {
                video = cachedVideo;
                returningFromAuth = true;
              }
            }
            if (video == null) {
              // Deep links and back navigation do not preserve go_router `extra`.
              // Hydrate by video id instead of crashing.
              return WatchScreen(videoId: videoId);
            }
            return VideoPlayerPage(
              video: video,
              videoId: videoId,
              returningFromAuth: returningFromAuth,
              initialResumePosition: initialResumePosition,
            );
          },
        ),
        GoRoute(
          path: '/watch/:videoId',
          name: 'watch_video',
          builder: (context, state) {
            final videoId = state.pathParameters['videoId'] ?? '';
            final playlistId = state.uri.queryParameters['playlist'];
            final pindex = int.tryParse(
              state.uri.queryParameters['pindex'] ?? '',
            );
            final isCurated = state.uri.queryParameters['curated'] == '1';

            if (videoId.isEmpty) {
              // Invalid deep link: send to home instead of crashing.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/home');
              });
              return const SizedBox.shrink();
            }

            final extra = state.extra;
            VideoModel? initialVideo;
            PlaylistSession? initialPlaylistSession;
            if (extra is WatchRouteExtra) {
              initialVideo = extra.video;
              initialPlaylistSession = extra.playlistSession;
            } else if (extra is VideoPlayerRouteExtra) {
              initialVideo = extra.video;
            } else if (extra is VideoModel) {
              initialVideo = extra;
            }

            return WatchScreen(
              videoId: videoId,
              playlistId: playlistId,
              playlistIndex: pindex,
              isCuratedPlaylist: isCurated,
              initialVideo: initialVideo,
              initialPlaylistSession: initialPlaylistSession,
            );
          },
        ),
        GoRoute(
          path: '/playlists',
          name: 'playlists',
          builder: (context, state) => const PlaylistsPage(),
        ),
        GoRoute(
          path: '/playlists/:playlistId',
          name: 'playlist_detail',
          builder: (context, state) {
            final playlistId = state.pathParameters['playlistId'] ?? '';
            return PlaylistDetailPage(playlistId: playlistId);
          },
        ),
        GoRoute(
          path: '/search',
          name: 'search',
          builder: (context, state) {
            final query = state.uri.queryParameters['q'] ?? '';
            return SearchResultsPage(query: query);
          },
        ),
        GoRoute(
          path: '/content/:slug',
          name: 'content_page',
          builder: (context, state) {
            final slug = state.pathParameters['slug'] ?? '';
            final config = contentPages[slug];
            if (config == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/home');
              });
              return const SizedBox.shrink();
            }
            return ContentWebViewPage(
              title: config.title,
              url: '$webBaseUrl${config.path}',
            );
          },
        ),
        GoRoute(
          path: '/help-legal',
          name: 'help_legal',
          builder: (context, state) => const HelpLegalPage(),
        ),
        GoRoute(
          path: '/my-reports',
          name: 'my_reports',
          builder: (context, state) => const MyReportsPage(),
        ),
        GoRoute(
          path: '/my-reports/:referenceId',
          name: 'my_report_detail',
          builder: (context, state) {
            final referenceId = Uri.decodeComponent(
              state.pathParameters['referenceId'] ?? '',
            );
            return MyReportDetailPage(referenceId: referenceId);
          },
        ),
      ],
      redirect: (context, state) {
        final isLoggedIn = _authRepository.currentUser != null;
        final loggingIn = state.uri.path == '/login';
        final signingUp = state.uri.path == '/signup';
        final uploading =
            state.uri.path == '/upload' || state.uri.path == '/upload/video';
        final onProfile = state.uri.path.startsWith('/users/');
        final onHome = state.uri.path == '/home';
        final onFollowing = state.uri.path == '/following';
        final onVideo = state.uri.path.startsWith('/video/');
        final onWatch = state.uri.path.startsWith('/watch/');
        final onSearch = state.uri.path == '/search';
        final onPlaylists = state.uri.path.startsWith('/playlists');
        final onReferral = state.uri.path.startsWith('/r/');
        final onContentPage = state.uri.path.startsWith('/content/');
        final onHelpLegal = state.uri.path == '/help-legal';
        final onMyReports = state.uri.path == '/my-reports';
        final onMyReportsDetail = state.uri.path.startsWith('/my-reports/');
        final onStudio = state.uri.path == '/studio' ||
            state.uri.path.startsWith('/studio/');

        if (!isLoggedIn) {
          if (onPlaylists) {
            return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
          }
          final onLiked = state.uri.path == '/liked';
          if (onLiked) {
            return '/login?returnTo=/liked';
          }
          final onWatchHistory = state.uri.path == '/watch-history';
          if (onWatchHistory) {
            return '/login?returnTo=/watch-history';
          }
          if (onMyReports) {
            return '/login?returnTo=/my-reports';
          }
          if (onMyReportsDetail) {
            return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
          }
          if (onStudio) {
            return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
          }
          // Allow access to home, video player, upload pages, and auth pages without authentication
          if (onProfile) {
            return null;
          }
          // Allow access to these pages without authentication
          if (loggingIn ||
              signingUp ||
              uploading ||
              onHome ||
              onFollowing ||
              onVideo ||
              onWatch ||
              onSearch ||
              onReferral ||
              onContentPage ||
              onHelpLegal ||
              onPlaylists) {
            return null;
          }
          // For any other route, redirect to home
          return '/home';
        }

        // If logged in and on login/signup page, redirect to home
        if (loggingIn || signingUp) {
          return '/home';
        }

        return null;
      },
    );
  }

  late final GoRouter router;
  late final RouterRefreshStream _refreshListenable;
  final AuthRepository _authRepository;
  final GlobalKey<NavigatorState> _navigatorKey;

  final FirebaseAnalytics _analytics;
  final UmamiService _umamiService;

  FirebaseAnalytics get analytics => _analytics;
  UmamiService get umamiService => _umamiService;

  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;

  void dispose() {
    _refreshListenable.dispose();
    router.dispose();
  }
}

class RouterRefreshStream extends ChangeNotifier {
  RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((user) {
      print(
        '🔄 Auth state changed: ${user != null ? "logged in" : "logged out"}',
      );
      // Notify listeners immediately to trigger router refresh
      notifyListeners();
      // Also schedule multiple notifications to ensure router processes the change
      Future.microtask(() {
        notifyListeners();
      });
      // Additional delayed notification to catch any race conditions
      Future.delayed(const Duration(milliseconds: 200), () {
        notifyListeners();
      });
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
