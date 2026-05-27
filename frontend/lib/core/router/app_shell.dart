import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/orders/presentation/pages/orders_inbox_page.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy/features/reports/presentation/pages/reports_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_profile_page.dart';
import 'package:shopxy/features/flash_deals/presentation/pages/flash_deals_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_bank_offers_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_banners_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_category_taxonomy_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_collections_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_shops_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_spotlight_approval_page.dart';
import 'package:shopxy/features/carousel/presentation/pages/my_carousel_page.dart';
import 'package:shopxy/features/spotlight/presentation/pages/spotlight_request_page.dart';
import 'package:shopxy/features/analytics/presentation/pages/merchant_analytics_page.dart';
import 'package:shopxy/features/promotions/presentation/pages/promotion_manager_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustments_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
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
    this.id,
  });
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;
  /// Stable identifier used to attach dynamic affordances (like the
  /// pending-orders badge) without leaking layout into the static list.
  final String? id;
}

const _kOrdersDestinationId = 'orders';

/// One row in the drawer's "operations" sections — a shortcut that
/// pushes a page on top of the current tab instead of switching tabs.
/// Drawer-only; the bottom-bar layout doesn't surface these.
class _Shortcut {
  const _Shortcut({
    required this.label,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.builder,
  });
  final String label;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final WidgetBuilder builder;
}

List<_Shortcut> get _manageShortcuts => [
      _Shortcut(
        label: 'My Shop',
        icon: Icons.storefront_outlined,
        accent: AppColors.brand,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const ShopProfilePage(),
      ),
      _Shortcut(
        label: 'My Carousel',
        icon: Icons.view_carousel_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const MyCarouselPage(),
      ),
      _Shortcut(
        label: 'Flash deals',
        icon: Icons.bolt_outlined,
        accent: const Color(0xFFE05A2A),
        accentSoft: const Color(0xFFFFE3D2),
        builder: (_) => const FlashDealsPage(),
      ),
      _Shortcut(
        label: 'Brand spotlight',
        icon: Icons.star_outline,
        accent: AppColors.accentAmber,
        accentSoft: AppColors.accentAmberSoft,
        builder: (_) => const SpotlightRequestPage(),
      ),
      _Shortcut(
        label: 'Promotions',
        icon: Icons.campaign_outlined,
        accent: AppColors.accentRose,
        accentSoft: AppColors.accentRoseSoft,
        builder: (_) => const PromotionManagerPage(),
      ),
      _Shortcut(
        label: AppStrings.navCategories,
        icon: Icons.category_outlined,
        accent: AppColors.accentTeal,
        accentSoft: AppColors.accentTealSoft,
        builder: (_) => const CategoriesPage(),
      ),
      _Shortcut(
        label: AppStrings.navVendors,
        icon: Icons.storefront_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const VendorsPage(),
      ),
      _Shortcut(
        label: AppStrings.navParties,
        icon: Icons.groups_outlined,
        accent: AppColors.accentRose,
        accentSoft: AppColors.accentRoseSoft,
        builder: (_) => const PartiesPage(),
      ),
    ];

