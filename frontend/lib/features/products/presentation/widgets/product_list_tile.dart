import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/widgets/product_thumbnail.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_status_badge.dart';

/// Product card used by the listing screen. Card-style layout (large
/// product image left, a vertical info stack on the right) — far
/// easier to scan than the older single-row design, which compressed
/// price, stock state, and identifying detail into one cramped strip.
///
/// Content stack on the right (top → bottom):
///   1. Product name (titleSmall, w700, up to 2 lines)
///   2. Identifier line: `SKU · Category` (small, muted)
///   3. Optional one-line description (small, muted)
///   4. Selling price (titleMedium, w800) with optional MRP
///      strikethrough + percent-off badge when there's an actual
///      discount
///   5. Stock status badge — green/amber/red tone tells the user at a
///      glance whether the product needs attention
///
/// The whole card is tappable to the product detail page.
class ProductListTile extends StatelessWidget {
  const ProductListTile({
    super.key,
    required this.product,
    this.onTap,
    this.showCategory = false,
  });

  final Product product;
  final VoidCallback? onTap;

  /// When `true`, the row prints its category next to the SKU so the
  /// user still knows what bucket they're in when section headers
  /// aren't being rendered.
  final bool showCategory;

  ({String label, AppStatusTone tone, AppStatusWeight weight}) get _stockChip {
    if (product.isOutOfStock) {
      return (
        label: AppStrings.outOfStock,
        tone: AppStatusTone.error,
        weight: AppStatusWeight.filled,
      );
    }
    if (product.isLowStock) {
      return (
        label:
            '${AppStrings.lowStock} · ${_formatQty(product.stockQuantity)} ${product.unit}',
        tone: AppStatusTone.warning,
        weight: AppStatusWeight.soft,
      );
    }
    return (
      label:
          '${AppStrings.inStock} · ${_formatQty(product.stockQuantity)} ${product.unit}',
      tone: AppStatusTone.success,
      weight: AppStatusWeight.soft,
    );
  }

  int? get _discountPercent {
    if (product.mrp <= 0 || product.sellingPrice >= product.mrp) return null;
    final pct = ((product.mrp - product.sellingPrice) / product.mrp) * 100;
    return pct.round();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.watch<NavigationPrefsProvider>().isCompact;
    final imageSide = compact ? 92.0 : 116.0;
    final vPad = compact ? AppSizes.sm : AppSizes.md;
    final chip = _stockChip;
    final discount = _discountPercent;
    final subtitle = _buildSubtitle();

    return Material(
      color: AppColors.white,
      child: InkWell(
        onTap: onTap,
        splashColor: AppColors.surfaceTint,
        highlightColor: AppColors.surfaceTint,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.lg,
            vertical: vPad,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProductThumbnail(product: product, size: imageSide),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (!compact &&
                        product.description != null &&
                        product.description!.isNotEmpty) ...[
                      const SizedBox(height: AppSizes.xs),
                      Text(
                        product.description!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: compact ? AppSizes.xs : AppSizes.sm),
                    _PriceRow(
                      sellingPrice: product.sellingPrice,
                      mrp: product.mrp,
                      discountPercent: discount,
                    ),
                    SizedBox(height: compact ? AppSizes.xs : AppSizes.sm),
                    AppStatusBadge(
                      label: chip.label,
                      tone: chip.tone,
                      weight: chip.weight,
                      icon: _stockIcon,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _buildSubtitle() {
    final parts = <String>[product.sku];
    if (showCategory && product.category != null) {
      parts.add(product.category!.name);
    }
    return parts.join(' · ');
  }

  IconData get _stockIcon {
    if (product.isOutOfStock) return Icons.error_outline_rounded;
    if (product.isLowStock) return Icons.warning_amber_rounded;
    return Icons.check_circle_outline_rounded;
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}

/// Selling price + optional MRP strikethrough + percent-off chip.
/// Lays out on one line; gracefully wraps to a second when the
/// strikethrough chunk doesn't fit.
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.sellingPrice,
    required this.mrp,
    required this.discountPercent,
  });

  final double sellingPrice;
  final double mrp;
  final int? discountPercent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      spacing: AppSizes.sm,
      runSpacing: 2,
      children: [
        Text(
          '${AppStrings.currencySymbol}${_formatPrice(sellingPrice)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (discountPercent != null) ...[
          Text(
            'M.R.P ${AppStrings.currencySymbol}${_formatPrice(mrp)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              decoration: TextDecoration.lineThrough,
              decorationColor: AppColors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            '($discountPercent% off)',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.success,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  String _formatPrice(double price) {
    return price.truncateToDouble() == price
        ? price.toInt().toString()
        : price.toStringAsFixed(2);
  }
}
