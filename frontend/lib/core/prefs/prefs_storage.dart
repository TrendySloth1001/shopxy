import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure-storage container for user preferences (theme / locale / navigation).
///
/// Crucially this sets the SAME options as [TokenManager] — in particular
/// `encryptedSharedPreferences: true` on Android. The bare `FlutterSecureStorage()`
/// (with the default `encryptedSharedPreferences: false`) writes to a different,
/// KeyStore-backed store that silently fails to persist across app restarts on
/// many Android devices. That's why theme/language/nav choices kept resetting to
/// default while the login (which already uses the encrypted store) survived.
/// All three prefs providers now share this instance so settings actually stick.
const appPrefsStorage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);
