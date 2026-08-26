import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HapticsPrefsProvider extends ChangeNotifier {
  HapticsPrefsProvider(this._storage);

  static const _key = 'app.hapticsEnabled';

  final FlutterSecureStorage _storage;
  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load() async {
    final raw = await _storage.read(key: _key);
    if (raw != null) _enabled = raw == 'true';
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
    await _storage.write(key: _key, value: value.toString());
  }
}
