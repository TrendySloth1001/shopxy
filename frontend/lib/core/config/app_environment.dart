import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shopxy/core/prefs/prefs_storage.dart';

class AppEnvironment {
  const AppEnvironment({
    required this.id,
    required this.label,
    required this.description,
    required this.baseUrl,
  });

  final String id;
  final String label;
  final String description;

  final String baseUrl;
}

const kDeveloperEmail = 'nkumawat1010@gmail.com';

bool isDeveloperAccount(String? email) =>
    email != null && email.trim().toLowerCase() == kDeveloperEmail;

class AppEnvironments {
  AppEnvironments._();

  static const _key = 'app.apiEnvironmentId';

  static const all = <AppEnvironment>[
    AppEnvironment(
      id: 'production',
      label: 'Production',
      description: 'Live merchants and real money',
      baseUrl: 'https://backendshopxy.cloudnsofts.com/',
    ),
    AppEnvironment(
      id: 'tunnel',
      label: 'Dev tunnel',
      description: 'The shared dev backend',
      baseUrl: 'https://qjhcp0ph-3003.inc1.devtunnels.ms/',
    ),
    AppEnvironment(
      id: 'local-android',
      label: 'Local — Android emulator',
      description: '10.0.2.2:3003, the host machine seen from the emulator',
      baseUrl: 'http://10.0.2.2:3003/',
    ),
    AppEnvironment(
      id: 'local-host',
      label: 'Local — iOS simulator / desktop',
      description: 'localhost:3003',
      baseUrl: 'http://localhost:3003/',
    ),
  ];

  static AppEnvironment get production => all.first;

  static String? _overrideBaseUrl;

  static String? get overrideBaseUrl => _overrideBaseUrl;

  static Future<void> load([
    FlutterSecureStorage storage = appPrefsStorage,
  ]) async {
    String? id;
    try {
      id = await storage.read(key: _key);
    } catch (_) {
      return;
    }
    if (id == null) return;
    for (final env in all) {
      if (env.id == id) {
        _overrideBaseUrl = env.baseUrl;
        return;
      }
    }
  }

  static Future<void> select(
    AppEnvironment env, [
    FlutterSecureStorage storage = appPrefsStorage,
  ]) async {
    _overrideBaseUrl = env.baseUrl;
    await storage.write(key: _key, value: env.id);
  }

  static AppEnvironment? matching(String baseUrl) {
    final needle = _normalise(baseUrl);
    for (final env in all) {
      if (_normalise(env.baseUrl) == needle) return env;
    }
    return null;
  }

  static String _normalise(String url) =>
      url.trim().toLowerCase().replaceAll(RegExp(r'/+$'), '');
}
