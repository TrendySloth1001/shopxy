import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/shop_invoices_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_shimmer.dart';

/// "Your shops" — horizontally-scrolling carousel of the user's
/// linked shops. Tapping a card goes to that shop's invoices page
/// (same destination as MyShops).
///
/// Renders a small skeleton row while loading. Returns
/// [SizedBox.shrink] if the user has no shops *and* loading is
/// done — the parent renders a richer empty state in that case.
class HomeShopsSection extends StatelessWidget {
  const HomeShopsSection({super.key, required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ShopsProvider>();
    final theme = Theme.of(context);

    if (p.isLoading && p.shops.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(title: 'Your shops', onSeeAll: null, theme: theme),
          const SizedBox(height: AppSizes.sm),
          SizedBox(
            height: 96,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
              children: const [
                _SkeletonShopCard(),
                SizedBox(width: AppSizes.md),
                _SkeletonShopCard(),
                SizedBox(width: AppSizes.md),
                _SkeletonShopCard(),
              ],
            ),
          ),
        ],
      );
    }

    if (p.shops.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          title: 'Your shops',
          onSeeAll: p.shops.length > 4 ? onSeeAll : null,
          theme: theme,
        ),
        const SizedBox(height: AppSizes.sm),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
            itemBuilder: (_, i) => _ShopCard(shop: p.shops[i]),
            separatorBuilder: (_, _) => const SizedBox(width: AppSizes.md),
            itemCount: p.shops.length,
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onSeeAll, required this.theme});
  final String title;
  final VoidCallback? onSeeAll;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.black,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.black,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: 0,
                ),
              ),
              child: const Text('See all'),
            ),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  const _ShopCard({required this.shop});
  final LinkedShop shop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isParty = shop.role == ShopRole.party;
    final accent = isParty ? AppColors.accentRose : AppColors.accentIndigo;
    final accentSoft =
        isParty ? AppColors.accentRoseSoft : AppColors.accentIndigoSoft;
    final shape = AppShapes.squircle(
      AppSizes.radiusMd,
      side: const BorderSide(color: AppColors.hairline),
    );

    return SizedBox(
      width: 200,
      child: Material(
        color: AppColors.white,
        shape: shape,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ShopInvoicesPage(shop: shop)),
          ),
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: ShapeDecoration(
                    color: accentSoft,
                    shape: AppShapes.squircle(AppSizes.radiusSm),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    shop.name.isEmpty ? '?' : shop.name[0].toUpperCase(),
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.name,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        shop.invoiceCount == 0
                            ? 'No invoices'
                            : '${shop.invoiceCount} ${shop.invoiceCount == 1 ? "invoice" : "invoices"}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonShopCard extends StatelessWidget {
  const _SkeletonShopCard();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: ShapeDecoration(
          color: AppColors.white,
          shape: AppShapes.squircle(
            AppSizes.radiusMd,
            side: const BorderSide(color: AppColors.hairline),
          ),
        ),
        child: Row(
          children: [
            const AppShimmerBox(width: 44, height: 44, radius: 8),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  AppShimmerLine(widthFactor: 0.8, height: 12),
                  SizedBox(height: 6),
                  AppShimmerLine(widthFactor: 0.5, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
