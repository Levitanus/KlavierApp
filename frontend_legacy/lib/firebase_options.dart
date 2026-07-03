import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('DefaultFirebaseOptions are not supported for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDGnqthWFCa0PPltZOLpy5CcwXPLMCvHVU',
    appId: '1:437925171777:web:d1b1d37e4a4e5c0142ecc0',
    messagingSenderId: '437925171777',
    projectId: 'museikschule',
    authDomain: 'museikschule.firebaseapp.com',
    storageBucket: 'museikschule.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDJmpOd-TQ79TwM87ctgaKQQGVFtuMQzqs',
    appId: '1:437925171777:android:5b92a9e11a8d810f42ecc0',
    messagingSenderId: '437925171777',
    projectId: 'museikschule',
    storageBucket: 'museikschule.firebasestorage.app',
  );
}
