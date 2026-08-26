import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';

typedef AuthResult = ({AuthUser user, String accessToken, String refreshToken});

typedef RegisterResponse = ({bool pending, String email, AuthResult? session});

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

  Future<RegisterResponse> register(
    String name,
    String email,
    String password, {
    required bool acceptedTerms,
    required bool acceptedPrivacy,
  }) async {
    final res = await _client.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        'role': 'CUSTOMER',
        'acceptedTerms': acceptedTerms,
        'acceptedPrivacy': acceptedPrivacy,
      },
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['pending'] == true) {
      return (
        pending: true,
        email: body['email'] as String? ?? email,
        session: null,
      );
    }
    if (res.statusCode != 201) {
      throw Exception(_extractError(body));
    }
    return (
      pending: false,
      email: email,
      session: (
        user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
        accessToken: body['accessToken'] as String,
        refreshToken: body['refreshToken'] as String,
      ),
    );
  }

  Future<AuthResult> verifyEmail(String email, String otp) async {
    final res = await _client.post(
      '/auth/verify-email',
      body: {'email': email, 'otp': otp},
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

  Future<void> resendOtp(String email) async {
    final res = await _client.post('/auth/resend-otp', body: {'email': email});
    if (res.statusCode != 204) {
      throw Exception(
        _extractError(jsonDecode(res.body) as Map<String, dynamic>),
      );
    }
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
    String? avatarUrl,
    bool clearAvatar = false,
    String? phoneNumber,
    bool clearPhone = false,
    bool? notifyOrders,
    bool? notifyDeals,
    bool? notifyAccount,
    bool? notifyMessages,
    bool? pushEnabled,
    bool? smsEnabled,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
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
    if (notifyOrders != null) body['notifyOrders'] = notifyOrders;
    if (notifyDeals != null) body['notifyDeals'] = notifyDeals;
    if (notifyAccount != null) body['notifyAccount'] = notifyAccount;
    if (notifyMessages != null) body['notifyMessages'] = notifyMessages;
    if (pushEnabled != null) body['pushEnabled'] = pushEnabled;
    if (smsEnabled != null) body['smsEnabled'] = smsEnabled;
    final res = await _client.patch('/auth/me', body: body);
    if (res.statusCode != 200) {
      final decoded = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(decoded['error'] ?? 'Failed to update profile');
    }
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
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
