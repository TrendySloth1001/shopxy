import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com/
  /// The trailing slash matters — endpoints are concatenated as
  /// `${apiBaseUrl}auth/login`, not joined with a path separator.
  ///
  /// In debug mode we fall through to a local dev URL. In release mode
  /// the value MUST come via dart-define — see [assertSafeForRelease].
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return 'https://qjhcp0ph-3003.inc1.devtunnels.ms/';
  }

  /// Throws on release builds that didn't get an explicit API_BASE_URL
  /// or that were misconfigured to a developer's personal tunnel.
  /// Call once from `main()` before [runApp].
  static void assertSafeForRelease() {
    if (kReleaseMode) {
      if (_envBaseUrl.isEmpty) {
        throw StateError(
          'API_BASE_URL dart-define is required for release builds.',
        );
      }
      if (_envBaseUrl.contains('devtunnels.ms') ||
          _envBaseUrl.contains('localhost') ||
          _envBaseUrl.contains('127.0.0.1')) {
        throw StateError(
          'API_BASE_URL "$_envBaseUrl" looks like a development host — '
          'refusing to launch a release build against it.',
        );
      }
    }
  }
}
