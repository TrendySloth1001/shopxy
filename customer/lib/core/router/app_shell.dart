import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/cart/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/home/presentation/pages/home_page.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/my_orders_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/my_shops_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
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

  /// Tracked so we can detect when linkage changes (e.g. user accepts
  /// an invite mid-session) and snap back to Home — without this, the
  /// same _currentIndex would silently point at a different page.
  bool? _lastLinked;

  static const List<Widget> _linkedPages = [
    HomePage(),
    MyShopsPage(),
    CartPage(embedded: true),
    MyOrdersPage(),
  ];

  static const List<Widget> _unlinkedPages = [
    HomePage(),
    CartPage(embedded: true),
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

    // Selector — only rebuilds when linkage state actually flips, not
    // on every shop-list refresh. Uses the provider's hint-or-real
    // getter so the very first paint reflects last-known state.
    return Selector<ShopsProvider, bool>(
      selector: (_, p) => p.hasLinkedParty,
      builder: (context, linked, _) {
        // Linkage flipped during the session — snap back to Home so
        // the user isn't dropped onto a tab whose meaning just
        // shifted under them.
        if (_lastLinked != null &&
            _lastLinked != linked &&
            _currentIndex != 0) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _currentIndex = 0);
          });
        }
        _lastLinked = linked;

        final pages = linked ? _linkedPages : _unlinkedPages;

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
                    data: MediaQuery.of(context)
                        .copyWith(padding: extendedPadding),
                    child: IndexedStack(
                      index: _currentIndex,
                      children: pages,
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
                      linked: linked,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
    required this.linked,
  });
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final ValueNotifier<bool> visible;
  final bool linked;

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
                  linked: linked,
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
  const _NavPill({
    required this.currentIndex,
    required this.onSelect,
    required this.linked,
  });
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final bool linked;

  static const _home = _NavItem(
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
    label: AppStrings.navHome,
  );
  static const _merchant = _NavItem(
    icon: Icons.storefront_outlined,
    selectedIcon: Icons.storefront_rounded,
    label: 'Merchant',
  );
  static const _cart = _NavItem(
    icon: Icons.shopping_cart_outlined,
    selectedIcon: Icons.shopping_cart_rounded,
    label: AppStrings.navCart,
    isCart: true,
  );
  static const _orders = _NavItem(
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long_rounded,
    label: 'Orders',
  );
  static const _profile = _NavItem(
    icon: Icons.person_outline_rounded,
    selectedIcon: Icons.person_rounded,
    label: AppStrings.navProfile,
  );

  /// When the user has at least one linked merchant the Merchant tab
  /// takes the index-1 slot and the Profile entry moves to the home
  /// top bar (rendered separately). Unlinked customers see the
  /// original layout where Profile lives in the bottom nav.
  static const _linkedItems = <_NavItem>[_home, _merchant, _cart, _orders];
  static const _unlinkedItems = <_NavItem>[_home, _cart, _orders, _profile];

  @override
  Widget build(BuildContext context) {
    final items = linked ? _linkedItems : _unlinkedItems;
    // width:double.infinity pins the pill to the full available width
    // so the cells redistribute internally (selected widens, others
    // compress) instead of the whole pill shrinking around them.
    return Container(
      width: double.infinity,
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
        // Cells get animated, computed widths instead of intrinsic
        // sizing — the selected cell takes a bigger share so it can
        // host its label, and unselected cells share the remaining
        // space equally. Total share always sums to the full inner
        // width, so cells stay flush against each other (no ugly
        // gaps) and the only thing that visibly moves on tap is the
        // brand-soft pill sliding to a new position + width.
        child: LayoutBuilder(
          builder: (context, c) {
            const selectedShare = 2.0;
            const unselectedShare = 1.0;
            final totalShare =
                selectedShare + unselectedShare * (items.length - 1);
            final selectedWidth = c.maxWidth * selectedShare / totalShare;
            final unselectedWidth =
                c.maxWidth * unselectedShare / totalShare;
            return Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    width:
                        i == currentIndex ? selectedWidth : unselectedWidth,
                    height: 44,
                    decoration: ShapeDecoration(
                      color: i == currentIndex
                          ? AppColors.brandSoft
                          : Colors.transparent,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onSelect(i),
                        child: _NavCell(
                          item: items[i],
                          selected: i == currentIndex,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
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
  const _NavCell({required this.item, required this.selected});
  final _NavItem item;
  final bool selected;

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

    // Content only — the parent AnimatedContainer owns width,
    // decoration, and tap. Centered Row clips its label to whatever
    // horizontal room the cell happens to have at any animation
    // frame, so the icon stays anchored and the label doesn't bleed
    // past the brand-soft pill while it grows / shrinks.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          if (selected) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
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
