import 'package:http/http.dart' as http;
import 'package:shopxy/core/config/app_config.dart';

class ApiClient {
  const ApiClient();

  Uri _buildUri(String path, [Map<String, String>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    final uri = Uri.parse('${AppConfig.apiBaseUrl}$normalizedPath');
    return queryParameters == null
        ? uri
        : uri.replace(queryParameters: queryParameters);
  }

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return http.get(_buildUri(path, queryParameters));
  }
}
