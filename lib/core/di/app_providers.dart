import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/home/domain/services/webrtc_service.dart';
import '../../features/home/presentation/viewmodels/home_view_model.dart';
import '../../features/upload/domain/services/spaces_service.dart';
import '../../features/upload/presentation/viewmodels/upload_view_model.dart';
import '../../features/upload/presentation/viewmodels/video_upload_view_model.dart';
import '../../features/user/data/user_repository.dart';
import '../../features/user/presentation/viewmodels/user_view_model.dart';
import '../../features/video/domain/repositories/video_repository.dart';
import '../../features/video/presentation/viewmodels/video_view_model.dart';
import '../../features/search/data/search_repository.dart';
import '../../features/search/presentation/viewmodels/search_view_model.dart';
import '../../features/following/presentation/viewmodels/following_view_model.dart';
import '../../features/liked/presentation/viewmodels/liked_videos_view_model.dart';
import '../../features/watch_history/presentation/viewmodels/watch_history_view_model.dart';
import '../routes/app_router.dart';
import '../services/api_client.dart';
import '../services/network_connectivity_service.dart';
import '../services/notification_service.dart';
import '../services/analytics_service.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    Provider<NetworkConnectivityService>(
      create: (_) => NetworkConnectivityService(),
      dispose: (_, service) => service.dispose(),
    ),
    Provider<ApiClient>(
      create: (context) => ApiClient(
        connectivityService: context.read<NetworkConnectivityService>(),
      ),
      dispose: (_, client) => client.dispose(),
    ),
    Provider<AuthRepository>(
      create: (context) =>
          BackendAuthRepository(apiClient: context.read<ApiClient>()),
      dispose: (_, repo) => (repo as BackendAuthRepository).dispose(),
    ),
    Provider<UserRepository>(
      create: (context) =>
          ApiUserRepository(apiClient: context.read<ApiClient>()),
    ),
    Provider<VideoRepository>(
      create: (context) =>
          VideoRepositoryImpl(apiClient: context.read<ApiClient>()),
    ),
    Provider<SearchRepository>(
      create: (context) =>
          ApiSearchRepository(apiClient: context.read<ApiClient>()),
    ),
    Provider<AppRouter>(
      create: (context) =>
          AppRouter(authRepository: context.read<AuthRepository>()),
      dispose: (_, router) => router.dispose(),
    ),
    Provider<AnalyticsService>(
      create: (context) =>
          AnalyticsService(appRouter: context.read<AppRouter>()),
    ),
    Provider<WebRtcService>(create: (_) => WebRtcService()),
    Provider<SpacesService>(
      create: (_) => SpacesService(
        region: 'blr1',
        accessKey: 'DO801FJALKLMFHVG97EX',
        secretKey: 'KQbKTjaWETEwh9dc28LgjKGMy8I8G88RKSbfOz8TjPA',
      ),
      dispose: (_, service) => service.dispose(),
    ),
    ChangeNotifierProvider<AuthViewModel>(
      create: (context) => AuthViewModel(
        authRepository: context.read<AuthRepository>(),
        userRepository: context.read<UserRepository>(),
        connectivityService: context.read<NetworkConnectivityService>(),
      ),
    ),
    ChangeNotifierProvider<UserViewModel>(
      create: (context) => UserViewModel(
        userRepository: context.read<UserRepository>(),
        connectivityService: context.read<NetworkConnectivityService>(),
      ),
    ),
    ChangeNotifierProvider<HomeViewModel>(
      create: (context) => HomeViewModel(
        authRepository: context.read<AuthRepository>(),
        authViewModel: context.read<AuthViewModel>(),
      ),
    ),
    ChangeNotifierProvider<UploadViewModel>(
      create: (context) =>
          UploadViewModel(spacesService: context.read<SpacesService>()),
    ),
    Provider<NotificationService>(create: (_) => NotificationService()),
    ChangeNotifierProvider<VideoUploadViewModel>(
      create: (context) => VideoUploadViewModel(
        apiClient: context.read<ApiClient>(),
        notificationService: context.read<NotificationService>(),
      ),
    ),
    ChangeNotifierProvider<VideoViewModel>(
      create: (context) => VideoViewModel(
        videoRepository: context.read<VideoRepository>(),
        connectivityService: context.read<NetworkConnectivityService>(),
      ),
    ),
    ChangeNotifierProvider<SearchViewModel>(
      create: (context) => SearchViewModel(
        searchRepository: context.read<SearchRepository>(),
        userRepository: context.read<UserRepository>(),
        authRepository: context.read<AuthRepository>(),
      ),
    ),
    ChangeNotifierProvider<FollowingViewModel>(
      create: (context) =>
          FollowingViewModel(videoRepository: context.read<VideoRepository>()),
    ),
    ChangeNotifierProvider<LikedVideosViewModel>(
      create: (context) => LikedVideosViewModel(
        videoRepository: context.read<VideoRepository>(),
      ),
    ),
    ChangeNotifierProvider<WatchHistoryViewModel>(
      create: (context) => WatchHistoryViewModel(
        videoRepository: context.read<VideoRepository>(),
      ),
    ),
  ];
}
