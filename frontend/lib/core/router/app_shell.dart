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
const _kInvoicesDestinationId = 'invoices';

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
    id: _kInvoicesDestinationId,
  ),
];

/// The Home (dashboard) tab — used as the initial tab so the app opens on Home,
/// not the first bar slot.
final _homeIndex = _destinations.indexWhere((d) => d.isHome);

class AppShellState extends State<AppShell> {
  int _currentIndex = _homeIndex < 0 ? 0 : _homeIndex;

  /// Tabs the user has actually opened this session. Only these get a real
  /// page built in the IndexedStack; the rest render an empty placeholder, so
  /// a tab's `initState` (and its cold-start network load) fires the first time
  /// it's shown — not for all five at boot. Seeded with the landing tab.
  late final Set<int> _visited = {_currentIndex};

  void _select(int index) {
    if (index != _currentIndex) AppHaptics.selection();
    setState(() {
      _currentIndex = index;
      _visited.add(index);
    });
  }

  /// Selects a bottom-nav tab by its destination id — for flows that finish
  /// deep in the navigation stack (e.g. Invoice settings' Save, which then
  /// pops back to the shell) and want to land the user on a specific tab
  /// rather than whichever one was active before they drilled in. Found via
  /// `context.findAncestorStateOfType<AppShellState>()` since AppShell is
  /// always the mounted root beneath any pushed screen — no GlobalKey needed.
  void selectDestination(String id) {
    final index = _destinations.indexWhere((d) => d.id == id);
    if (index >= 0) _select(index);
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
    // not the full shell — a locked-down register. Select only the field we
    // branch on so an unrelated AuthProvider notify (e.g. the live perms-version
    // refetch of /auth/me) doesn't rebuild the shell — and with it all tabs.
    final shopRole = context.select<AuthProvider, String?>(
      (a) => a.user?.shopRole,
    );
    if (shopRole == 'CASHIER') {
      return const PosPage(kiosk: true);
    }

    // Depend on the theme so a palette change rebuilds the shell — and with
    // it the freshly-built pages below — instead of leaving them on stale
    // AppColors until an app restart.
    context.watch<ThemePrefsProvider>();
    final l10n = AppLocalizations.of(context);
    // Fresh page instances each build (see [_Destination.pageBuilder]), but
    // only for tabs the user has opened — unvisited tabs stay a zero-cost
    // placeholder until first selected (see [_visited]).
    final pages = <Widget>[
      for (var i = 0; i < _destinations.length; i++)
        if (_visited.contains(i))
          _destinations[i].pageBuilder()
        else
          const SizedBox.shrink(),
    ];

    return Scaffold(
      // Let the page scroll BEHIND the floating nav so its frosted islands
      // actually blur live content (mirrors the top FloatingAppBar). Scaffold
      // folds the nav's height into the body's bottom MediaQuery padding, so
      // scrollables that honour it still clear the bar.
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: pages),
      bottomNavigationBar: _FloatingBottomNav(
        destinations: _destinations,
        currentIndex: _currentIndex,
        onSelect: _select,
        l10n: l10n,
      ),
    );
  }
}

/// The app's **floating bottom navigation** — two frosted islands that echo the
/// [FloatingAppBar] up top rather than a flat, edge-to-edge Material bar:
///
/// ```
///  ┌─────────────────────────────┐   ┌──────────┐
///  │ ▦ Menu    ▤    ▧⁰    ▨       │   │ ⌂  Home  │
///  └─────────────────────────────┘   └──────────┘
///    (selected)                        (always labelled)
/// ```
///
/// - **Leading pill** — one shared island holding every non-home destination.
///   The active one expands in place to reveal its label; the rest stay icons.
/// - **Trailing Home chip** — a distinct island on the right that is *always*
///   expanded (icon + "Home"); it never collapses to an icon, it only switches
///   between selected and unselected styling.
/// Public entry point for the floating bottom nav's layout metrics. The widget
/// itself is private (only [AppShell] builds it), but tab pages need its
/// [contentBottomInset] to pad their scroll content clear of the floating bar.
abstract final class FloatingBottomNav {
  FloatingBottomNav._();

  /// Vertical breathing room above and below the island band.
  static const double vMargin = AppSizes.sm;

  /// The bottom inset a tab page's scroll content needs so its last item clears
  /// (and can scroll *behind*) the floating bar: the device's bottom safe area
  /// + the island band + its margins. Read from the raw view so it's correct at
  /// any nested body context — the symmetric partner of
  /// [FloatingAppBar.contentTopInset].
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
              // Home stays a distinct island, subdued (outline only) while it
              // isn't the active tab, and its item is always labelled so the
              // chip never collapses to a bare icon.
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

/// Frosted rounded-pill container shared by both nav islands — the same glass
/// treatment as the floating app bar's islands, kept local to the shell.
///
/// [subdued] drops the frosted fill to a hairline outline. The Home chip uses
/// it while unselected so it reads as a quiet, tappable outline instead of a
/// filled surface — leaving the dark selected pill as the emphasised surface.
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
    // RepaintBoundary isolates the island's own repaints (the badge count, the
    // select colour tween) from the rest of the shell, and vice-versa. The blur
    // sigma is kept moderate: a BackdropFilter re-blurs the live content behind
    // it every scrolled frame, and cost scales with the kernel radius, so 12 is
    // visually frosted but markedly cheaper per frame than 18.
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

/// A single tappable destination inside an island. Unselected it's an icon;
/// selected it grows into a filled dark pill that also shows the destination's
/// **name**. [alwaysLabel] keeps the label showing even when unselected (used
/// by the Home chip, which must never collapse to a bare icon). The indicator
/// is the same height and squircle in every island, so the leading pill and the
/// Home chip stay visually consistent. The orders slot keeps its live
/// pending-count badge.
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

  /// Height of the indicator — shared by every item so pills line up across
  /// both islands. Sits inset within the taller island band.
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
                // Capped + ellipsised so a long localised label (the app ships
                // Hindi) fades rather than overflowing the pill on a narrow
                // screen.
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

/// Orders bottom-nav icon that subscribes to just the pending count, so an
/// order arriving repaints this icon alone rather than the whole shell.
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

/// Wraps a destination icon with a Material 3 numeric badge. We hand-roll
/// the badge wrapper (instead of using NavigationDestination's `badge`
/// slot, which only renders for the unselected icon on some platforms)
/// so the indicator stays visible in both states. Hidden when count == 0.
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
