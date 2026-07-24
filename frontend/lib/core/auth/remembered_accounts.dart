import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// A remembered account for the one-tap return sign-in picker. The display
/// fields are safe to render; the device-remember token is kept alongside in
/// the OS keychain (never surfaced to the UI).
class RememberedAccount {
  const RememberedAccount({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  Map<String, dynamic> _toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatarUrl': avatarUrl,
  };

  static RememberedAccount _fromJson(Map<String, dynamic> j) => RememberedAccount(
    id: j['id'].toString(),
    name: (j['name'] as String?) ?? '',
    email: (j['email'] as String?) ?? '',
    avatarUrl: j['avatarUrl'] as String?,
  );
}

/// Persists remembered accounts (profile + device-remember token) in the OS
/// keychain — same secure-storage backing as [TokenManager]. The token only
/// ever leaves here to call `/auth/remember-login`; it's never shown.
class RememberedAccountsStore {
  RememberedAccountsStore([FlutterSecureStorage? storage])
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              // *ThisDeviceOnly so the device-remember token (a full
              // password-less credential) never rides a backup/transfer.
              accessibility: KeychainAccessibility.first_unlock_this_device,
            ),
          );

  final FlutterSecureStorage _storage;
  static const _key = 'remembered_accounts';

  Future<List<Map<String, dynamic>>> _read() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _write(List<Map<String, dynamic>> rows) =>
      _storage.write(key: _key, value: jsonEncode(rows));

  /// Display profiles only (no tokens) for the picker.
  Future<List<RememberedAccount>> list() async {
    final rows = await _read();
    return rows.map(RememberedAccount._fromJson).toList();
  }

  Future<String?> tokenFor(String id) async {
    for (final row in await _read()) {
      // .toString() so a row persisted by an older build (numeric id) still
      // matches the now-String id after the opaque-id migration.
      if (row['id']?.toString() == id) return row['token'] as String?;
    }
    return null;
  }

  /// Upsert (most-recent first), carrying the freshest profile + token.
  Future<void> save(RememberedAccount account, String token) async {
    final rows = await _read()
      ..removeWhere((r) => r['id']?.toString() == account.id);
    rows.insert(0, {...account._toJson(), 'token': token});
    await _write(rows);
  }

  Future<void> remove(String id) async {
    final rows = await _read()..removeWhere((r) => r['id']?.toString() == id);
    await _write(rows);
  }
}
