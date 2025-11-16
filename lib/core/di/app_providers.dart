import 'package:firebase_auth/firebase_auth.dart';
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
import '../routes/app_router.dart';
import '../services/api_client.dart';

List<SingleChildWidget> buildAppProviders() {
  return [
    Provider<FirebaseAuth>.value(value: FirebaseAuth.instance),
    Provider<AuthRepository>(
      create: (context) =>
          FirebaseAuthRepository(auth: context.read<FirebaseAuth>()),
    ),
    Provider<ApiClient>(
      create: (context) =>
          ApiClient(firebaseAuth: context.read<FirebaseAuth>()),
      dispose: (_, client) => client.dispose(),
    ),
    Provider<UserRepository>(
      create: (context) =>
          ApiUserRepository(apiClient: context.read<ApiClient>()),
    ),
    Provider<AppRouter>(
      create: (context) =>
          AppRouter(authRepository: context.read<AuthRepository>()),
      dispose: (_, router) => router.dispose(),
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
      ),
    ),
    ChangeNotifierProvider<UserViewModel>(
      create: (context) =>
          UserViewModel(userRepository: context.read<UserRepository>()),
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
    ChangeNotifierProvider<VideoUploadViewModel>(
      create: (_) => VideoUploadViewModel(),
    ),
  ];
}
