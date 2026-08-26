import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppLanguage { english, hindi }

class LocalePrefsProvider extends ChangeNotifier {
  LocalePrefsProvider(this._storage);

  static const _key = 'app.locale';

  final FlutterSecureStorage _storage;
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;

  Locale get locale => localeFor(_language);

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
