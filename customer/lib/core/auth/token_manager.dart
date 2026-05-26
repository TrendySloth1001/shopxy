import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  /// Marker key kept in SharedPreferences (which IS wiped on iOS uninstall).
  /// If this isn't set on first launch we assume a fresh install and wipe
  /// the keychain — without this, iOS preserves the prior owner's tokens
  /// across uninstall/reinstall and auto-logs the next user into their
  /// account.
  static const _kInstalledFlag = 'shopxy.app.installed';

  String? _accessToken;

  /// In-memory access token — fast, no async needed for request headers.
  String? get accessToken => _accessToken;

  /// Called when a 401 can't be recovered (refresh failed / no token).
  VoidCallback? onUnauthorized;

  /// Load tokens from secure storage on app start.
  Future<void> init() async {
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kInstalledFlag)) {
        // First launch on this install — Keychain may carry tokens from
        // a prior installation. Wipe before reading so we don't auto-sign-
        // in the new user as the previous one.
        await Future.wait([
          _storage.delete(key: _keyAccess),
          _storage.delete(key: _keyRefresh),
        ]);
        await prefs.setBool(_kInstalledFlag, true);
      }
    }
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

  /// Clear stored tokens (logout / session expired). Only deletes the
  /// two token keys — other secure-storage co-tenants must survive a
  /// session reset.
  Future<void> clear() async {
    _accessToken = null;
    await Future.wait([
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyRefresh),
    ]);
  }
}
