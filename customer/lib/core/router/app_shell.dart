import 'package:flutter/material.dart';
import 'package:shopxy_customer/features/catalog/presentation/pages/catalog_page.dart';
import 'package:shopxy_customer/features/home/presentation/pages/home_page.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/my_orders_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Tabs available in the customer-app shell. Indexed access via
/// `.index` is what [CustomerShellScope.select] expects, so adding a
/// tab here automatically gives every page a typed name to switch to.
enum CustomerShellTab { home, browse, orders, notifications, profile }

/// Exposes the tab-switching API to descendants. Pages that need to
/// jump tabs (the Home tile that goes to Browse, the empty Cart that
/// returns to Browse, etc.) read this scope rather than reaching into
/// the State directly.
class CustomerShellScope extends InheritedWidget {
  const CustomerShellScope({
    super.key,
    required this.index,
    required this.select,
    required super.child,
  });

  final int index;
  final ValueChanged<int> select;

  static CustomerShellScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CustomerShellScope>();

  @override
  bool updateShouldNotify(CustomerShellScope oldWidget) =>
      index != oldWidget.index;
}

class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    CatalogPage(),
    MyOrdersPage(),
    NotificationsPage(),
    CustomerProfilePage(),
  ];

  void _select(int i) {
    if (i == _currentIndex) return;
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return CustomerShellScope(
      index: _currentIndex,
      select: _select,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _pages),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.hairline, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _select,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: AppStrings.navHome,
              ),
              NavigationDestination(
                icon: Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(Icons.grid_view_rounded),
                label: AppStrings.navBrowse,
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: AppStrings.navOrders,
              ),
              NavigationDestination(
                icon: Icon(Icons.notifications_none_rounded),
                selectedIcon: Icon(Icons.notifications_rounded),
                label: AppStrings.navNotifications,
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: AppStrings.navProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
