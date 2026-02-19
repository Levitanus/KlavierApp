import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'l10n/app_localizations.dart';
import 'config/app_config.dart';
import 'auth.dart';
import 'services/notification_service.dart';
import 'services/push_notification_service.dart';
import 'services/hometask_service.dart';
import 'services/feed_service.dart';
import 'services/chat_service.dart';
import 'services/websocket_service.dart';
import 'services/theme_service.dart';
import 'services/locale_service.dart';
import 'services/active_view_tracker.dart';
import 'firebase_options.dart';
import 'login_screen.dart';
import 'home_screen.dart';
import 'reset_password_screen.dart';
import 'register_screen.dart';
import 'utils/notification_navigation.dart';

final ColorScheme _lightColorScheme =
    ColorScheme.fromSeed(
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

final ColorScheme _darkColorScheme =
    ColorScheme.fromSeed(
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
      onBackground: const Color(0xFFE9E1D7),
      surface: const Color(0xFF1F1B1A),
      onSurface: const Color(0xFFE9E1D7),
      outline: const Color(0xFF3A3130),
      surfaceTint: const Color(0xFF3BA79D),
    );

TextTheme _appTextTheme(Brightness brightness, ColorScheme colorScheme) {
  final base = ThemeData(brightness: brightness, useMaterial3: true).textTheme;
  final bodyColor = brightness == Brightness.dark
      ? colorScheme.onSurface.withOpacity(0.92)
      : colorScheme.onSurface;
  final displayColor = brightness == Brightness.dark
      ? colorScheme.onSurface.withOpacity(0.88)
      : colorScheme.onSurface;
  return GoogleFonts.getTextTheme(
    'Jost',
    base,
  ).apply(bodyColor: bodyColor, displayColor: displayColor);
}

final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );
  }

  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationNavigation(message.data);
    });

    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationNavigation(initialMessage.data);
    }
  }
  await AppConfig.load();
  // Use path-based URL strategy instead of hash-based
  usePathUrlStrategy();
  runApp(const MyApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void _handleLocalNotificationResponse(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) {
    return;
  }

  final params = Uri.splitQueryString(payload);
  _handleNotificationNavigation(Map<String, dynamic>.from(params));
}

Future<void> _handleForegroundMessage(RemoteMessage message) async {
  if (kDebugMode) {
    print('[PUSH] Foreground message received: ${message.data}');
  }

  final data = message.data;
  if (_shouldSuppressForegroundNotification(data)) {
    if (kDebugMode) {
      print('[PUSH] Suppressed foreground notification for active screen');
    }
    return;
  }

  await _showLocalNotification(
    title: message.notification?.title ?? 'Notification',
    body: message.notification?.body ?? '',
    payload: data,
  );
}

bool _shouldSuppressForegroundNotification(Map<String, dynamic> data) {
  final route = data['route'] as String?;
  if (route == null || route.isEmpty) {
    return false;
  }

  if (route.startsWith('/chat/')) {
    final match = RegExp(r'/chat/(\d+)').firstMatch(route);
    final threadId = match != null ? int.tryParse(match.group(1) ?? '') : null;
    if (threadId != null && ActiveViewTracker.activeChatThreadId == threadId) {
      return true;
    }
  }

  if (route.startsWith('/feeds')) {
    final metadata = _parseMetadata(data);
    final rawPostId = metadata?['post_id'];
    final postId = rawPostId is int
        ? rawPostId
        : (rawPostId is String ? int.tryParse(rawPostId) : null);
    if (postId != null && ActiveViewTracker.activeFeedPostId == postId) {
      return true;
    }
  }

  return false;
}

String _resolveNotificationIcon(Map<String, dynamic> data) {
  final type = data['type'] as String?;
  if (type == 'chat_message' || type == 'feed_comment') {
    return 'ic_notif_message';
  }
  return 'ic_notif_bell';
}

Map<String, dynamic>? _parseMetadata(Map<String, dynamic> data) {
  final raw = data['metadata'];
  if (raw == null) {
    return null;
  }
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is String && raw.isNotEmpty) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

void _handleNotificationNavigation(Map<String, dynamic> data) {
  final route = data['route'] as String?;
  if (route == null || route.isEmpty) {
    return;
  }

  final metadata = _parseMetadata(data);
  final context = _navigatorKey.currentContext;
  if (context == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleNotificationNavigation(data);
    });
    return;
  }

  navigateToNotificationRoute(context, route, metadata);
}

