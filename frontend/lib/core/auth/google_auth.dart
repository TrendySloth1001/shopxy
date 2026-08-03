import 'package:google_sign_in/google_sign_in.dart';
import 'package:shopxy/core/config/app_config.dart';

/// Thin wrapper around `google_sign_in` v7's singleton API. `initialize()`
/// must complete before `authenticate()` is called — enforced here so
/// call sites don't need to remember the ordering.
class GoogleAuth {
  GoogleAuth._();

  static bool get isConfigured =>
      AppConfig.googleClientIdAndroid.isNotEmpty ||
      AppConfig.googleClientIdIos.isNotEmpty;

  static Future<void>? _initFuture;

  static Future<void> _ensureInitialized() {
    // `serverClientId` (the WEB client ID) makes the returned ID token's
    // audience the web client on every platform, so the backend verifies
    // Android/iOS/web sign-ins the same way. `clientId` is only needed on
    // iOS (google_sign_in reads Android's client ID from the SHA-1 +
    // package name registered in Cloud Console, not from code).
    return _initFuture ??= GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleClientIdIos.isNotEmpty
          ? AppConfig.googleClientIdIos
          : null,
      serverClientId: AppConfig.googleClientIdWeb.isNotEmpty
          ? AppConfig.googleClientIdWeb
          : null,
    );
  }

  /// Runs the interactive Google sign-in flow and returns a verified ID
  /// token, or `null` if the user cancelled. Throws for any other failure.
  static Future<String?> signInIdToken() async {
    await _ensureInitialized();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw Exception('Google did not return an ID token');
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }
}
