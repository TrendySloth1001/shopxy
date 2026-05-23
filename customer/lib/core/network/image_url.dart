import 'package:shopxy_customer/core/config/app_config.dart';

/// Joins a stored image reference with the current API base URL.
///
/// Backend stores **relative** image paths (e.g. `/images/abc.jpg`) so
/// the database doesn't carry an environment-specific host. The
/// frontend joins each path with whatever URL it's currently talking
/// to the backend on — so the same row works against localhost,
/// devtunnels, and prod without a migration.
///
/// Older rows that baked `localhost` or `127.0.0.1` into the URL are
/// re-anchored against the live API base so they don't break on a
/// real device. Other absolute URLs are passed through unchanged.
String resolveImageUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return _join(trimmed);

  if (uri.hasScheme) {
    final host = uri.host;
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    if (isLoopback) return _join(uri.path);
    return trimmed;
  }
  return _join(trimmed);
}

String _join(String pathOrUrl) {
  final base = AppConfig.apiBaseUrl.endsWith('/')
      ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
      : AppConfig.apiBaseUrl;
  final suffix = pathOrUrl.startsWith('/') ? pathOrUrl : '/$pathOrUrl';
  return '$base$suffix';
}
