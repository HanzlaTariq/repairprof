import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

class AppConfig {
  static const emulators = bool.fromEnvironment(
    'USE_EMULATORS',
    defaultValue: true,
  );
  static const host = String.fromEnvironment(
    'EMULATOR_HOST',
    defaultValue: '10.0.2.2',
  );
  static const _api = String.fromEnvironment('API_BASE');
  static const _tracking = String.fromEnvironment('TRACKING_BASE');
  static String get api => _api.isNotEmpty
      ? _api
      : 'http://${kIsWeb ? '127.0.0.1' : host}:5001/demo-repairproof/us-central1/api';
  static String get tracking =>
      _tracking.isNotEmpty ? _tracking : 'http://127.0.0.1:5000';
  static FirebaseOptions get firebase => const FirebaseOptions(
    apiKey: String.fromEnvironment(
      'FIREBASE_API_KEY',
      defaultValue: 'demo-key',
    ),
    appId: String.fromEnvironment(
      'FIREBASE_APP_ID',
      defaultValue: '1:123456789:android:demo',
    ),
    messagingSenderId: String.fromEnvironment(
      'FIREBASE_SENDER_ID',
      defaultValue: '123456789',
    ),
    projectId: String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'demo-repairproof',
    ),
    authDomain: String.fromEnvironment(
      'FIREBASE_AUTH_DOMAIN',
      defaultValue: 'demo-repairproof.firebaseapp.com',
    ),
  );
  static void validate() {
    if (!emulators &&
        (_api.isEmpty ||
            _tracking.isEmpty ||
            firebase.projectId.startsWith('demo-'))) {
      throw StateError(
        'Production Firebase settings are missing. Follow SETUP_ROMAN_URDU.md.',
      );
    }
    if (!emulators &&
        (!api.startsWith('https://') || !tracking.startsWith('https://'))) {
      throw StateError('Production API and tracking links require HTTPS.');
    }
  }
}
