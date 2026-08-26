import 'package:flutter/foundation.dart';

class AppConfig {
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  static const bool _allowDevHost =
      bool.fromEnvironment('ALLOW_DEV_HOST', defaultValue: false);

  static const String productionBaseUrl =
      'https://backendshopxy.cloudnsofts.com/';

  static const String devBaseUrl = 'https://qjhcp0ph-3003.inc1.devtunnels.ms/';

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return kReleaseMode ? productionBaseUrl : devBaseUrl;
  }

  static const _devHostMarkers = [
    'devtunnels.ms',
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  ];

  static void assertSafeForRelease() {
    if (!kReleaseMode || _allowDevHost || _envBaseUrl.isEmpty) return;
    if (looksLikeDevHost(_envBaseUrl)) {
      throw StateError(
        'API_BASE_URL "$_envBaseUrl" looks like a development host — '
        'refusing to launch a release build against it '
        '(pass --dart-define=ALLOW_DEV_HOST=true to override).',
      );
    }
  }

  @visibleForTesting
  static bool looksLikeDevHost(String url) {
    final host = url.toLowerCase();
    return _devHostMarkers.any(host.contains);
  }

  static const String webBaseUrl = 'https://shopxy.app';

  static const String appScheme = 'shopxy';
}
