import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/application/providers/auth_provider.dart';
import '../../../auth/domain/entities/auth_session.dart';
import '../../data/repositories/hometask_repository.dart';

final hometaskRepositoryProvider = Provider.family<HometaskRepository, AuthSession>(
  (ref, session) => HometaskRepository(
    apiClient: ref.read(apiClientProvider),
    session: session,
  ),
);