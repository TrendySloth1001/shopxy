import 'dart:convert';
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

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<http.Response> get(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return http.get(_buildUri(path, queryParameters), headers: _headers);
  }

  Future<http.Response> post(String path, {Object? body}) {
    return http.post(
      _buildUri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> patch(String path, {Object? body}) {
    return http.patch(
      _buildUri(path),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  Future<http.Response> delete(String path) {
    return http.delete(_buildUri(path), headers: _headers);
  }
}
