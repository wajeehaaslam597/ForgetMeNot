import 'package:flutter/foundation.dart';

/// FastAPI backend base URL.
///
/// **Physical phone (USB or Wi‑Fi):** your PC must listen on all interfaces and you
/// must pass your PC's LAN IP, e.g.
/// `flutter run --dart-define=API_BASE=http://192.168.1.5:8000`
///
/// **Android emulator:** defaults to [10.0.2.2] (maps to the host machine).
///
/// **iOS Simulator / Windows / macOS desktop:** [127.0.0.1].
class ApiConfig {
  ApiConfig._();

  static const String _fromEnv = String.fromEnvironment('API_BASE');

  static String get baseUrl {
    if (_fromEnv.isNotEmpty) return _fromEnv;
    if (kIsWeb) return 'http://127.0.0.1:8000';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }
}
