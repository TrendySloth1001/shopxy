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
    //return 'https://backendshopxy.cloudnsofts.com/';
  }

  /// Google sign-in client IDs. Override at build time:
  ///   flutter run --dart-define=GOOGLE_CLIENT_ID_ANDROID=... \
  ///     --dart-define=GOOGLE_CLIENT_ID_IOS=... \
  ///     --dart-define=GOOGLE_CLIENT_ID_WEB=...
  /// `googleClientIdWeb` is passed as `serverClientId` to `GoogleSignIn`
  /// (not `googleClientIdAndroid`/iOS) — so the ID token's audience is
  /// the WEB client ID and the same backend check works across every
  /// platform, matching the merchant-web build.
  ///
  /// Hardcoded fallbacks (mirrors [apiBaseUrl]) so a plain `flutter run`
  /// works without dart-define flags. Android is confirmed (package
  /// com.shopxy.shopxy + debug SHA-1, verified in Cloud Console — Android
  /// clients use the same "installed" JSON key as Desktop app, which is
  /// what caused the earlier back-and-forth). iOS has no fallback yet
  /// (not received) — the button still shows once Android alone is set
  /// (see `isConfigured` in google_auth.dart), but iOS sign-in itself
  /// will fail until its client ID + Info.plist URL scheme are filled in.
  /// Will need the RELEASE keystore's SHA-1 added as a second Android
  /// client before a Play Store build (this one's the debug keystore).
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
