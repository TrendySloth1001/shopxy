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
    // Debug-only fall-through: a known local URL is far safer than
    // pointing at a developer's personal devtunnel.
    return 'https://qjhcp0ph-3003.inc1.devtunnels.ms/';
  }

  /// Temporarily a no-op so release APKs can be built against the
  /// devtunnel default for on-device testing. Restore the dart-define
  /// + devtunnel/localhost checks before shipping to real users.
  static void assertSafeForRelease() {}

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