List<_Shortcut> get _operationShortcuts => [
      _Shortcut(
        label: AppStrings.navInvoices,
        icon: Icons.receipt_long_outlined,
        accent: AppColors.brandStrong,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const InvoicesPage(),
      ),
      _Shortcut(
        label: AppStrings.navChallans,
        icon: Icons.assignment_outlined,
        accent: AppColors.accentAmber,
        accentSoft: AppColors.accentAmberSoft,
        builder: (_) => const ChallansPage(),
      ),
      _Shortcut(
        label: 'Stock adjustments',
        icon: Icons.tune_rounded,
        accent: AppColors.brand,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const StockAdjustmentsPage(),
      ),
      _Shortcut(
        label: 'Reports',
        icon: Icons.insights_outlined,
        accent: AppColors.brandStrong,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const ReportsPage(),
      ),
      _Shortcut(
        label: 'Analytics',
        icon: Icons.bar_chart_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const MerchantAnalyticsPage(),
      ),
    ];

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
    label: AppStrings.navOrders,
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox_rounded,
    page: OrdersInboxPage(),
    id: _kOrdersDestinationId,
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
  void initState() {
    super.initState();
    // Seed the orders badge with the first count so it renders correctly
    // on cold start; the inbox refreshes its own count on enter.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrdersProvider>().refreshPendingCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    final pendingOrders = context.watch<OrdersProvider>().pendingCount;
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
          // Bottom-bar mode also gets the drawer — primary destinations
          // live in the bar, the rest (My Shop, Promotions, Spotlight,
          // Analytics, Platform admin tools) are one tap away via the
          // menu icon in every top-level AppBar. Without this the new
          // features had no entry point in bottom-bar mode.
          : Scaffold(
              key: prefs.shellScaffoldKey,
              drawer: const _NavDrawer(),
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
                        icon: _DestinationIcon(
                          icon: d.icon,
                          badge: d.id == _kOrdersDestinationId
                              ? pendingOrders
                              : 0,
                        ),
                        selectedIcon: _DestinationIcon(
                          icon: d.selectedIcon,
                          badge: d.id == _kOrdersDestinationId
                              ? pendingOrders
                              : 0,
                        ),
                        label: d.label,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Wraps a destination icon with a Material 3 numeric badge. We hand-roll
/// the badge wrapper (instead of using NavigationDestination's `badge`
/// slot, which only renders for the unselected icon on some platforms)
/// so the indicator stays visible in both states. Hidden when count == 0.
class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.icon, required this.badge});
  final IconData icon;
  final int badge;

  @override
  Widget build(BuildContext context) {
    if (badge <= 0) return Icon(icon);
    final label = badge > 99 ? '99+' : '$badge';
    return Badge(
      label: Text(label),
      backgroundColor: AppColors.warning,
      textColor: AppColors.white,
      child: Icon(icon),
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
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (int i = 0; i < _destinations.length; i++)
                    _DrawerTile(
                      destination: _destinations[i],
                      selected: active.index == i,
                      badge: _destinations[i].id == _kOrdersDestinationId
                          ? context.watch<OrdersProvider>().pendingCount
                          : 0,
                      onTap: () {
                        active.select(i);
                        Navigator.pop(context);
                      },
                    ),
                  const SizedBox(height: 12),
                  const _DrawerSectionLabel(text: 'Manage'),
                  for (final s in _manageShortcuts)
                    _DrawerShortcutTile(shortcut: s),
                  const SizedBox(height: 8),
                  const _DrawerSectionLabel(text: 'Operations'),
                  for (final s in _operationShortcuts)
                    _DrawerShortcutTile(shortcut: s),
                  if (context.watch<AuthProvider>().user?.isPlatformAdmin ==
                      true) ...[
                    const SizedBox(height: 8),
                    const _DrawerSectionLabel(text: 'Platform admin'),
                    _DrawerShortcutTile(
                      shortcut: _Shortcut(
                        label: 'Banner manager',
                        icon: Icons.view_carousel_outlined,
                        accent: AppColors.accentIndigo,
                        accentSoft: AppColors.accentIndigoSoft,
                        builder: (_) => const AdminBannersPage(),
                      ),
                    ),
                    _DrawerShortcutTile(
                      shortcut: _Shortcut(
                        label: 'Category taxonomy',
                        icon: Icons.account_tree_outlined,
                        accent: AppColors.accentTeal,
                        accentSoft: AppColors.accentTealSoft,
                        builder: (_) => const AdminCategoryTaxonomyPage(),
                      ),
                    ),
                    _DrawerShortcutTile(
                      shortcut: _Shortcut(
                        label: 'Spotlight approvals',
                        icon: Icons.verified_outlined,
                        accent: AppColors.accentAmber,
                        accentSoft: AppColors.accentAmberSoft,
                        builder: (_) => const AdminSpotlightApprovalPage(),
                      ),
                    ),
                    _DrawerShortcutTile(
                      shortcut: _Shortcut(
                        label: 'Collections',
                        icon: Icons.collections_bookmark_outlined,
                        accent: AppColors.accentRose,
                        accentSoft: AppColors.accentRoseSoft,
                        builder: (_) => const AdminCollectionsPage(),
                      ),
                    ),
                    _DrawerShortcutTile(
                      shortcut: _Shortcut(
                        label: 'Bank offers',
                        icon: Icons.account_balance_outlined,
                        accent: AppColors.info,
                        accentSoft: AppColors.infoSoft,
                        builder: (_) => const AdminBankOffersPage(),
                      ),
                    ),
                    _DrawerShortcutTile(
                      shortcut: _Shortcut(
                        label: 'Shop verification',
                        icon: Icons.verified_user_outlined,
                        accent: AppColors.brandStrong,
                        accentSoft: AppColors.brandSoft,
                        builder: (_) => const AdminShopsPage(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
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
    this.badge = 0,
  });
  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

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
                Expanded(
                  child: Text(
                    destination.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected ? AppColors.white : AppColors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.white : AppColors.warning,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: TextStyle(
                        color: selected ? AppColors.black : AppColors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
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

class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

/// Drawer row that pushes a page on top of the active tab instead of
/// switching tabs. Visually lighter than [_DrawerTile] (no selection
/// state, colored leading square) so the eye reads them as shortcuts
/// rather than primary destinations.
class _DrawerShortcutTile extends StatelessWidget {
  const _DrawerShortcutTile({required this.shortcut});
  final _Shortcut shortcut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        shape: AppShapes.squircle(14),
        child: InkWell(
          customBorder: AppShapes.squircle(14),
          onTap: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(MaterialPageRoute(builder: shortcut.builder));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: ShapeDecoration(
                    color: shortcut.accentSoft,
                    shape: AppShapes.squircle(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(shortcut.icon, size: 16, color: shortcut.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    shortcut.label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Leading button surfaced in every top-level page's AppBar. Opens the
/// AppShell drawer in both layouts — the bottom-bar carries the four
/// primary destinations, the drawer carries everything else (My Shop,
/// Promotions, Spotlight, Analytics, and the Platform admin tools).
class ShellMenuButton extends StatelessWidget {
  const ShellMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    return IconButton(
      icon: const Icon(Icons.menu_rounded),
      tooltip: 'Menu',
      onPressed: prefs.openShellDrawer,
    );
  }
}
