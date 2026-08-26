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
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/constants/app_curves.dart';
import 'package:shopxy_customer/shared/constants/app_durations.dart';

enum CustomerShellTab { home, cart, orders, profile }

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

  final _navVisible = ValueNotifier<bool>(true);

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
      _navVisible.value = true;
      return;
    }
    setState(() => _currentIndex = i);
    _navVisible.value = true;
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollEndNotification &&
        n.metrics.pixels <= n.metrics.minScrollExtent) {
      _navVisible.value = true;
      return false;
    }
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

  bool _onScrollMetrics(ScrollMetricsNotification n) {
    if (n.metrics.maxScrollExtent <= 0 && !_navVisible.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _navVisible.value = true;
      });
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
    final basePadding = MediaQuery.paddingOf(context);
    final extendedPadding = basePadding.copyWith(
      bottom: basePadding.bottom + _kNavFootprint,
    );

    return Selector<ShopsProvider, bool>(
      selector: (_, p) => p.hasLinkedParty,
      builder: (context, linked, _) {
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
            body: NotificationListener<ScrollMetricsNotification>(
              onNotification: _onScrollMetrics,
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScroll,
                child: Stack(
                  children: [
                    MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(padding: extendedPadding),
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
          ),
        );
      },
    );
  }
}

const double _kNavFootprint = 72;

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
            curve: AppCurves.decelerateEmphasized,
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
    icon: AppIcons.homeOutlined,
    selectedIcon: AppIcons.homeRounded,
    label: AppStrings.navHome,
  );
  static const _merchant = _NavItem(
    icon: AppIcons.storefrontOutlined,
    selectedIcon: AppIcons.storefrontRounded,
    label: 'Merchant',
  );
  static const _cart = _NavItem(
    icon: AppIcons.shoppingCartOutlined,
    selectedIcon: AppIcons.shoppingCartRounded,
    label: AppStrings.navCart,
    isCart: true,
  );
  static const _orders = _NavItem(
    icon: AppIcons.receiptLongOutlined,
    selectedIcon: AppIcons.receiptLongRounded,
    label: 'Orders',
  );
  static const _profile = _NavItem(
    icon: AppIcons.personOutlineRounded,
    selectedIcon: AppIcons.personRounded,
    label: AppStrings.navProfile,
  );

  static const _linkedItems = <_NavItem>[_home, _merchant, _cart, _orders];
  static const _unlinkedItems = <_NavItem>[_home, _cart, _orders, _profile];

  @override
  Widget build(BuildContext context) {
    final items = linked ? _linkedItems : _unlinkedItems;
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
        child: LayoutBuilder(
          builder: (context, c) {
            const selectedShare = 2.0;
            const unselectedShare = 1.0;
            final totalShare =
                selectedShare + unselectedShare * (items.length - 1);
            final selectedWidth = c.maxWidth * selectedShare / totalShare;
            final unselectedWidth = c.maxWidth * unselectedShare / totalShare;
            return Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  AnimatedContainer(
                    duration: AppDurations.medium,
                    curve: AppCurves.decelerateEmphasized,
                    width: i == currentIndex ? selectedWidth : unselectedWidth,
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
  final AppIconData icon;
  final AppIconData selectedIcon;
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
        : AppIcon(
            selected ? item.selectedIcon : item.icon,
            color: selected ? AppColors.brandStrong : AppColors.muted,
            size: 22,
          );

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
  final AppIconData icon;
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
          AppIcon(icon, size: 22, color: color),
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
