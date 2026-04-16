import 'package:flutter/material.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

class ProductListTile extends StatelessWidget {
  const ProductListTile({
    super.key,
    required this.product,
    this.onTap,
  });

  final Product product;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final stockColor = product.isOutOfStock
        ? theme.colorScheme.error
        : product.isLowStock
            ? const Color(0xFFF59E0B)
            : const Color(0xFF1F8A5B);

    final stockLabel = product.isOutOfStock
        ? AppStrings.outOfStock
        : product.isLowStock
            ? AppStrings.lowStock
            : '${_formatQty(product.stockQuantity)} ${product.unit}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSizes.sm),
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(AppSizes.radiusMd),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            // Product thumbnail
            Container(
              width: AppSizes.productThumbSize,
              height: AppSizes.productThumbSize,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AppSizes.radiusSm),
              ),
              child: product.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                      child: Image.network(
                        product.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.inventory_2_outlined,
                          color: theme.colorScheme.primary,
                          size: AppSizes.iconLg,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.inventory_2_outlined,
                      color: theme.colorScheme.primary,
                      size: AppSizes.iconLg,
                    ),
            ),
            const SizedBox(width: AppSizes.md),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'SKU: ${product.sku}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Price & stock
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${AppStrings.currencySymbol}${product.sellingPrice.toStringAsFixed(0)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: stockColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppSizes.radiusSm),
                  ),
                  child: Text(
                    stockLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: stockColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
