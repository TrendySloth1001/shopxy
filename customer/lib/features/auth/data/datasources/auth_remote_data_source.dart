import 'dart:convert';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';

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

  /// Register a new customer. [acceptedTerms]/[acceptedPrivacy] carry the
  /// user's explicit, affirmative consent captured on the register screen
  /// (an opt-in checkbox linking the Terms + Privacy notice) — never assumed.
  /// The backend rejects the signup if either is not true. (DPDP Act 2023 s.6
  /// — consent must be free, specific, informed and unambiguous.)
  Future<AuthResult> register(
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
        // Customer app — explicitly tag the signup so the backend never
        // defaults a merchant-app submission to CUSTOMER by accident.
        'role': 'CUSTOMER',
        // Affirmative DPDP consent captured on the register screen.
        'acceptedTerms': acceptedTerms,
        'acceptedPrivacy': acceptedPrivacy,
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

  /// PATCH /auth/me. Send only the fields the user changed —
  /// undefined keys are dropped so we don't accidentally clear
  /// values the user hasn't touched. Pass an explicit `null` for a
  /// field to clear it (e.g. removing the avatar).
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
