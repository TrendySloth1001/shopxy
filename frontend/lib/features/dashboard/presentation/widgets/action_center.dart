import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/orders/presentation/pages/orders_inbox_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotations_page.dart';
import 'package:shopxy/features/returns/presentation/pages/merchant_returns_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

enum _Tone { brand, amber, error }

class _Item {
  const _Item(this.count, this.label, this.icon, this.tone, this.page);
  final int count;
  final String label;
  final AppIconData icon;
  final _Tone tone;
  final Widget Function() page;
}

class ActionCenter extends StatelessWidget {
  const ActionCenter({super.key, required this.queue});
  final DashboardActionQueue queue;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final items = <_Item>[
      _Item(
        queue.orders,
        l10n.dashboardOrdersToConfirm,
        AppIcons.shoppingBagOutlined,
        _Tone.brand,
        () => const OrdersInboxPage(),
      ),
      _Item(
        queue.returns,
        l10n.dashboardReturnsToReview,
        AppIcons.replayRounded,
        _Tone.amber,
        () => const MerchantReturnsPage(),
      ),
      _Item(
        queue.quotations,
        l10n.dashboardQuotesToPrice,
        AppIcons.descriptionOutlined,
        _Tone.brand,
        () => const QuotationsPage(),
      ),
      _Item(
        queue.drafts,
        l10n.dashboardDraftsToConfirm,
        AppIcons.assignmentOutlined,
        _Tone.brand,
        () => const InvoicesPage(),
      ),
      _Item(
        queue.outOfStock,
        l10n.dashboardOutOfStock,
        AppIcons.inventory2Outlined,
        _Tone.error,
        () => const ProductsPage(),
      ),
      _Item(
        queue.lowStock,
        l10n.dashboardLowStock,
        AppIcons.inventoryOutlined,
        _Tone.amber,
        () => const ProductsPage(),
      ),
    ].where((it) => it.count > 0).toList();

    return DashSection(
      title: l10n.dashboardNeedsAttention,
      child: items.isEmpty
          ? DashCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.md,
                vertical: AppSizes.lg,
              ),
              child: Row(
                children: [
                  AppIcon(
                    AppIcons.checkCircleRounded,
                    size: AppSizes.iconMd,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(
                      l10n.dashboardAllCaughtUp,
                      style: DashText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            )
          : LayoutBuilder(
              builder: (context, c) {
                final cols = responsiveCols(c.maxWidth, base: 2, lg: 3, xl: 6);
                return ResponsiveGrid(
                  columns: cols,
                  children: [for (final it in items) _Tile(item: it)],
                );
              },
            ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (item.tone) {
      _Tone.brand => (AppColors.brandSoft, AppColors.brandStrong),
      _Tone.amber => (AppColors.accentAmberSoft, AppColors.accentAmber),
      _Tone.error => (AppColors.errorSoft, AppColors.error),
    };
    return DashCard(
      onTap: () => dashPush(context, item.page()),
      child: Row(
        children: [
          Container(
            width: AppSizes.avatarXs,
            height: AppSizes.avatarXs,
            decoration: ShapeDecoration(
              color: bg,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: AppIcon(item.icon, size: 18, color: fg),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${item.count}',
                  style: DashText.headlineSm.copyWith(
                    fontFeatures: tabularFigures,
                  ),
                ),
                Text(
                  item.label,
                  style: DashText.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
