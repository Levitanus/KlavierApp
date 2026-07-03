import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/auth/domain/entities/auth_session.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';

class AppShellScreen extends ConsumerWidget {
  const AppShellScreen({super.key, required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Musikschule am Thomas-Mann-Platz'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: DashboardScreen(session: session),
    );
  }
}
