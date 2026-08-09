import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';

typedef AuthResult = ({AuthUser user, String accessToken, String refreshToken});

/// Register can either (a) require email-OTP verification — `pending` is true
/// and no session is issued yet, or (b) sign the user straight in when the OTP
/// infra is unavailable — `pending` is false and `session` carries the tokens.
typedef RegisterResponse = ({bool pending, String email, AuthResult? session});
typedef RememberLoginResult = ({
  AuthUser user,
  String accessToken,
  String refreshToken,
  String rememberToken,
});

/// Google sign-in result — same as [AuthResult] plus whether this account
/// still needs to set up its recovery PIN (new signups always do).
typedef GoogleAuthResult = ({
  AuthUser user,
  String accessToken,
  String refreshToken,
  bool needsPinSetup,
});

/// One active session behind the account (a device where you're signed in).
class SessionInfo {
  const SessionInfo({
    required this.id,
    required this.device,
    required this.where,
    required this.createdAt,
    required this.lastUsedAt,
    required this.current,
  });

  final String id;
  final String device; // friendly label ("Chrome on Windows", "ShopXY app")
  final String? where; // masked IP
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool current; // the session making this request

  factory SessionInfo.fromJson(Map<String, dynamic> j) => SessionInfo(
    id: j['id'].toString(),
    device: (j['device'] as String?) ?? 'Unknown device',
    where: j['where'] as String?,
    createdAt: DateTime.parse(j['createdAt'] as String),
    lastUsedAt: j['lastUsedAt'] != null
        ? DateTime.parse(j['lastUsedAt'] as String)
        : null,
    current: (j['current'] as bool?) ?? false,
  );
}

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

  /// Sign in via a verified Google ID token — creates/links/signs in the
  /// account server-side (see `backend auth.service.ts#googleAuth`).
  Future<GoogleAuthResult> googleAuth(String idToken) async {
    final res = await _client.post('/auth/google', body: {'idToken': idToken});
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Google sign-in failed');
    }
    return (
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      needsPinSetup: (body['needsPinSetup'] as bool?) ?? false,
    );
  }

  /// Set (or replace) the recovery PIN used to sign in if Google is ever
  /// unreachable. Authenticated.
  Future<void> setRecoveryPin(String pin) async {
    final res = await _client.post('/auth/recovery-pin', body: {'pin': pin});
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(_extractError(body));
    }
  }

  /// Fallback sign-in for Google-only accounts when Google itself isn't
  /// reachable.
  Future<AuthResult> loginWithRecoveryPin(String email, String pin) async {
    final res = await _client.post(
      '/auth/recovery-pin/login',
      body: {'email': email, 'pin': pin},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Sign in failed');
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
    String? shopName,
  }) async {
    final res = await _client.post(
      '/auth/register',
      body: {
        'name': name,
        'email': email,
        'password': password,
        // Merchant app — signup creates an OWNER. The shop is named in
        // onboarding (name-your-shop) unless a shopName is supplied here,
        // mirroring merchant-web. The customer app sends 'CUSTOMER'.
        'role': 'OWNER',
        if (shopName != null && shopName.isNotEmpty) 'shopName': shopName,
        // DPDP consent gate — both literals required by the backend
        // schema. The register page disables submit until the user
        // ticks both boxes, so reaching this line implies acceptance.
        'acceptedTerms': true,
        'acceptedPrivacy': true,
      },
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    // OTP gate: 200 + pending → an email code was sent, no account yet.
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
    // Direct sign-in. Only reachable against a dev backend running with
    // ALLOW_UNVERIFIED_SIGNUP — production always returns `pending` or 503.
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

  /// Confirm the signup OTP → the backend creates the account and returns a
  /// session (same shape as login).
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

  /// Ask for a password-reset code.
  ///
  /// Succeeds whether or not the address has an account — the server answers
  /// identically either way so this can't be used to test which emails are
  /// registered. Don't "improve" this by surfacing a not-found.
  Future<void> forgotPassword(String email) async {
    final res = await _client.post(
      '/auth/forgot-password',
      body: {'email': email},
    );
    if (res.statusCode != 204) {
      throw Exception(
        _extractError(jsonDecode(res.body) as Map<String, dynamic>),
      );
    }
  }

  /// Confirm the reset code and set a new password. Returns nothing: the
  /// server issues no session and has signed every device out, so the user
  /// signs in again with the new password.
  Future<void> resetPassword(
    String email,
    String otp,
    String newPassword,
  ) async {
    final res = await _client.post(
      '/auth/reset-password',
      body: {'email': email, 'otp': otp, 'newPassword': newPassword},
    );
    if (res.statusCode != 204) {
      throw Exception(
        _extractError(jsonDecode(res.body) as Map<String, dynamic>),
      );
    }
  }

  /// Re-send the signup verification code (rate-limited server-side).
  Future<void> resendOtp(String email) async {
    final res = await _client.post('/auth/resend-otp', body: {'email': email});
    if (res.statusCode != 204) {
      throw Exception(
        _extractError(jsonDecode(res.body) as Map<String, dynamic>),
      );
    }
  }

  // ── Sessions / devices ────────────────────────────────────────────────

  /// Active sessions for the signed-in user (device / where / when).
  Future<List<SessionInfo>> listSessions() async {
    final res = await _client.get('/auth/sessions');
    if (res.statusCode != 200) throw Exception('Could not load your devices.');
    final list = jsonDecode(res.body) as List<dynamic>;
    return list
        .map((e) => SessionInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Revoke one session — signs that device out immediately.
  Future<void> revokeSession(String id) async {
    final res = await _client.delete('/auth/sessions/$id');
    if (res.statusCode != 204) {
      throw Exception('Could not sign out that device.');
    }
  }

  /// Sign out every device except the current one. Returns how many were revoked.
  Future<int> revokeOtherSessions() async {
    final res = await _client.post('/auth/sessions/revoke-others');
    if (res.statusCode != 200) {
      throw Exception('Could not sign out other devices.');
    }
    return (jsonDecode(res.body) as Map<String, dynamic>)['revoked'] as int? ??
        0;
  }

  /// [bypassCache] forces a live read — for callers that just wrote
  /// something (a new shop, a profile change) and need this response to
  /// reflect it immediately, not after the next background revalidation.
  Future<AuthUser> getMe({bool bypassCache = false}) async {
    final res = await _client.get('/auth/me', bypassCache: bypassCache);
    if (res.statusCode != 200) throw Exception('Session expired');
    return AuthUser.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _client.post('/auth/logout', body: {'refreshToken': refreshToken});
  }

  // ── Device-remember (one-tap return sign-in) ──────────────────────────

  /// Mint a device-remember credential for the signed-in user (authed).
  Future<String> issueRememberToken({String? label}) async {
    final reqBody = <String, dynamic>{};
    if (label != null) reqBody['label'] = label;
    final res = await _client.post('/auth/remember', body: reqBody);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 201) {
      throw Exception(body['error'] ?? 'Could not remember this device');
    }
    return body['rememberToken'] as String;
  }

  /// Exchange a stored device-remember credential for a fresh session.
  Future<RememberLoginResult> rememberLogin(String rememberToken) async {
    final res = await _client.post(
      '/auth/remember-login',
      body: {'rememberToken': rememberToken},
    );
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? 'Sign in failed');
    }
    return (
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      accessToken: body['accessToken'] as String,
      refreshToken: body['refreshToken'] as String,
      rememberToken: body['rememberToken'] as String,
    );
  }

  /// Revoke a device-remember credential ("Remove this account").
  Future<void> forgetRemember(String rememberToken) async {
    await _client.post(
      '/auth/remember/forget',
      body: {'rememberToken': rememberToken},
    );
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
    String? gstEffectiveFrom,
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
    put('gstEffectiveFrom', gstEffectiveFrom);
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
      final code = _extractError(errBody);
      throw Exception(
        code == 'GST_EFFECTIVE_DATE_REQUIRED'
            ? 'Pick the date GST starts applying before saving a new GSTIN.'
            : code,
      );
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

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
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
    // Some errors ship a machine-readable sentinel in `error` plus human copy
    // in `message` (e.g. `verification_unavailable`). Prefer the copy —
    // showing a merchant a snake_case sentinel is worse than useless.
    final message = body['message'];
    if (message is String && message.isNotEmpty) return message;
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
