import 'package:flutter/foundation.dart';

class AppConfig {
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com/
  /// The trailing slash matters — endpoints are concatenated as
  /// `${apiBaseUrl}auth/login`, not joined with a path separator.
  ///
  /// Optional — when absent [apiBaseUrl] picks a default by build mode.
  static const String _envBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Escape hatch for on-device testing: build with
  /// `--dart-define=ALLOW_DEV_HOST=true` to allow a release build that points
  /// at a devtunnel/localhost. Off by default so a normal release can't ship
  /// against a dev host by accident.
  static const bool _allowDevHost =
      bool.fromEnvironment('ALLOW_DEV_HOST', defaultValue: false);

  static const String productionBaseUrl =
      'https://backendshopxy.cloudnsofts.com/';

  /// The shared dev backend. This is where the test catalogue lives, so it
  /// stays the debug default — pointing `flutter run` at production shows an
  /// almost-empty app.
  static const String devBaseUrl = 'https://qjhcp0ph-3003.inc1.devtunnels.ms/';

  /// Default by build mode: debug gets the dev backend and its test data,
  /// release gets production. It used to be the dev tunnel in both, so a
  /// release built without a dart-define shipped against a developer's tunnel.
  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    return kReleaseMode ? productionBaseUrl : devBaseUrl;
  }

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

  /// Split out so it's testable — [assertSafeForRelease] is gated on
  /// [kReleaseMode], which is false under `flutter test`.
  @visibleForTesting
  static bool looksLikeDevHost(String url) {
    final host = url.toLowerCase();
    return _devHostMarkers.any(host.contains);
  }

  /// Public base URL the marketplace uses for shareable links. Universal
  /// / App Links resolve to this host (see Android intent-filters and
  /// iOS Associated Domains config); if the destination app isn't
  /// installed the path falls back to a static web product page.
  ///
  /// Update the domain once we own one — the platform manifests
  /// reference this same host via build-time string resources, so a
  /// single rename here + a re-deploy of the apple-app-site-association
  /// / assetlinks.json files is all it takes to switch.
  static const String webBaseUrl = 'https://shopxy.app';

  /// Custom scheme used as a fallback for deep links when the device
  /// hasn't been verified for app links (e.g. fresh installs that
  /// haven't yet been associated with the universal-link domain).
  /// Format: `shopxy://product/<id>`.
  static const String appScheme = 'shopxy';
}
