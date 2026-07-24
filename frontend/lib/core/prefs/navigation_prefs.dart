import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the app's primary destinations live.
/// - [bottomBar] — phone-first Material 3 bottom bar.
/// - [sidebar]   — collapsible left drawer opened from a menu icon in
///   each top-level page's AppBar. Closed by default so the body owns
///   the full width; the user pulls it in when they need to switch.
enum NavigationStyle { bottomBar, sidebar }

/// Row density on inventory-heavy lists.
/// - [comfortable] — generous spacing, default.
/// - [compact]     — tighter padding + smaller thumbnails so more rows
///   fit per screen for fast inventory scanning.
enum ListDensity { comfortable, compact }

/// User preferences holder. Persists to the same secure-storage
/// container we already use for auth tokens, so we don't take a new
/// dependency. Also owns a global key for the AppShell's outer
/// Scaffold so any page can call [openShellDrawer] regardless of how
/// deep it sits in the widget tree.
class NavigationPrefsProvider extends ChangeNotifier {
  NavigationPrefsProvider(this._storage);

  static const _navKey = 'nav.style';
  static const _densityKey = 'nav.density';

  final FlutterSecureStorage _storage;
  NavigationStyle _style = NavigationStyle.bottomBar;
  ListDensity _density = ListDensity.comfortable;

  /// Held by the outer Scaffold in [AppShell] when sidebar mode is on.
  /// Top-level pages use this to surface the drawer from their own
  /// AppBars without needing to drill a callback through the tree.
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

  /// Open the AppShell drawer from any page. Safe to call when there's
  /// no drawer mounted (the key won't have a current state in that
  /// case) — returns silently.
  void openShellDrawer() {
    shellScaffoldKey.currentState?.openDrawer();
  }
}
