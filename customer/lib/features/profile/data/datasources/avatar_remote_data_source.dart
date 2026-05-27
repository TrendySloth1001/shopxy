import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shopxy_customer/core/network/api_client.dart';

/// Uploads a profile avatar to `/me/upload/avatar` and returns the
/// canonical URL the backend stored it at. Mirrors the merchant
/// pipeline (sharp re-encode + 3 WebP variants) so the same image
/// loader can resolve responsive sizes.
class AvatarRemoteDataSource {
  AvatarRemoteDataSource(this._client);
  final ApiClient _client;

  Future<String> upload(File file) async {
    final res = await _client.multipart(
      '/me/upload/avatar',
      makeFile: () => http.MultipartFile.fromPath('file', file.path),
    );
    final body = await res.stream.bytesToString();
    if (res.statusCode != 201) {
      throw Exception(_decodeError(body));
    }
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final url = (decoded['url'] as String?) ??
        ((decoded['variants'] as Map?)?['md'] as String?);
    if (url == null || url.isEmpty) {
      throw Exception('Upload succeeded but no url returned');
    }
    return url;
  }

  String _decodeError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['error'] as String?) ?? 'Upload failed';
    } catch (_) {
      return 'Upload failed';
    }
  }
}
