import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/cart_v2/presentation/pages/cart_v2_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/pages/home_v2_page.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/my_orders_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Tabs available in the customer-app shell. Orders was added in the
/// May 2026 nav redesign so it's reachable in one tap instead of
/// hidden behind Profile.
enum CustomerShellTab { home, cart, orders, profile }

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

  /// Whether the floating nav is currently slid into view. Flips when
  /// any descendant ScrollView reports `UserScrollNotification` with a
  /// reverse (scroll-down) or forward (scroll-up) direction. We use a
  /// ValueNotifier rather than setState so the nav can rebuild in
  /// isolation — the IndexedStack underneath doesn't tear down.
  final _navVisible = ValueNotifier<bool>(true);

  final _pages = const [
    HomeV2Page(),
    CartV2Page(embedded: true),
    MyOrdersPage(),
    CustomerProfilePage(),
  ];

  void _select(int i) {
    if (i == _currentIndex) {
      // Re-tapping the active tab snaps the nav back into view so the
      // user can always recover it after scrolling down.
      _navVisible.value = true;
      return;
    }
    setState(() => _currentIndex = i);
    _navVisible.value = true;
  }

  bool _onScroll(ScrollNotification n) {
    if (n is UserScrollNotification) {
      switch (n.direction) {
        case ScrollDirection.reverse:
          if (_navVisible.value) _navVisible.value = false;
        case ScrollDirection.forward:
          if (!_navVisible.value) _navVisible.value = true;
        case ScrollDirection.idle:
          break;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _navVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Extend the bottom safe area by the nav's footprint so descendant
    // ScrollViews / SafeAreas leave room for the floating pill and
    // content isn't hidden behind it. Cheap and universal — no need
    // to touch every page.
    final basePadding = MediaQuery.paddingOf(context);
    final extendedPadding = basePadding.copyWith(
      bottom: basePadding.bottom + _kNavFootprint,
    );

    return CustomerShellScope(
      index: _currentIndex,
      select: _select,
      child: Scaffold(
        backgroundColor: AppColors.canvas,
        body: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: Stack(
            children: [
              MediaQuery(
                data: MediaQuery.of(context).copyWith(padding: extendedPadding),
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _FloatingNav(
                  currentIndex: _currentIndex,
                  onSelect: _select,
                  visible: _navVisible,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Total vertical room (pill height + margin) the floating nav
/// consumes when fully visible. Pages use this via the extended
/// MediaQuery padding to avoid laying content underneath.
const double _kNavFootprint = 72;

// ─── Floating pill ──────────────────────────────────────────────────

class _FloatingNav extends StatelessWidget {
  const _FloatingNav({
    required this.currentIndex,
    required this.onSelect,
    required this.visible,
  });
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final ValueNotifier<bool> visible;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ValueListenableBuilder<bool>(
      valueListenable: visible,
      builder: (context, isVisible, _) {
        return IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            offset: isVisible ? Offset.zero : const Offset(0, 1.4),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 220),
              opacity: isVisible ? 1 : 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSizes.lg,
                  0,
                  AppSizes.lg,
                  AppSizes.sm + bottomInset * 0.5,
                ),
                child: _NavPill(
                  currentIndex: currentIndex,
                  onSelect: onSelect,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NavPill extends StatelessWidget {
  const _NavPill({required this.currentIndex, required this.onSelect});
  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = <_NavItem>[
    _NavItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: AppStrings.navHome,
    ),
    _NavItem(
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart_rounded,
      label: AppStrings.navCart,
      isCart: true,
    ),
    _NavItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: 'Orders',
    ),
    _NavItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: AppStrings.navProfile,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusFull),
        shadows: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _items.length; i++)
              _NavCell(
                item: _items[i],
                selected: i == currentIndex,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.isCart = false,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isCart;
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconWidget = item.isCart
        ? Selector<CartProvider, int>(
            selector: (_, c) => c.lineCount,
            builder: (_, count, _) => _BadgedIcon(
              icon: selected ? item.selectedIcon : item.icon,
              color: selected ? AppColors.brandStrong : AppColors.muted,
              count: count,
            ),
          )
        : Icon(
            selected ? item.selectedIcon : item.icon,
            color: selected ? AppColors.brandStrong : AppColors.muted,
            size: 22,
          );

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: AppShapes.squircle(AppSizes.radiusFull),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? 14 : 10,
              vertical: 10,
            ),
            decoration: ShapeDecoration(
              color: selected ? AppColors.brandSoft : Colors.transparent,
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                iconWidget,
                if (selected) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.brandStrong,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BadgedIcon extends StatelessWidget {
  const _BadgedIcon({
    required this.icon,
    required this.color,
    required this.count,
  });
  final IconData icon;
  final Color color;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          if (count > 0)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: BoxDecoration(
                  color: AppColors.brand,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.white, width: 1.5),
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
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
