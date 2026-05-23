import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/widgets/product_thumbnail.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Product row used by the merchant listing screen.
///
/// Merchant-first signal hierarchy (was customer-store-style before):
///   1. Name + (SKU · HSN) — identification
///   2. Sell · cost · margin % — what you actually price-set against,
///      with the margin colour-coded (green ≥ 20%, amber 5–20%, red < 5%)
///   3. Stock state with threshold context ("3 KG / reorder at 5")
///   4. Loss-leader flag if sellingPrice > MRP (a price-entry mistake
///      worth catching at a glance)
///
/// The whole row is tappable to the product detail page.
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

  /// Margin = (sell − cost) / sell × 100. Returns null when sellingPrice
  /// is zero (avoids div-by-zero) — the UI then hides the chip.
  double? get _marginPct {
    if (product.sellingPrice <= 0) return null;
    return ((product.sellingPrice - product.purchasePrice) /
            product.sellingPrice) *
        100;
  }

  ({Color fg, Color bg}) _marginPalette(double m) {
    if (m < 0) return (fg: AppColors.error, bg: AppColors.errorSoft);
    if (m < 5) return (fg: AppColors.error, bg: AppColors.errorSoft);
    if (m < 20) return (fg: AppColors.warning, bg: AppColors.warningSoft);
    return (fg: AppColors.success, bg: AppColors.successSoft);
  }

  bool get _isAboveMrp =>
      product.mrp > 0 && product.sellingPrice > product.mrp + 0.005;

  String _stockLabel() {
    final qty = _formatQty(product.stockQuantity);
    final unit = product.unit;
    if (product.isOutOfStock) {
      return 'Out of stock';
    }
    if (product.isLowStock) {
      final threshold = _formatQty(product.lowStockThreshold);
      return '$qty $unit · reorder at $threshold';
    }
    return '$qty $unit in stock';
  }

  ({Color fg, Color bg, IconData icon}) _stockPalette() {
    if (product.isOutOfStock) {
      return (fg: AppColors.error, bg: AppColors.errorSoft, icon: Icons.error_outline_rounded);
    }
    if (product.isLowStock) {
      return (fg: AppColors.warning, bg: AppColors.warningSoft, icon: Icons.warning_amber_rounded);
    }
    return (fg: AppColors.success, bg: AppColors.successSoft, icon: Icons.check_circle_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = context.watch<NavigationPrefsProvider>().isCompact;
    final imageSide = compact ? 56.0 : 72.0;
    final vPad = compact ? AppSizes.sm : AppSizes.md;
    final margin = _marginPct;
    final stock = _stockPalette();

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
                    // Name
                    Text(
                      product.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Identifiers — SKU · HSN · Category (when shown)
                    Text(
                      _buildIdentifierLine(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    // Price + margin line
                    _MerchantPriceLine(
                      sell: product.sellingPrice,
                      cost: product.purchasePrice,
                      mrp: product.mrp,
                      marginPct: margin,
                      marginPalette: margin == null ? null : _marginPalette(margin),
                      isAboveMrp: _isAboveMrp,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    // Stock pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSizes.sm,
                        vertical: 3,
                      ),
                      decoration: ShapeDecoration(
                        color: stock.bg,
                        shape: AppShapes.squircle(AppSizes.radiusFull),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(stock.icon, size: 12, color: stock.fg),
                          const SizedBox(width: 4),
                          Text(
                            _stockLabel(),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: stock.fg,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
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

  String _buildIdentifierLine() {
    final parts = <String>[product.sku];
    if (product.hsnCode != null && product.hsnCode!.isNotEmpty) {
      parts.add('HSN ${product.hsnCode}');
    }
    if (showCategory && product.category != null) {
      parts.add(product.category!.name);
    }
    return parts.join(' · ');
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }
}

/// Sell price (prominent) · cost (muted, smaller) · margin chip.
/// When sellingPrice exceeds MRP, a small amber "above MRP" badge is
/// added to flag a likely price-entry mistake.
class _MerchantPriceLine extends StatelessWidget {
  const _MerchantPriceLine({
    required this.sell,
    required this.cost,
    required this.mrp,
    required this.marginPct,
    required this.marginPalette,
    required this.isAboveMrp,
  });

  final double sell;
  final double cost;
  final double mrp;
  final double? marginPct;
  final ({Color fg, Color bg})? marginPalette;
  final bool isAboveMrp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSizes.sm,
      runSpacing: 2,
      children: [
        // Sell price — primary
        Text(
          '${AppStrings.currencySymbol}${_fmt(sell)}',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.0,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // Cost — secondary (always shown if non-zero)
        if (cost > 0)
          Text(
            'cost ${AppStrings.currencySymbol}${_fmt(cost)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.muted,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        // Margin chip — colour codes profitability at a glance
        if (marginPct != null && marginPalette != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: ShapeDecoration(
              color: marginPalette!.bg,
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: Text(
              '${marginPct! >= 0 ? '' : ''}${marginPct!.toStringAsFixed(0)}%',
              style: TextStyle(
                color: marginPalette!.fg,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.2,
              ),
            ),
          ),
        // Above-MRP warning — a real signal merchants want to catch
        if (isAboveMrp)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: ShapeDecoration(
              color: AppColors.warningSoft,
              shape: AppShapes.squircle(AppSizes.radiusFull),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 11,
                  color: AppColors.warning,
                ),
                const SizedBox(width: 3),
                Text(
                  'above M.R.P.',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _fmt(double v) =>
      v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);
}
