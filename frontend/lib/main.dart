import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Klavier',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        onGenerateRoute: (settings) {
          final name = settings.name ?? '/';
          final uri = Uri.parse(name);

          if (uri.pathSegments.length == 2 &&
              uri.pathSegments.first == 'reset-password') {
            final token = uri.pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => ResetPasswordScreen(token: token),
            );
          }

          return MaterialPageRoute(
            builder: (context) => const AuthWrapper(),
          );
        },
        initialRoute: '/',
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        // Show loading indicator while checking authentication
        if (authService.token == null && !authService.isAuthenticated) {
          // Check if we're still initializing
          return FutureBuilder(
            future: Future.delayed(const Duration(milliseconds: 100)),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // After initialization, decide which screen to show
              return authService.isAuthenticated
                  ? const HomeScreen()
                  : const LoginScreen();
            },
          );
        }

        // Navigate based on authentication status
        return authService.isAuthenticated
            ? const HomeScreen()
            : const LoginScreen();
      },
    );
  }
}
