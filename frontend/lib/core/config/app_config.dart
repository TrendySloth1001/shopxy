class AppConfig {
  /// Override at build time:
  ///   flutter run --dart-define=API_BASE_URL=https://api.example.com/
  /// The trailing slash matters — endpoints are concatenated as
  /// `${apiBaseUrl}auth/login`, not joined with a path separator.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3001/',
  );
}
