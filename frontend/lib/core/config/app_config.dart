import 'package:flutter/foundation.dart';
import 'package:shopxy/core/config/app_environment.dart';

class AppConfig {
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com/
  /// The trailing slash matters — endpoints are concatenated as
  /// `${apiBaseUrl}auth/login`, not joined with a path separator.
  ///
  /// Optional — when absent [apiBaseUrl] falls back to production.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Resolution order: the environment picked in Settings (developer-only,
  /// see [AppEnvironments]) → the build-time dart-define → production.
  ///
  /// Read at call time, never cached, so a switch takes effect on the next
  /// request without anything having to re-read it.
  static String get apiBaseUrl {
    final picked = AppEnvironments.overrideBaseUrl;
    if (picked != null) return picked;
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return AppEnvironments.production.baseUrl;
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

  /// Hosts that must never back a release build (10.0.2.2 = emulator's host).
  static const _devHostMarkers = [
    'devtunnels.ms',
    'localhost',
    '127.0.0.1',
    '10.0.2.2',
  ];

  /// Throws on a release build pointed at a developer host. Call once from
  /// `main()` before [runApp].
  ///
  /// A *missing* API_BASE_URL is fine — [apiBaseUrl] falls back to production.
  /// Requiring it used to throw here on every build that omitted the flag,
  /// which shipped an app that could only render a blank window.
  ///
  /// Checks the dart-define only, not [apiBaseUrl]: an environment picked in
  /// Settings is a deliberate choice and stays honoured.
  static void assertSafeForRelease() {
    if (!kReleaseMode || _envBaseUrl.isEmpty) return;
    if (looksLikeDevHost(_envBaseUrl)) {
      throw StateError(
        'API_BASE_URL "$_envBaseUrl" looks like a development host — '
        'refusing to launch a release build against it.',
      );
    }
  }

  /// Split out so it's testable — [assertSafeForRelease] is gated on
  /// [kReleaseMode], which is false under `flutter test`.
  @visibleForTesting
  static bool looksLikeDevHost(String url) {
    final host = url.toLowerCase();
    return _devHostMarkers.any(host.contains);
  }
}
