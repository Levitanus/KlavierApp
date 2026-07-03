import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../auth/application/providers/auth_provider.dart';
import '../../../auth/application/auth_state.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/entities/user_profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(apiClient: ref.watch(apiClientProvider)),
);

final currentUserProfileProvider = FutureProvider<UserProfile>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.status != AuthStatus.authenticated || authState.session == null) {
    throw const AppException('Profile requested without an authenticated session.');
  }

  return ref.watch(profileRepositoryProvider).fetchCurrentProfile(authState.session!);
});
