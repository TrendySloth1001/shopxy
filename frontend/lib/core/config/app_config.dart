import 'package:flutter/foundation.dart';
import 'package:shopxy/core/config/app_environment.dart';

class AppConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl {
    final picked = AppEnvironments.overrideBaseUrl;
    if (picked != null) return picked;
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return AppEnvironments.production.baseUrl;
  }

  static const String googleClientIdAndroid = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_ANDROID',
    defaultValue:
        '345405040836-j23uacgv396b20da9hjqa2ui00d2d2at.apps.googleusercontent.com',
  );
  static const String googleClientIdIos = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_IOS',
  );
  static const String googleClientIdWeb = String.fromEnvironment(
    'GOOGLE_CLIENT_ID_WEB',
    defaultValue:
        '345405040836-lps9u0rducshks9kjtpb96t8u3365lui.apps.googleusercontent.com',
  );

  static const _devHostMarkers = [
    'devtunnels.ms',
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  ];

  static void assertSafeForRelease() {
    if (!kReleaseMode || _envBaseUrl.isEmpty) return;
    if (looksLikeDevHost(_envBaseUrl)) {
      throw StateError(
        'API_BASE_URL "$_envBaseUrl" looks like a development host — '
        'refusing to launch a release build against it.',
      );
    }
  }

  @visibleForTesting
  static bool looksLikeDevHost(String url) {
    final host = url.toLowerCase();
    return _devHostMarkers.any(host.contains);
  }
}
