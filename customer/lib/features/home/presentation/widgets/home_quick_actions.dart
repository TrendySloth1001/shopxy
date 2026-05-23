import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Four-tile row of high-traffic shortcuts. Sits right under the
/// search bar so the first scroll surface answers the question
/// "what can I do here?" without scrolling.
///
/// Each tile is a soft-tinted icon + a one-word label. Order matches
/// Baymard's recommended e-commerce home priority: browse, recent
/// activity (orders), wishlist, account.
class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({
    super.key,
    required this.onBrowse,
    required this.onOrders,
    required this.onWishlist,
    required this.onShops,
  });

  final VoidCallback onBrowse;
  final VoidCallback onOrders;
  final VoidCallback onWishlist;
  final VoidCallback onShops;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Row(
        children: [
          Expanded(
            child: _Tile(
              icon: Icons.grid_view_rounded,
              label: 'Browse',
              tint: AppColors.brand,
              tintSoft: AppColors.brandSoft,
              onTap: onBrowse,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _Tile(
              icon: Icons.receipt_long_rounded,
              label: 'Orders',
              tint: AppColors.accentIndigo,
              tintSoft: AppColors.accentIndigoSoft,
              onTap: onOrders,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _Tile(
              icon: Icons.favorite_rounded,
              label: 'Saved',
              tint: AppColors.accentRose,
              tintSoft: AppColors.accentRoseSoft,
              onTap: onWishlist,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _Tile(
              icon: Icons.storefront_rounded,
              label: 'Shops',
              tint: AppColors.accentTeal,
              tintSoft: AppColors.accentTealSoft,
              onTap: onShops,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.label,
    required this.tint,
    required this.tintSoft,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color tint;
  final Color tintSoft;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shape = AppShapes.squircle(
      AppSizes.radiusMd,
      side: const BorderSide(color: AppColors.hairline),
    );
    return Material(
      color: AppColors.white,
      shape: shape,
      child: InkWell(
        onTap: onTap,
        customBorder: shape,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.md,
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: tintSoft,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 18, color: tint),
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: AppColors.black,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
