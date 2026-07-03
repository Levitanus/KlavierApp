import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/auth_session.dart';
import '../../../profile/application/providers/profile_provider.dart';
import '../../../profile/presentation/screens/profile_edit_screen.dart';
import '../../../profile/presentation/widgets/profile_summary_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profileAsync = ref.watch(currentUserProfileProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Musikschule', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 8),
          Text(
            'Rewrite baseline is active. Auth and profile are running on the new architecture.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Signed in as ${session.username}', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Text('Roles: ${session.roles.join(', ')}'),
                  const SizedBox(height: 8),
                  Text('User id: ${session.userId ?? 'unknown'}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          profileAsync.when(
            data: (profile) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Profile', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final refreshed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (context) => ProfileEditScreen(
                              session: session,
                              profile: profile,
                            ),
                          ),
                        );
                        if (refreshed == true) {
                          ref.invalidate(currentUserProfileProvider);
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: Text(
                        Theme.of(context).platform == TargetPlatform.iOS
                            ? 'Edit'
                            : 'Edit profile',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ProfileSummaryCard(profile: profile),
              ],
            ),
            loading: () => const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text('Loading profile...'),
                  ],
                ),
              ),
            ),
            error: (error, stackTrace) => Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Profile failed to load', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(error.toString()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
