import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

/// Static description of each primary destination. Both layouts (bottom
/// bar + drawer) read from this same list so they can never drift.
class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
}

const _destinations = <_Destination>[
  _Destination(
    label: AppStrings.navDashboard,
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard_rounded,
    page: DashboardPage(),
  ),
  _Destination(
    label: AppStrings.navProducts,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    page: ProductsPage(),
  ),
  _Destination(
    label: AppStrings.navInvoices,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    page: InvoicesPage(),
  ),
  _Destination(
    label: AppStrings.navProfile,
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    page: ProfilePage(),
  ),
];

/// We need to publish the active index so the drawer (mounted by the
/// outer Scaffold, sibling to the page) can highlight the right tile
/// and call back into the AppShell to switch pages without a route.
class _ActiveTab extends InheritedWidget {
  const _ActiveTab({
    required this.index,
    required this.select,
    required super.child,
  });
  final int index;
  final ValueChanged<int> select;

  static _ActiveTab of(BuildContext context) {
    final i = context.dependOnInheritedWidgetOfExactType<_ActiveTab>();
    assert(i != null, '_ActiveTab not found in widget tree');
    return i!;
  }

  @override
  bool updateShouldNotify(_ActiveTab oldWidget) => index != oldWidget.index;
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _select(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    final pages = _destinations.map((d) => d.page).toList(growable: false);

    final body = IndexedStack(index: _currentIndex, children: pages);

    return _ActiveTab(
      index: _currentIndex,
      select: _select,
      child: prefs.isSidebar
          ? Scaffold(
              key: prefs.shellScaffoldKey,
              drawer: const _NavDrawer(),
              body: body,
            )
          : Scaffold(
              body: body,
              bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.hairline, width: 1),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: _currentIndex,
                  labelBehavior:
                      NavigationDestinationLabelBehavior.alwaysShow,
                  height: 64,
                  onDestinationSelected: _select,
                  destinations: [
                    for (final d in _destinations)
                      NavigationDestination(
                        icon: Icon(d.icon),
                        selectedIcon: Icon(d.selectedIcon),
                        label: d.label,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Drawer body. Brand stripe at the top, then a vertical list of
/// destinations with the active one highlighted. Tapping a row closes
/// the drawer and switches the page in the same animation.
class _NavDrawer extends StatelessWidget {
  const _NavDrawer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _ActiveTab.of(context);

    return Drawer(
      backgroundColor: AppColors.canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: ShapeDecoration(
                      color: AppColors.black,
                      shape: AppShapes.squircle(12),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'S',
                      style: TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    AppStrings.appName,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              color: AppColors.hairline,
            ),
            const SizedBox(height: 8),
            for (int i = 0; i < _destinations.length; i++)
              _DrawerTile(
                destination: _destinations[i],
                selected: active.index == i,
                onTap: () {
                  active.select(i);
                  Navigator.pop(context);
                },
              ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'v1.0',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: AppColors.subtle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.destination,
    required this.selected,
    required this.onTap,
  });
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? AppColors.black : Colors.transparent,
        shape: AppShapes.squircle(14),
        child: InkWell(
          customBorder: AppShapes.squircle(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  size: 20,
                  color: selected ? AppColors.white : AppColors.black,
                ),
                const SizedBox(width: 14),
                Text(
                  destination.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: selected ? AppColors.white : AppColors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading button surfaced in every top-level page's AppBar. In
/// bottom-bar mode it renders nothing (so Flutter doesn't insert a
/// stray back arrow); in sidebar mode it shows a menu icon that opens
/// the AppShell drawer.
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    if (!prefs.isSidebar) return const SizedBox.shrink();
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Menu',
      onPressed: prefs.openShellDrawer,
    );
  }
}
