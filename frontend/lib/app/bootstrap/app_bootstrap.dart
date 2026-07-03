import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../firebase_options.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/theme/app_theme.dart';
import '../routing/app_router.dart';

class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  late final Future<void> _bootstrapFuture = AppBootstrap.initialize();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BootstrapStatusMaterialApp(
            title: 'Bootstrapping KlavierApp',
            message: 'Loading app configuration and platform services.',
          );
        }

        if (snapshot.hasError) {
          return _BootstrapStatusMaterialApp(
            title: 'Bootstrap failed',
            message: snapshot.error.toString(),
          );
        }

        return const _AppRoot();
      },
    );
  }
}

class AppBootstrap {
  static Future<void> initialize() async {
    await AppConfig.load();

    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  }
}

class _AppRoot extends StatelessWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      onGenerateTitle: (context) => AppLocalizations.of(context)?.appTitle ?? 'Musikschule am Thomas-Mann-Platz',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AppRouter(),
    );
  }
}

class _BootstrapStatusMaterialApp extends StatelessWidget {
  const _BootstrapStatusMaterialApp({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: Scaffold(
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
      ),
    );
  }
}
