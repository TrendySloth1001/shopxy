import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/config/app_environment.dart';

/// The release-build safety guard. Getting it wrong is invisible until an APK
/// is built: `assertSafeForRelease` runs before `runApp`, so anything it
/// throws leaves a blank launch window.
///
/// It can't be called directly here (gated on `kReleaseMode`), so these test
/// [AppConfig.looksLikeDevHost] — the half that decides whether it fires.
void main() {
  group('looksLikeDevHost', () {
    test('flags every environment the app itself calls non-production', () {
      // Derived from the real list so a new environment can't escape the guard.
      final devEnvs = AppEnvironments.all
          .where((e) => e.id != AppEnvironments.production.id)
          .toList();

      expect(devEnvs, isNotEmpty, reason: 'sanity: there are dev environments');
      for (final env in devEnvs) {
        expect(
          AppConfig.looksLikeDevHost(env.baseUrl),
          isTrue,
          reason: '${env.id} (${env.baseUrl}) must be refused in release',
        );
      }
    });

    test('does not flag production', () {
      expect(
        AppConfig.looksLikeDevHost(AppEnvironments.production.baseUrl),
        isFalse,
      );
    });

    test('matches regardless of case', () {
      expect(AppConfig.looksLikeDevHost('https://LOCALHOST:3003/'), isTrue);
      expect(AppConfig.looksLikeDevHost('HTTP://127.0.0.1/'), isTrue);
    });

    test('flags the emulator host alias', () {
      expect(AppConfig.looksLikeDevHost('http://10.0.2.2:3003/'), isTrue);
    });

    test('leaves ordinary hosts alone', () {
      expect(
        AppConfig.looksLikeDevHost('https://backendshopxy.cloudnsofts.com/'),
        isFalse,
      );
      expect(AppConfig.looksLikeDevHost('https://api.example.com/'), isFalse);
    });
  });

  group('apiBaseUrl', () {
    test('falls back to production when no dart-define was given', () {
      // Why a missing API_BASE_URL is safe, and no longer fatal.
      expect(AppEnvironments.overrideBaseUrl, isNull);
      expect(AppConfig.apiBaseUrl, AppEnvironments.production.baseUrl);
    });

    test('production is a real https host, not a placeholder', () {
      final url = AppEnvironments.production.baseUrl;
      expect(url, startsWith('https://'));
      expect(AppConfig.looksLikeDevHost(url), isFalse);
      // Endpoints are concatenated, not path-joined.
      expect(url, endsWith('/'));
    });
  });
}
