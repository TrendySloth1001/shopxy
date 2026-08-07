import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shopxy/core/prefs/prefs_storage.dart';

/// One backend this app can be pointed at.
///
/// Each environment runs its own database, so choosing a backend chooses the
/// data you see — which is the whole point of the developer switcher in
/// Settings. Selecting one signs you out: a JWT minted by one environment is
/// meaningless to another, and every cached list would be from the wrong
/// database.
class AppEnvironment {
  const AppEnvironment({
    required this.id,
    required this.label,
    required this.description,
    required this.baseUrl,
  });

  /// Stable key written to storage. Never renamed — a stored id that no
  /// longer matches anything is ignored (see [AppEnvironments.load]).
  final String id;
  final String label;
  final String description;

  /// The trailing slash matters — endpoints are concatenated as
  /// `${apiBaseUrl}auth/login`, not joined with a path separator.
  final String baseUrl;
}

/// The account the environment switcher is shown to.
///
/// This hides developer UI; it is not a security boundary and doesn't need to
/// be. The switch only changes which backend *this install* talks to — anyone
/// building the app from source could point it anywhere already — so there is
/// no privilege here to protect, and nothing is asked of the server.
const kDeveloperEmail = 'nkumawat1010@gmail.com';

bool isDeveloperAccount(String? email) =>
    email != null && email.trim().toLowerCase() == kDeveloperEmail;

/// The developer environment switcher.
///
/// This is an allow-list, not a free-text field, and deliberately so: the app
/// attaches the signed-in merchant's bearer token to every request, so a
/// switcher that accepted a typed-in URL would be a one-tap way to hand that
/// token — and the whole shop's data — to any host on the internet. Adding an
/// environment is a code change.
class AppEnvironments {
  AppEnvironments._();

  static const _key = 'app.apiEnvironmentId';

  /// The first entry is the production default that [AppConfig.apiBaseUrl]
  /// falls back to, so the two can't drift apart.
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

  /// The base URL chosen in Settings, or null when no choice has been made
  /// and the build-time default applies.
  static String? get overrideBaseUrl => _overrideBaseUrl;

  /// Read the saved choice. MUST be awaited in `main()` before anything
  /// resolves a URL, otherwise the first requests of the run go to the
  /// previous environment.
  static Future<void> load([
    FlutterSecureStorage storage = appPrefsStorage,
  ]) async {
    String? id;
    try {
      id = await storage.read(key: _key);
    } catch (_) {
      // A locked or unreadable keystore must not stop the app booting — it
      // just boots against the build-time default.
      return;
    }
    if (id == null) return;
    for (final env in all) {
      if (env.id == id) {
        _overrideBaseUrl = env.baseUrl;
        return;
      }
    }
    // A retired environment id. Fall through to the build-time default rather
    // than launching against nothing.
  }

  static Future<void> select(
    AppEnvironment env, [
    FlutterSecureStorage storage = appPrefsStorage,
  ]) async {
    _overrideBaseUrl = env.baseUrl;
    await storage.write(key: _key, value: env.id);
  }

  /// Which entry [baseUrl] corresponds to, or null if it matches none (a
  /// dart-define pointing somewhere bespoke). Callers pass
  /// `AppConfig.apiBaseUrl`; taking it as an argument keeps this file free of
  /// an import cycle back to `AppConfig`.
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
