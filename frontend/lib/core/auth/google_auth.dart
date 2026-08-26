import 'package:google_sign_in/google_sign_in.dart';
import 'package:shopxy/core/config/app_config.dart';

class GoogleAuth {
  GoogleAuth._();

  static bool get isConfigured =>
      AppConfig.googleClientIdAndroid.isNotEmpty ||
      AppConfig.googleClientIdIos.isNotEmpty;

  static Future<void>? _initFuture;

  static Future<void> _ensureInitialized() {
    return _initFuture ??= GoogleSignIn.instance.initialize(
      clientId: AppConfig.googleClientIdIos.isNotEmpty
          ? AppConfig.googleClientIdIos
          : null,
      serverClientId: AppConfig.googleClientIdWeb.isNotEmpty
          ? AppConfig.googleClientIdWeb
          : null,
    );
  }

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
