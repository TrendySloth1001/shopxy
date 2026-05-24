import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/cart_v2/presentation/pages/cart_v2_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/pages/home_v2_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Tabs available in the customer-app shell. Browse used to live here
/// but Home V2 already covers categories, deals and trending, so the
/// dedicated tab was retired.
enum CustomerShellTab { home, cart, profile }

/// Exposes the tab-switching API to descendants. Pages that need to
/// jump tabs (the empty Cart that returns to Home, etc.) read this
/// scope rather than reaching into the State directly.
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
    HomeV2Page(),
    CartV2Page(embedded: true),
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
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: AppStrings.navHome,
              ),
              // Badge mirrors the cart's line count — the same source the
              // (now-removed) header icon used to read, so the number on
              // screen stays consistent with what's in the cart provider.
              NavigationDestination(
                icon: Selector<CartProvider, int>(
                  selector: (_, c) => c.lineCount,
                  builder: (_, count, _) => _BadgedIcon(
                    icon: Icons.shopping_cart_outlined,
                    count: count,
                  ),
                ),
                selectedIcon: Selector<CartProvider, int>(
                  selector: (_, c) => c.lineCount,
                  builder: (_, count, _) => _BadgedIcon(
                    icon: Icons.shopping_cart_rounded,
                    count: count,
                  ),
                ),
                label: AppStrings.navCart,
              ),
              const NavigationDestination(
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

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({required this.icon, required this.count});
  final IconData icon;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 24),
          if (count > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
