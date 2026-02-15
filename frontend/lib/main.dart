import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'l10n/app_localizations.dart';
import 'config/app_config.dart';
import 'auth.dart';
import 'services/notification_service.dart';
import 'services/hometask_service.dart';
import 'services/feed_service.dart';
import 'services/chat_service.dart';
import 'services/websocket_service.dart';
import 'services/theme_service.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';
import 'register_screen.dart';

final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.light,
  seedColor: const Color(0xFF2F9C94),
).copyWith(
  primary: const Color(0xFF2F9C94),
  onPrimary: const Color(0xFFFFFFFF),
  primaryContainer: const Color(0xFFBEE8E3),
  onPrimaryContainer: const Color(0xFF0B3532),
  secondary: const Color(0xFF4FB3A6),
  onSecondary: const Color(0xFF0A2A25),
  secondaryContainer: const Color(0xFFD6F1ED),
  onSecondaryContainer: const Color(0xFF0F3E38),
  tertiary: const Color(0xFFF2C94C),
  onTertiary: const Color(0xFF3A2A00),
  tertiaryContainer: const Color(0xFFFFE8A3),
  onTertiaryContainer: const Color(0xFF2D1C00),
  error: const Color(0xFFC82128),
  onError: const Color(0xFFFFFFFF),
  errorContainer: const Color(0xFFF6C7C9),
  onErrorContainer: const Color(0xFF3A0B0D),
  background: const Color(0xFFFFF6E8),
  onBackground: const Color(0xFF231F20),
  surface: const Color(0xFFFFFFFF),
  onSurface: const Color(0xFF231F20),
  outline: const Color(0xFFE8DCC7),
  surfaceTint: const Color(0xFF2F9C94),
);

final ColorScheme _darkColorScheme = ColorScheme.fromSeed(
  brightness: Brightness.dark,
  seedColor: const Color(0xFF2F9C94),
).copyWith(
  primary: const Color(0xFF3BA79D),
  onPrimary: const Color(0xFFFFFFFF),
  primaryContainer: const Color(0xFF1D3F3B),
  onPrimaryContainer: const Color(0xFFC5EEE9),
  secondary: const Color(0xFF4FB3A6),
  onSecondary: const Color(0xFF0B2320),
  secondaryContainer: const Color(0xFF22514B),
  onSecondaryContainer: const Color(0xFFD3F1ED),
  tertiary: const Color(0xFFF07C76),
  onTertiary: const Color(0xFF2B0D0B),
  tertiaryContainer: const Color(0xFF3A1C1A),
  onTertiaryContainer: const Color(0xFFFFD5D2),
  error: const Color(0xFFED1C24),
  onError: const Color(0xFFFFFFFF),
  errorContainer: const Color(0xFF7A0D12),
  onErrorContainer: const Color(0xFFF7E3E4),
  background: const Color(0xFF141211),
  onBackground: const Color(0xFFF7F0E8),
  surface: const Color(0xFF1F1B1A),
  onSurface: const Color(0xFFF7F0E8),
  outline: const Color(0xFF3A3130),
  surfaceTint: const Color(0xFF3BA79D),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  // Use path-based URL strategy instead of hash-based
  usePathUrlStrategy();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (context) => NotificationService(
            authService: context.read<AuthService>(),
          ),
          update: (context, authService, previous) =>
              previous ?? NotificationService(authService: authService),
        ),
        ChangeNotifierProxyProvider<AuthService, HometaskService>(
          create: (context) => HometaskService(
            authService: context.read<AuthService>(),
          ),
          update: (context, authService, previous) {
            final service = previous ?? HometaskService(authService: authService);
            service.syncAuth();
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, WebSocketService>(
          create: (context) => WebSocketService(
            authService: context.read<AuthService>(),
            token: context.read<AuthService>().token ?? '',
            serverUrl: AppConfig.instance.baseUrl,
          ),
          update: (context, authService, previous) {
            final token = authService.token ?? '';
            final service = (previous == null || previous.token != token)
                ? WebSocketService(
                    authService: authService,
                    token: token,
                    serverUrl: AppConfig.instance.baseUrl,
                  )
                : previous;
            // Connect if token is available and not already connected
            if (token.isNotEmpty && !service.isConnected) {
              service.connect();
            }
            return service;
          },
        ),
        ChangeNotifierProxyProvider2<AuthService, WebSocketService, FeedService>(
          create: (context) => FeedService(
            authService: context.read<AuthService>(),
            wsService: context.read<WebSocketService>(),
          ),
          update: (context, authService, wsService, previous) {
            final service = previous ?? FeedService(
              authService: authService,
              wsService: wsService,
            );
            service.syncAuth();
            return service;
          },
        ),
        ChangeNotifierProxyProvider2<AuthService, WebSocketService, ChatService>(
          create: (context) => ChatService(
            token: context.read<AuthService>().token ?? '',
            wsService: context.read<WebSocketService>(),
          ),
          update: (context, authService, wsService, previous) {
            final service = previous ?? ChatService(
              token: authService.token ?? '',
              wsService: wsService,
            );
            service.updateToken(authService.token ?? '');
            service.updateCurrentUserId(authService.userId);
            service.updateIsAdmin(authService.isAdmin);
            if (authService.isAuthenticated) {
              service.ensureThreadsLoaded();
            }
            return service;
          },
        ),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, child) => MaterialApp(
          onGenerateTitle: (context) =>
              AppLocalizations.of(context)?.appTitle ?? 'Music School App',
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: _lightColorScheme,
            scaffoldBackgroundColor: _lightColorScheme.background,
            dividerColor: _lightColorScheme.outline,
            appBarTheme: AppBarTheme(
              backgroundColor: _lightColorScheme.surface,
              foregroundColor: _lightColorScheme.onSurface,
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: _darkColorScheme,
            scaffoldBackgroundColor: _darkColorScheme.background,
            dividerColor: _darkColorScheme.outline,
            appBarTheme: AppBarTheme(
              backgroundColor: _darkColorScheme.surface,
              foregroundColor: _darkColorScheme.onSurface,
              elevation: 0,
            ),
          ),
          themeMode: themeService.themeMode,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            quill.FlutterQuillLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateRoute: (settings) {
            final name = settings.name ?? '/';
            final uri = Uri.parse(name);

            // Handle /reset-password/{token}
            if (uri.pathSegments.length == 2 &&
                uri.pathSegments.first == 'reset-password') {
              final token = uri.pathSegments[1];
              return MaterialPageRoute(
                builder: (context) => ResetPasswordScreen(token: token),
              );
            }

            // Handle /register?token=xxx
            if (uri.path == '/register' &&
                uri.queryParameters.containsKey('token')) {
              final token = uri.queryParameters['token']!;
              return MaterialPageRoute(
                builder: (context) => RegisterScreen(token: token),
              );
            }

            return MaterialPageRoute(
              builder: (context) => const AuthWrapper(),
            );
          },
          initialRoute: '/',
        ),
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
