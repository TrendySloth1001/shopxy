import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';

typedef AuthResult = ({AuthUser user, String accessToken, String refreshToken});

class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);
  final ApiClient _client;

  Future<AuthResult> login(String email, String password) async {
    final res = await _client.post(
      '/auth/login',
      body: {'email': email, 'password': password},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Login failed');
    }
    return (
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
  }

  Future<AuthResult> register(
    String name,
    String email,
    String password, {
    required String shopName,
  }) async {
    final res = await _client.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        // Merchant app — every signup creates an OWNER + their Shop on
        // the backend, atomically. The customer app sends 'CUSTOMER'.
        'role': 'OWNER',
        'shopName': shopName,
        // DPDP consent gate — both literals required by the backend
        // schema. The register page disables submit until the user
        // ticks both boxes, so reaching this line implies acceptance.
        'acceptedTerms': true,
        'acceptedPrivacy': true,
      },
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(_extractError(body));
    }
    return (
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
    );
  }

  Future<AuthUser> getMe() async {
    final res = await _client.get('/auth/me');
    if (res.statusCode != 200) throw Exception('Session expired');
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _client.post('/auth/logout', body: {'refreshToken': refreshToken});
  }

  Future<AuthUser> updateProfile({
    String? name,
    bool? emailNotifications,
    String? shopName,
    String? shopAddress,
    String? shopCity,
    String? shopState,
    String? shopStateCode,
    String? shopPinCode,
    String? shopGstin,
    String? shopPan,
    String? upiVpa,
    String? avatarUrl,
    bool clearAvatar = false,
    String? phoneNumber,
    bool clearPhone = false,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (emailNotifications != null) {
      body['emailNotifications'] = emailNotifications;
    }
    // For shop fields, treat empty string as explicit clear (→ JSON null),
    // and a non-null value as "user touched this and wants to save it."
    // Untouched fields stay out of the body entirely.
    void put(String key, String? value) {
      if (value == null) return;
      body[key] = value.isEmpty ? null : value;
    }

    put('shopName', shopName);
    put('shopAddress', shopAddress);
    put('shopCity', shopCity);
    put('shopState', shopState);
    put('shopStateCode', shopStateCode);
    put('shopPinCode', shopPinCode);
    put('shopGstin', shopGstin);
    put('shopPan', shopPan);
    put('upiVpa', upiVpa);
    // Avatar + phone — explicit clear flag because the empty-string
    // convention above conflicts with multi-step upload UX.
    if (clearAvatar) {
      body['avatarUrl'] = null;
    } else if (avatarUrl != null) {
      body['avatarUrl'] = avatarUrl;
    }
    if (clearPhone) {
      body['phoneNumber'] = null;
    } else if (phoneNumber != null) {
      body['phoneNumber'] = phoneNumber;
    }

    final res = await _client.patch('/auth/me', body: body);
    if (res.statusCode != 200) {
      final errBody = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(_extractError(errBody));
    }
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// DPDP right-to-access — fetches the full user-bound data dump as
  /// raw bytes. Returned as bytes (not parsed JSON) so the caller can
  /// hand the unmodified blob to the share sheet / file system.
  Future<List<int>> exportData() async {
    final res = await _client.get('/auth/me/export');
    if (res.statusCode != 200) {
      throw Exception('Failed to export data (HTTP ${res.statusCode})');
    }
    return res.bodyBytes;
  }

  /// DPDP right-to-erasure. Throws with a stable message the UI can
  /// match on so the "active records" case can render a useful hint.
  Future<void> deleteAccount(String currentPassword) async {
    final res = await _client.delete(
      '/auth/me',
      body: {'currentPassword': currentPassword},
    );
    if (res.statusCode == 200) return;
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final err = body['error'];
    if (err == 'cannot_delete_with_active_records') {
      throw Exception(
        'This account has invoices that must be retained for 8 years '
        '(Companies Act / GST). Contact support@shopxy.example to request '
        'a controlled deletion.',
      );
    }
    if (err == 'invalid_password') {
      throw Exception('Current password is incorrect');
    }
    throw Exception(_extractError(body));
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final res = await _client.post(
      '/auth/change-password',
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
    if (res.statusCode != 204) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to change password');
    }
  }

  String _extractError(Map<String, dynamic> body) {
    final err = body['error'];
    if (err is String) return err;
    if (err is Map) {
      final fields = err['fieldErrors'] as Map?;
      if (fields != null) {
        for (final v in fields.values) {
          if (v is List && v.isNotEmpty) return v.first as String;
        }
      }
    }
    return 'An error occurred';
  }
}
