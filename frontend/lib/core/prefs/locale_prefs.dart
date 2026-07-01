import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The UI languages the merchant app ships, mirroring the web app. English is
/// the default; Hindi is the first added locale for the multilingual pilot.
/// (More Indian languages plug in here + a matching `app_<code>.arb`.)
enum AppLanguage { english, hindi }

/// Owns the selected UI language and persists it to the same secure-storage
/// container used for auth tokens / theme / nav prefs (no new dependency).
///
/// Unlike [ThemePrefsProvider] this is created and loaded inside `ShopxyApp`
/// (app.dart) rather than `main.dart`, so the locale wiring stays out of the
/// heavily-shared bootstrap file. A saved non-default language may show one
/// English frame on the very first cold start before [load] resolves — an
/// acceptable trade for not touching main.dart.
class LocalePrefsProvider extends ChangeNotifier {
  LocalePrefsProvider(this._storage);

  static const _key = 'app.locale';

  final FlutterSecureStorage _storage;
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  /// The [Locale] handed to `MaterialApp.locale`.
  Locale get locale => localeFor(_language);

  /// True when the active language is written in Devanagari and therefore needs
  /// the Noto Sans Devanagari font (Inter doesn't cover the script).
  bool get isDevanagari => _language == AppLanguage.hindi;

  static Locale localeFor(AppLanguage lang) => switch (lang) {
        AppLanguage.english => const Locale('en'),
        AppLanguage.hindi => const Locale('hi'),
      };

  Future<void> load() async {
    _language = _parse(await _storage.read(key: _key));
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (_language == value) return;
    _language = value;
    notifyListeners();
    await _storage.write(key: _key, value: value.name);
  }

  static AppLanguage _parse(String? raw) => switch (raw) {
        'hindi' => AppLanguage.hindi,
        _ => AppLanguage.english,
      };
}
