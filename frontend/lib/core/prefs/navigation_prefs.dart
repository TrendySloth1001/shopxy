import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum NavigationStyle { bottomBar, sidebar }

enum ListDensity { comfortable, compact }

class NavigationPrefsProvider extends ChangeNotifier {
  NavigationPrefsProvider(this._storage);

  static const _navKey = 'nav.style';
  static const _densityKey = 'nav.density';

  final FlutterSecureStorage _storage;
  NavigationStyle _style = NavigationStyle.bottomBar;
  ListDensity _density = ListDensity.comfortable;

  final GlobalKey<ScaffoldState> shellScaffoldKey =
      GlobalKey<ScaffoldState>(debugLabel: 'app_shell');

  NavigationStyle get style => _style;
  ListDensity get density => _density;
  bool get isSidebar => _style == NavigationStyle.sidebar;
  bool get isCompact => _density == ListDensity.compact;

  Future<void> load() async {
    final navRaw = await _storage.read(key: _navKey);
    _style = navRaw == 'sidebar'
        ? NavigationStyle.sidebar
        : NavigationStyle.bottomBar;

    final densRaw = await _storage.read(key: _densityKey);
    _density =
        densRaw == 'compact' ? ListDensity.compact : ListDensity.comfortable;

    notifyListeners();
  }

  Future<void> setStyle(NavigationStyle value) async {
    if (_style == value) return;
    _style = value;
    notifyListeners();
    await _storage.write(
      key: _navKey,
      value: value == NavigationStyle.sidebar ? 'sidebar' : 'bottomBar',
    );
  }

  Future<void> setDensity(ListDensity value) async {
    if (_density == value) return;
    _density = value;
    notifyListeners();
    await _storage.write(
      key: _densityKey,
      value: value == ListDensity.compact ? 'compact' : 'comfortable',
    );
  }

  void openShellDrawer() {
    shellScaffoldKey.currentState?.openDrawer();
  }
}
