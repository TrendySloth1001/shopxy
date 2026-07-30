import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Owns the app-wide haptics on/off switch and persists it to the same
/// secure-storage container used for theme/nav prefs (no new dependency).
/// Loaded in `main()` before the first frame, same as [ThemePrefsProvider].
///
/// There is no cross-platform API for reading the OS-level "system haptics"
/// setting on either iOS or Android, so this can't genuinely default to
/// "whatever the system is set to" — it defaults to **on**, which is the
/// closest honest approximation (both platforms ship with haptics on by
/// default too).
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
