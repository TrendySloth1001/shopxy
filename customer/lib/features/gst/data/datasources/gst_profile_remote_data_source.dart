import 'dart:convert';

import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/gst/domain/entities/gst_profile.dart';

/// Talks to `/me/gst-profile` (auth-only):
///   GET   /me/gst-profile
///   PATCH /me/gst-profile   { gstin, legalName }  — gstin: null clears it
class GstProfileRemoteDataSource {
  const GstProfileRemoteDataSource(this._client);
  final ApiClient _client;

  Future<GstProfile> fetch() async {
    final res = await _client.get('/me/gst-profile');
    if (res.statusCode == 401) return const GstProfile.empty();
    if (res.statusCode != 200) {
      throw Exception('Failed to load GST details: ${res.statusCode}');
    }
    return GstProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Returns the saved profile, or throws [GstProfileRejected] carrying the
  /// server's message when the GSTIN fails validation. The server is the only
  /// thing that runs the checksum, so its wording is what the user sees.
  Future<GstProfile> save({String? gstin, String? legalName}) async {
    final res = await _client.patch(
      '/me/gst-profile',
      body: {'gstin': gstin, 'legalName': legalName},
    );
    if (res.statusCode == 400) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw GstProfileRejected(
        message: body['error'] as String? ?? 'Those GST details were rejected.',
        code: body['code'] as String?,
      );
    }
    if (res.statusCode != 200) {
      throw Exception('Failed to save GST details: ${res.statusCode}');
    }
    return GstProfile.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}

class GstProfileRejected implements Exception {
  const GstProfileRejected({required this.message, this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}
