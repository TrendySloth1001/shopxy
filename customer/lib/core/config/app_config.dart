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

  /// Escape hatch for on-device testing: build with
  /// `--dart-define=ALLOW_DEV_HOST=true` to allow a release build that points
  /// at a devtunnel/localhost. Off by default so a normal release can't ship
  /// against a dev host by accident.
  static const bool _allowDevHost =
      bool.fromEnvironment('ALLOW_DEV_HOST', defaultValue: false);

  static String get apiBaseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    // Debug-only fall-through: a known local URL is far safer than
    // pointing at a developer's personal devtunnel.
    return 'https://qjhcp0ph-3003.inc1.devtunnels.ms/';
  }

  /// Throws on release builds that didn't get an explicit API_BASE_URL, or
  /// that were misconfigured to a developer's personal tunnel — unless
  /// ALLOW_DEV_HOST is set for deliberate on-device testing.
  /// Call once from `main()` before [runApp].
  static void assertSafeForRelease() {
    if (!kReleaseMode || _allowDevHost) return;
    if (_envBaseUrl.isEmpty) {
      throw StateError(
        'API_BASE_URL dart-define is required for release builds '
        '(or pass --dart-define=ALLOW_DEV_HOST=true for device testing).',
      );
    }
    if (_envBaseUrl.contains('devtunnels.ms') ||
        _envBaseUrl.contains('localhost') ||
        _envBaseUrl.contains('127.0.0.1')) {
      throw StateError(
        'API_BASE_URL "$_envBaseUrl" looks like a development host — '
        'refusing to launch a release build against it '
        '(pass --dart-define=ALLOW_DEV_HOST=true to override).',
      );
    }
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
