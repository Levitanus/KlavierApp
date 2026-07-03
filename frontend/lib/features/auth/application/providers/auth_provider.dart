import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_preferences.dart';
import '../../../../core/storage/session_storage.dart';
import '../../data/repositories/auth_repository.dart';
import '../auth_state.dart';
import '../controllers/auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());
final localPreferencesProvider =
    Provider<LocalPreferences>((ref) => LocalPreferences());

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    sessionStorage: ref.watch(sessionStorageProvider),
    localPreferences: ref.watch(localPreferencesProvider),
  ),
);

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(ref.watch(authRepositoryProvider)),
);
