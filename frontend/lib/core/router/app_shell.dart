import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';
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
import 'package:shopxy/shared/constants/app_curves.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/features/developer/presentation/widgets/environment_badge.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class _Destination {
  const _Destination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.pageBuilder,
    this.id,
    this.isHome = false,
  });

  final String Function(AppLocalizations l10n) label;
  final AppIconData icon;
  final AppIconData selectedIcon;

  final Widget Function() pageBuilder;

  final String? id;

  final bool isHome;
}

const _kOrdersDestinationId = 'orders';
const _kInvoicesDestinationId = 'invoices';

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
    id: _kInvoicesDestinationId,
  ),
];

final _homeIndex = _destinations.indexWhere((d) => d.isHome);

class AppShellState extends State<AppShell> {
  int _currentIndex = _homeIndex < 0 ? 0 : _homeIndex;

  late final Set<int> _visited = {_currentIndex};

  void _select(int index) {
    if (index != _currentIndex) AppHaptics.selection();
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  void selectDestination(String id) {
    final index = _destinations.indexWhere((d) => d.id == id);
    if (index >= 0) _select(index);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<OrdersProvider>().refreshPendingCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shopRole = context.select<AuthProvider, String?>(
      (a) => a.user?.shopRole,
    );
    if (shopRole == 'CASHIER') {
      return const PosPage(kiosk: true);
    }

    context.watch<ThemePrefsProvider>();
    final l10n = AppLocalizations.of(context);
    final pages = <Widget>[
      for (var i = 0; i < _destinations.length; i++)
        if (_visited.contains(i))
          _destinations[i].pageBuilder()
        else
          const SizedBox.shrink(),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: pages),
          Positioned(
            left: AppSizes.lg,
            bottom:
                FloatingBottomNav.contentBottomInset(context) + AppSizes.xs,
            child: const SafeArea(top: false, child: EnvironmentBadge()),
          ),
        ],
      ),
      bottomNavigationBar: _FloatingBottomNav(
        destinations: _destinations,
        currentIndex: _currentIndex,
        onSelect: _select,
        l10n: l10n,
      ),
    );
  }
}

abstract final class FloatingBottomNav {
  FloatingBottomNav._();

  static const double vMargin = AppSizes.sm;

  static double contentBottomInset(BuildContext context) {
    final safeBottom = MediaQueryData.fromView(View.of(context)).padding.bottom;
    return safeBottom + _NavIsland.height + vMargin * 2;
  }
}

class _FloatingBottomNav extends StatelessWidget {
  const _FloatingBottomNav({
    required this.destinations,
    required this.currentIndex,
    required this.onSelect,
    required this.l10n,
  });

  final List<_Destination> destinations;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final homeIndex = destinations.indexWhere((d) => d.isHome);
    final leftEntries = <int>[
      for (var i = 0; i < destinations.length; i++)
        if (!destinations[i].isHome) i,
    ];

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: FloatingBottomNav.vMargin,
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavIsland(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final i in leftEntries)
                      _NavItem(
                        destination: destinations[i],
                        selected: currentIndex == i,
                        onTap: () => onSelect(i),
                        l10n: l10n,
                      ),
                  ],
                ),
              ),
            ),
            if (homeIndex >= 0) ...[
              const SizedBox(width: AppSizes.sm),
              _NavIsland(
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                subdued: currentIndex != homeIndex,
                child: _NavItem(
                  destination: destinations[homeIndex],
                  selected: currentIndex == homeIndex,
                  onTap: () => onSelect(homeIndex),
                  l10n: l10n,
                  alwaysLabel: true,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavIsland extends StatelessWidget {
  const _NavIsland({
    required this.child,
    required this.padding,
    this.subdued = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool subdued;

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: AppDurations.short,
            curve: AppCurves.standard,
            height: height,
            padding: padding,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: AppColors.surface.withValues(alpha: subdued ? 0 : 0.55),
              shape: AppShapes.squircle(
                AppSizes.radiusFull,
                side: BorderSide(color: AppColors.hairline),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
    required this.l10n,
    this.alwaysLabel = false,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;
  final AppLocalizations l10n;
  final bool alwaysLabel;

  static const double _indicatorHeight = AppSizes.tapTargetMin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showLabel = selected || alwaysLabel;
    final icon = selected ? destination.selectedIcon : destination.icon;
    final fg = selected ? AppColors.onInverse : AppColors.black;
    final label = destination.label(l10n);
    final glyph = destination.id == _kOrdersDestinationId
        ? _OrdersBadgeIcon(icon: icon, color: fg)
        : AppIcon(icon, color: fg, size: AppSizes.iconLg);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkResponse(
        onTap: onTap,
        radius: AppSizes.xxl,
        child: AnimatedContainer(
          duration: AppDurations.short,
          curve: AppCurves.standard,
          height: _indicatorHeight,
          padding: EdgeInsets.symmetric(
            horizontal: showLabel ? AppSizes.md : AppSizes.sm,
          ),
          decoration: ShapeDecoration(
            color: selected ? AppColors.inverseSurface : Colors.transparent,
            shape: AppShapes.squircle(AppSizes.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              glyph,
              if (showLabel) ...[
                const SizedBox(width: AppSizes.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 88),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: theme.textTheme.labelLarge?.semibold.copyWith(
                      color: fg,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OrdersBadgeIcon extends StatelessWidget {
  const _OrdersBadgeIcon({required this.icon, this.color});
  final AppIconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final badge = context.select<OrdersProvider, int>((o) => o.pendingCount);
    return _DestinationIcon(icon: icon, badge: badge, color: color);
  }
}

class _DestinationIcon extends StatelessWidget {
  const _DestinationIcon({required this.icon, required this.badge, this.color});
  final AppIconData icon;
  final int badge;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final glyph = AppIcon(icon, color: color, size: AppSizes.iconLg);
    if (badge <= 0) return glyph;
    final label = badge > 99 ? '99+' : '$badge';
    return Badge(
      label: Text(label),
      backgroundColor: AppColors.warning,
      textColor: AppColors.white,
      child: glyph,
    );
  }
}
