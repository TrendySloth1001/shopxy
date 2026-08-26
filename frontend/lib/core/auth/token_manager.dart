import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenManager {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  static const _kInstalledFlag = 'shopxy.merchant.installed';

  String? _accessToken;

  String? get accessToken => _accessToken;

  String get currentUserId {
    final token = _accessToken;
    if (token == null) return 'anon';
    try {
      final parts = token.split('.');
      if (parts.length != 3) return 'anon';
      final payload =
          jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))))
              as Map<String, dynamic>;
      final sub = payload['sub'];
      return sub == null ? 'anon' : '$sub';
    } catch (_) {
      return 'anon';
    }
  }

  VoidCallback? onUnauthorized;

  Future<void> init() async {
    if (Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      if (!prefs.containsKey(_kInstalledFlag)) {
        await Future.wait([
          _storage.delete(key: _keyAccess),
          _storage.delete(key: _keyRefresh),
        ]);
        await prefs.setBool(_kInstalledFlag, true);
      }
    }
    _accessToken = await _storage.read(key: _keyAccess);
  }

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

  Future<void> clear() async {
    _accessToken = null;
    await Future.wait([
      _storage.delete(key: _keyAccess),
      _storage.delete(key: _keyRefresh),
    ]);
  }
}
