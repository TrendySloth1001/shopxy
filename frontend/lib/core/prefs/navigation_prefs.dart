import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the app's primary destinations live.
/// - [bottomBar] — phone-first Material 3 bottom bar.
/// - [sidebar]   — collapsible left drawer opened from a menu icon in
///   each top-level page's AppBar. Closed by default so the body owns
///   the full width; the user pulls it in when they need to switch.
enum NavigationStyle { bottomBar, sidebar }

/// User preferences holder. Persists to the same secure-storage
/// container we already use for auth tokens, so we don't take a new
/// dependency. Also owns a global key for the AppShell's outer
/// Scaffold so any page can call [openShellDrawer] regardless of how
/// deep it sits in the widget tree.
class NavigationPrefsProvider extends ChangeNotifier {
  NavigationPrefsProvider(this._storage);

  static const _navKey = 'nav.style';

  final FlutterSecureStorage _storage;
  NavigationStyle _style = NavigationStyle.bottomBar;

  /// Held by the outer Scaffold in [AppShell] when sidebar mode is on.
  /// Top-level pages use this to surface the drawer from their own
  /// AppBars without needing to drill a callback through the tree.
  final GlobalKey<ScaffoldState> shellScaffoldKey =
      GlobalKey<ScaffoldState>(debugLabel: 'app_shell');

  NavigationStyle get style => _style;
  bool get isSidebar => _style == NavigationStyle.sidebar;

  Future<void> load() async {
    final navRaw = await _storage.read(key: _navKey);
    _style = navRaw == 'sidebar'
        ? NavigationStyle.sidebar
        : NavigationStyle.bottomBar;

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

  /// Open the AppShell drawer from any page. Safe to call when there's
  /// no drawer mounted (the key won't have a current state in that
  /// case) — returns silently.
  void openShellDrawer() {
    shellScaffoldKey.currentState?.openDrawer();
  }
}
