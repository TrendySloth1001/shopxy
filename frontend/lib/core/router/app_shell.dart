import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/router/menu_page.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/orders/presentation/pages/orders_inbox_page.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/features/pos/presentation/pages/pos_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

/// Static description of a primary bottom-bar destination.
class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.page,
    this.id,
  });

  /// Resolves the destination's user-facing label against the active
  /// localizations. A resolver (not a plain String) because the destination
  /// list is declared statically, outside any BuildContext.
  final String Function(AppLocalizations l10n) label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  /// Stable identifier used to attach dynamic affordances (like the
  /// pending-orders badge) without leaking layout into the static list.
  final String? id;
}

const _kOrdersDestinationId = 'orders';

// Labels are resolvers (see [_Destination.label]) so the list can't be const;
// it's built once as a top-level final instead. Everything beyond these five
// primary tabs lives in the Menu tab (see menu_page.dart).
// Bottom-bar order: Menu · Products · Home · Orders · Invoices, with Home
// (the dashboard) centred as the default landing tab.
final _destinations = <_Destination>[
  _Destination(
    label: (l10n) => l10n.navMenu,
    icon: Icons.apps_outlined,
    selectedIcon: Icons.apps,
    page: const MenuPage(),
  ),
  _Destination(
    label: (l10n) => l10n.navProducts,
    icon: Icons.inventory_2_outlined,
    selectedIcon: Icons.inventory_2_rounded,
    page: const ProductsPage(),
  ),
  _Destination(
    label: (l10n) => l10n.navHome,
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    page: const DashboardPage(),
  ),
  _Destination(
    label: (l10n) => l10n.navOrders,
    icon: Icons.inbox_outlined,
    selectedIcon: Icons.inbox_rounded,
    page: const OrdersInboxPage(),
    id: _kOrdersDestinationId,
  ),
  _Destination(
    label: (l10n) => l10n.navInvoices,
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    page: const InvoicesPage(),
  ),
];

/// The Home (dashboard) tab — used as the initial tab so the app opens on Home,
/// not the first bar slot. Resolved by type so it survives reordering.
final _homeIndex = _destinations.indexWhere((d) => d.page is DashboardPage);

class AppShellState extends State<AppShell> {
  int _currentIndex = _homeIndex < 0 ? 0 : _homeIndex;

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
    // Cashier kiosk lock: a plain Cashier gets the till only (with log-out),
    // not the full shell — a locked-down register.
    final user = context.watch<AuthProvider>().user;
    if (user?.shopRole == 'CASHIER') {
      return const PosPage(kiosk: true);
    }

    final l10n = AppLocalizations.of(context);
    final pendingOrders = context.watch<OrdersProvider>().pendingCount;
    final pages = _destinations.map((d) => d.page).toList(growable: false);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.hairline, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: _DestinationIcon(
                  icon: d.icon,
                  badge: d.id == _kOrdersDestinationId ? pendingOrders : 0,
                ),
                selectedIcon: _DestinationIcon(
                  icon: d.selectedIcon,
                  badge: d.id == _kOrdersDestinationId ? pendingOrders : 0,
                ),
                label: d.label(l10n),
              ),
          ],
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
