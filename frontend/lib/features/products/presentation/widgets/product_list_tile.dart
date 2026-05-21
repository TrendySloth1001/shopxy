import 'package:flutter/material.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

class ProductListTile extends StatelessWidget {
  const ProductListTile({super.key, required this.product, this.onTap});

  final Product product;
  final VoidCallback? onTap;

  AppStatusTone get _stockTone {
    if (product.isOutOfStock) return AppStatusTone.error;
    if (product.isLowStock) return AppStatusTone.warning;
    return AppStatusTone.success;
  }

  String get _stockLabel {
    if (product.isOutOfStock) return AppStrings.outOfStock;
    if (product.isLowStock) return AppStrings.lowStock;
    return '${_formatQty(product.stockQuantity)} ${product.unit}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: AppSizes.md,
          ),
          child: Row(
            children: [
              _ProductThumbnail(product: product),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'SKU: ${product.sku}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${AppStrings.currencySymbol}${product.sellingPrice.toStringAsFixed(0)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppStatusBadge(label: _stockLabel, tone: _stockTone, dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final shape = AppShapes.squircle(
      AppSizes.radiusSm,
      side: BorderSide(color: AppColors.hairline, width: 1),
    );
    return Container(
      width: AppSizes.productThumbSize,
      height: AppSizes.productThumbSize,
      decoration: ShapeDecoration(color: AppColors.white, shape: shape),
      child: product.primaryImageUrl != null
          ? ClipPath(
              clipper: ShapeBorderClipper(shape: shape),
              child: Image.network(
                product.primaryImageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.black,
                  size: AppSizes.iconMd,
                ),
              ),
            )
          : const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.black,
              size: AppSizes.iconMd,
            ),
    );
  }
}
