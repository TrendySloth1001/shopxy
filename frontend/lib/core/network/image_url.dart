import 'package:shopxy/core/config/app_config.dart';

String resolveImageUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return _join(trimmed);

  if (uri.hasScheme) {
    final host = uri.host;
    final isLoopback =
        host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
    if (isLoopback) {
      return _join(uri.path);
    }
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
