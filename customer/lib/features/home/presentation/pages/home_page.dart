import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_greeting_header.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_pending_invite_callout.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_quick_actions.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_recent_orders.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_search_entry.dart';
import 'package:shopxy_customer/features/home/presentation/widgets/home_shops_section.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/my_shops_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// First-tab landing surface — what a customer sees when they open the
/// app. Composed of small section widgets so the rules in DESIGN.md
/// can be enforced inside each block.
///
/// Sections, in scroll order:
///   1. Greeting + avatar + bell
///   2. Search entry (taps → search route, wired in next milestone)
///   3. Pending-invitation callout (only when there are invites)
///   4. Quick-actions row (Browse / Orders / Saved / Shops)
///   5. Your shops carousel
///   6. Recent orders strip
///   7. Empty state when there's nothing yet
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refresh();
    });
  }

  Future<void> _refresh() async {
    final shops = context.read<ShopsProvider>();
    final orders = context.read<OrdersProvider>();
    final notifs = context.read<NotificationsProvider>();
    await Future.wait([
      shops.loadShops(),
      orders.load(),
      notifs.loadIncoming(status: 'PENDING'),
    ]);
  }

  void _switchTab(int index) {
    CustomerShellScope.of(context)?.select(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.brand,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSizes.huge),
            children: [
              const HomeGreetingHeader(),
              HomeSearchEntry(
                onTap: () => _switchTab(CustomerShellTab.browse.index),
              ),
              HomePendingInviteCallout(
                onTap: () =>
                    _switchTab(CustomerShellTab.notifications.index),
              ),
              HomeQuickActions(
                onBrowse: () => _switchTab(CustomerShellTab.browse.index),
                onOrders: () => _switchTab(CustomerShellTab.orders.index),
                onWishlist: () => _openWishlist(context),
                onShops: () => _openAllShops(context),
              ),
              const SizedBox(height: AppSizes.lg),
              HomeShopsSection(onSeeAll: () => _openAllShops(context)),
              HomeRecentOrders(
                onSeeAll: () => _switchTab(CustomerShellTab.orders.index),
              ),
              const _HomeEmptyState(),
            ],
          ),
        ),
      ),
    );
  }

  void _openAllShops(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyShopsPage()),
    );
  }

  /// Wishlist isn't wired yet (next milestone). Until then the tile
  /// drops a snackbar so the user knows it's intentional, not broken.
  void _openWishlist(BuildContext context) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Saved items are coming soon.'),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          0,
          AppSizes.lg,
          AppSizes.lg,
        ),
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
    );
  }
}

/// Shown only when the user has zero shops AND zero orders. A blank
/// home with just a search bar feels broken; this gives them somewhere
/// to go.
class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState();

  @override
  Widget build(BuildContext context) {
    final shops = context.watch<ShopsProvider>();
    final orders = context.watch<OrdersProvider>();
    if (shops.isLoading || orders.isLoading) return const SizedBox.shrink();
    if (shops.shops.isNotEmpty || orders.orders.isNotEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSizes.xl),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.xl),
        decoration: ShapeDecoration(
          color: AppColors.heroPanel,
          shape: AppShapes.squircle(AppSizes.radiusLg),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 40,
              color: AppColors.muted,
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'No shops linked yet',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              'Shops you accept an invite from will show up here. Ask a merchant to send you an invite.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
