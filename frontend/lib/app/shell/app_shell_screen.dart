import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../features/hometasks/presentation/screens/hometasks_screen.dart';
import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/profile/application/providers/profile_provider.dart';
import '../../features/profile/presentation/screens/profile_edit_screen.dart';
import '../../features/profile/presentation/widgets/profile_summary_card.dart';

class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final logoAsset = isDark
        ? 'assets/branding/logo_bright.svg'
        : 'assets/branding/logo_dark.svg';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(logoAsset, height: 22),
            const SizedBox(width: 12),
            const Text('Musikschule am Thomas-Mann-Platz'),
          ],
        ),
        actions: [
          Builder(
            builder: (context) => IconButton(
              tooltip: 'Menu',
              onPressed: () => Scaffold.of(context).openEndDrawer(),
              icon: const Icon(Icons.menu),
            ),
          ),
          IconButton(
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        session.username.isNotEmpty
                            ? session.username.characters.first.toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(session.username, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      session.roles.join(', '),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              profileAsync.when(
                data: (profile) => ProfileSummaryCard(profile: profile),
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
                    child: Text(error.toString()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.assignment),
                title: const Text('Hometasks'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (context) => HometasksScreen(session: session),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit profile'),
                onTap: () async {
                  Navigator.of(context).pop();
                  final profile = await ref.read(currentUserProfileProvider.future);
                  if (!context.mounted) {
                    return;
                  }
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (context) => ProfileEditScreen(
                        session: session,
                        profile: profile,
                      ),
                    ),
                  );
                  ref.invalidate(currentUserProfileProvider);
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Log out'),
                onTap: () {
                  Navigator.of(context).pop();
                  ref.read(authControllerProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
      body: DashboardScreen(session: session),
    );
  }
}
