import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Small "Sold by {shop}" chip used on cart, checkout, and order
/// detail rows so multi-shop bags read unambiguously. Renders nothing
/// when the shop name is null/empty — callers don't need to guard.
class ShopChip extends StatelessWidget {
  const ShopChip({
    super.key,
    required this.shopName,
    this.dense = false,
  });

  final String? shopName;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final name = shopName?.trim();
    if (name == null || name.isEmpty) return const SizedBox.shrink();

    final fontSize = dense ? 10.0 : 11.0;
    final iconSize = dense ? 11.0 : 13.0;
    final padV = dense ? 2.0 : 3.0;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7, vertical: padV),
      decoration: ShapeDecoration(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.storefront_outlined,
            size: iconSize,
            color: AppColors.brandStrong,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.brandStrong,
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
