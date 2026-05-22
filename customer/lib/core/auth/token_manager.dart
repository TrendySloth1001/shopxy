import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  String? _accessToken;

  /// In-memory access token — fast, no async needed for request headers.
  String? get accessToken => _accessToken;

  /// Called when a 401 can't be recovered (refresh failed / no token).
  VoidCallback? onUnauthorized;

  /// Load tokens from secure storage on app start.
  Future<void> init() async {
    _accessToken = await _storage.read(key: _keyAccess);
  }

  /// Persist both tokens and update in-memory access token.
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    await Future.wait([
      _storage.write(key: _keyAccess, value: accessToken),
      _storage.write(key: _keyRefresh, value: refreshToken),
    ]);
  }

  Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  /// Clear all stored tokens (logout / session expired).
  Future<void> clear() async {
    _accessToken = null;
    await _storage.deleteAll();
  }
}
