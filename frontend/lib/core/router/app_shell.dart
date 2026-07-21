import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
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
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

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
    required this.pageBuilder,
    this.id,
    this.isHome = false,
  });

  /// Resolves the destination's user-facing label against the active
  /// localizations. A resolver (not a plain String) because the destination
  /// list is declared statically, outside any BuildContext.
  final String Function(AppLocalizations l10n) label;
  final AppIconData icon;
  final AppIconData selectedIcon;

  /// Builds a FRESH page widget on each call. Fresh instances (not a cached
  /// const) are what let the IndexedStack children rebuild when the shell
  /// rebuilds on a theme change — const pages short-circuit the rebuild and
  /// keep stale [AppColors] until an app restart.
  final Widget Function() pageBuilder;

  /// Stable identifier used to attach dynamic affordances (like the
  /// pending-orders badge) without leaking layout into the static list.
  final String? id;

  /// The default landing tab (the dashboard).
  final bool isHome;
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
    icon: AppIcons.appsOutlined,
    selectedIcon: AppIcons.apps,
    pageBuilder: MenuPage.new,
  ),
  _Destination(
    label: (l10n) => l10n.navProducts,
    icon: AppIcons.inventory2Outlined,
    selectedIcon: AppIcons.inventory2Rounded,
    pageBuilder: ProductsPage.new,
  ),
  _Destination(
    label: (l10n) => l10n.navHome,
    icon: AppIcons.homeOutlined,
    selectedIcon: AppIcons.homeRounded,
    pageBuilder: DashboardPage.new,
    isHome: true,
  ),
  _Destination(
    label: (l10n) => l10n.navOrders,
    icon: AppIcons.inboxOutlined,
    selectedIcon: AppIcons.inboxRounded,
    pageBuilder: OrdersInboxPage.new,
    id: _kOrdersDestinationId,
  ),
  _Destination(
    label: (l10n) => l10n.navInvoices,
    icon: AppIcons.receiptLongOutlined,
    selectedIcon: AppIcons.receiptLong,
    pageBuilder: InvoicesPage.new,
  ),
];

/// The Home (dashboard) tab — used as the initial tab so the app opens on Home,
/// not the first bar slot.
final _homeIndex = _destinations.indexWhere((d) => d.isHome);

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

    // Depend on the theme so a palette change rebuilds the shell — and with
    // it the freshly-built pages below — instead of leaving them on stale
    // AppColors until an app restart.
    context.watch<ThemePrefsProvider>();
    final l10n = AppLocalizations.of(context);
    // Fresh page instances each build (see [_Destination.pageBuilder]).
    final pages = _destinations
        .map((d) => d.pageBuilder())
        .toList(growable: false);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 64,
          onDestinationSelected: _select,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                // The orders badge watches the count itself (via a Selector)
                // so a count change repaints only that icon — not the whole
                // shell, which would rebuild every page in the IndexedStack.
                icon: d.id == _kOrdersDestinationId
                    ? _OrdersBadgeIcon(icon: d.icon)
                    : AppIcon(d.icon),
                selectedIcon: d.id == _kOrdersDestinationId
                    ? _OrdersBadgeIcon(icon: d.selectedIcon)
                    : AppIcon(d.selectedIcon),
                label: d.label(l10n),
              ),
          ],
        ),
      ),
    );
  }
}

/// Orders bottom-nav icon that subscribes to just the pending count, so an
/// order arriving repaints this icon alone rather than the whole shell.
class _OrdersBadgeIcon extends StatelessWidget {
  const _OrdersBadgeIcon({required this.icon});
  final AppIconData icon;

  @override
  Widget build(BuildContext context) {
    final badge = context.select<OrdersProvider, int>((o) => o.pendingCount);
    return _DestinationIcon(icon: icon, badge: badge);
  }
}

/// Wraps a destination icon with a Material 3 numeric badge. We hand-roll
/// the badge wrapper (instead of using NavigationDestination's `badge`
/// slot, which only renders for the unselected icon on some platforms)
/// so the indicator stays visible in both states. Hidden when count == 0.
class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.icon, required this.badge});
  final AppIconData icon;
  final int badge;

  @override
  Widget build(BuildContext context) {
    if (badge <= 0) return AppIcon(icon);
    final label = badge > 99 ? '99+' : '$badge';
    return Badge(
      label: Text(label),
      backgroundColor: AppColors.warning,
      textColor: AppColors.white,
      child: AppIcon(icon),
    );
  }
}