Future<void> _showLocalNotification({
  required String title,
  required String body,
  required Map<String, dynamic> payload,
}) async {
  if (kIsWeb) return; // Local notifications not needed on web

  final smallIcon = _resolveNotificationIcon(payload);

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'default',
    'Default Notifications',
    channelDescription: 'Default notification channel',
    importance: Importance.max,
    priority: Priority.high,
    icon: smallIcon,
    largeIcon: const DrawableResourceAndroidBitmap('ic_notif_large'),
  );

  await _localNotifications.show(
    UniqueKey().hashCode,
    title,
    body,
    NotificationDetails(android: androidDetails),
    payload: Uri(
      queryParameters: payload.map((k, v) => MapEntry(k, v.toString())),
    ).query,
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LocaleService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, NotificationService>(
          create: (context) =>
              NotificationService(authService: context.read<AuthService>()),
          update: (context, authService, previous) =>
              previous ?? NotificationService(authService: authService),
        ),
        ChangeNotifierProxyProvider<AuthService, PushNotificationService>(
          create: (context) =>
              PushNotificationService(authService: context.read<AuthService>()),
          update: (context, authService, previous) {
            final service =
                previous ?? PushNotificationService(authService: authService);
            service.syncAuth();
            return service;
          },
        ),
        ChangeNotifierProxyProvider<AuthService, HometaskService>(
          create: (context) =>
              HometaskService(authService: context.read<AuthService>()),
          update: (context, authService, previous) {
            final service =
                previous ?? HometaskService(authService: authService);
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
        ChangeNotifierProxyProvider2<
          AuthService,
          WebSocketService,
          FeedService
        >(
          create: (context) => FeedService(
            authService: context.read<AuthService>(),
            wsService: context.read<WebSocketService>(),
          ),
          update: (context, authService, wsService, previous) {
            final service =
                previous ??
                FeedService(authService: authService, wsService: wsService);
            service.syncAuth();
            return service;
          },
        ),
        ChangeNotifierProxyProvider2<
          AuthService,
          WebSocketService,
          ChatService
        >(
          create: (context) => ChatService(
            token: context.read<AuthService>().token ?? '',
            wsService: context.read<WebSocketService>(),
          ),
          update: (context, authService, wsService, previous) {
            final service =
                previous ??
                ChatService(
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
      child: _StartupPushSubscription(
        child: Consumer2<ThemeService, LocaleService>(
          builder: (context, themeService, localeService, child) {
            final lightTextTheme = _appTextTheme(
              Brightness.light,
              _lightColorScheme,
            );
            final darkTextTheme = _appTextTheme(
              Brightness.dark,
              _darkColorScheme,
            );

            return MaterialApp(
              navigatorKey: _navigatorKey,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)?.appTitle ?? 'Music School App',
              locale: localeService.locale ?? const Locale('de'),
              theme: ThemeData(
                useMaterial3: true,
                colorScheme: _lightColorScheme,
                scaffoldBackgroundColor: _lightColorScheme.background,
                dividerColor: _lightColorScheme.outline,
                textTheme: lightTextTheme,
                primaryTextTheme: lightTextTheme,
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
                textTheme: darkTextTheme,
                primaryTextTheme: darkTextTheme,
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

                if (uri.path == '/feeds') {
                  final feedId = int.tryParse(
                    uri.queryParameters['feed_id'] ?? '',
                  );
                  final postId = int.tryParse(
                    uri.queryParameters['post_id'] ?? '',
                  );
                  return MaterialPageRoute(
                    builder: (context) => HomeScreen(
                      initialFeedId: feedId,
                      initialPostId: postId,
                    ),
                  );
                }

                if (uri.path == '/hometasks') {
                  final studentId = int.tryParse(
                    uri.queryParameters['student_id'] ?? '',
                  );
                  return MaterialPageRoute(
                    builder: (context) =>
                        HomeScreen(initialStudentId: studentId),
                  );
                }

                // Handle /chat/{threadId}
                if (uri.pathSegments.length == 2 &&
                    uri.pathSegments.first == 'chat') {
                  final threadId = int.tryParse(uri.pathSegments[1]);
                  if (threadId != null) {
                    return MaterialPageRoute(
                      builder: (context) =>
                          HomeScreen(initialChatThreadId: threadId),
                    );
                  }
                }

                return MaterialPageRoute(
                  builder: (context) => const AuthWrapper(),
                );
              },
              initialRoute: '/',
            );
          },
        ),
      ),
    );
  }
}

class _StartupPushSubscription extends StatefulWidget {
  final Widget child;

  const _StartupPushSubscription({required this.child});

  @override
  State<_StartupPushSubscription> createState() =>
      _StartupPushSubscriptionState();
}

class _StartupPushSubscriptionState extends State<_StartupPushSubscription> {
  bool _didRun = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didRun) return;
    _didRun = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PushNotificationService>().trySubscribeOnStartup();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
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
                  body: Center(child: CircularProgressIndicator()),
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
