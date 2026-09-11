import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseConfig {
  FirebaseConfig._();

  static String get _projectId => dotenv.get('FIREBASE_PROJECT_ID', fallback: '');
  static String get _messagingSenderId => dotenv.get('FIREBASE_MESSAGING_SENDER_ID', fallback: '');

  static String get _apiKey {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.get('FIREBASE_IOS_API_KEY', fallback: '');
    }
    return dotenv.get('FIREBASE_ANDROID_API_KEY', fallback: '');
  }

  static String get _appId {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return dotenv.get('FIREBASE_IOS_APP_ID', fallback: '');
    }
    return dotenv.get('FIREBASE_ANDROID_APP_ID', fallback: '');
  }

  static bool get isConfigured {
    if (kIsWeb) return false;
    final supportedPlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return supportedPlatform &&
        _projectId.isNotEmpty &&
        _messagingSenderId.isNotEmpty &&
        _apiKey.isNotEmpty &&
        _appId.isNotEmpty;
  }

  static FirebaseOptions get currentPlatform {
    if (!isConfigured) {
      throw StateError('Firebase push notification configuration is incomplete.');
    }

    return FirebaseOptions(
      apiKey: _apiKey,
      appId: _appId,
      messagingSenderId: _messagingSenderId,
      projectId: _projectId,
      storageBucket: dotenv.get('FIREBASE_STORAGE_BUCKET', fallback: ''),
    );
  }
}
