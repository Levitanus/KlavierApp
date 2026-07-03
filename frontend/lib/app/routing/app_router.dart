import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../shell/app_shell_screen.dart';
import 'startup_route.dart';

class AppRouter extends ConsumerWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupRoute = StartupRoute.fromUri(Uri.base);
    final authState = ref.watch(authControllerProvider);

    if (startupRoute.showsResetPassword) {
      return ResetPasswordScreen(token: startupRoute.resetPasswordToken!);
    }

    if (startupRoute.showsRegistration) {
      return RegisterScreen(token: startupRoute.registrationToken!);
    }

    if (authState.isInitializing) {
      return const _StatusScreen(
        title: 'Preparing KlavierApp',
        message: 'Loading configuration and restoring your session.',
      );
    }

    if (authState.isAuthenticated && authState.session != null) {
      return AppShellScreen(session: authState.session!);
    }

    return LoginScreen(errorMessage: authState.errorMessage);
  }
}

class _StatusScreen extends StatelessWidget {
  const _StatusScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
