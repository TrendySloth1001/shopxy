import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
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
///   4. Last-activity hint ("Sold 3d ago" / "Out since 5d ago") + vendor pill
///   5. Loss-leader flag if sellingPrice > MRP (a price-entry mistake
///      worth catching at a glance)
///
/// Density modes are meaningfully different:
///   • compact   — small thumb, name 1 line, no description, tight padding.
///   • comfortable (card) — large thumb, name up to 2 lines, description shown
///                 when present, larger price font.
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
    // Card mode (comfortable) is the richer layout — bigger thumb, more
    // breathing room, name wraps to 2 lines, description visible.
    final imageSide = compact ? 56.0 : 96.0;
    final vPad = compact ? AppSizes.sm : AppSizes.lg;
    final nameMaxLines = compact ? 1 : 2;
    final showDescription =
        !compact && (product.description?.trim().isNotEmpty ?? false);
    final priceStyle = compact
        ? theme.textTheme.titleMedium
        : theme.textTheme.titleLarge;
    final margin = _marginPct;
    final stock = _stockPalette();
    final activity = _activityHint();
    final hasVendor =
        (product.lastVendorName != null && product.lastVendorName!.isNotEmpty);
    final showMetaLine = activity != null || hasVendor;

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
                      maxLines: nameMaxLines,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Identifiers — SKU · HSN · Category (when shown).
                    // Category renders with its picked icon so the row
                    // matches the bucket header / picker visually.
                    _buildIdentifierRow(theme),
                    // Description — comfortable-only, gives the card real body
                    if (showDescription) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.description!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.muted,
                          height: 1.35,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSizes.sm),
                    // Price + margin line
                    _MerchantPriceLine(
                      sell: product.sellingPrice,
                      cost: product.purchasePrice,
                      mrp: product.mrp,
                      marginPct: margin,
                      marginPalette: margin == null ? null : _marginPalette(margin),
                      isAboveMrp: _isAboveMrp,
                      priceStyle: priceStyle,
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
                    // Last-activity + vendor pill row — only when we have
                    // something to say. Skipped entirely for fresh products
                    // with no ledger history so we don't render empty space.
                    if (showMetaLine) ...[
                      const SizedBox(height: AppSizes.xs),
                      Wrap(
                        spacing: AppSizes.xs,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (activity != null)
                            _MetaChip(
                              icon: activity.icon,
                              label: activity.label,
                              fg: activity.fg,
                              bg: activity.bg,
                            ),
                          if (hasVendor)
                            _MetaChip(
                              icon: Icons.storefront_outlined,
                              label: product.lastVendorName!,
                              fg: AppColors.muted,
                              bg: AppColors.surfaceTint,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Renders the SKU · HSN · Category line. Category portion uses a
  /// [WidgetSpan] so the picked icon sits inline with the text rather
  /// than forcing the row into a wrapping layout.
  Widget _buildIdentifierRow(ThemeData theme) {
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppColors.muted,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final leading = StringBuffer(product.sku);
    if (product.hsnCode != null && product.hsnCode!.isNotEmpty) {
      leading.write(' · HSN ${product.hsnCode}');
    }

    final spans = <InlineSpan>[TextSpan(text: leading.toString())];
    if (showCategory && product.category != null) {
      spans.add(const TextSpan(text: ' · '));
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Icon(
            resolveCategoryIcon(product.category!.iconName),
            size: 12,
            color: AppColors.muted,
          ),
        ),
      ));
      spans.add(TextSpan(text: product.category!.name));
    }

    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: baseStyle, children: spans),
    );
  }

  String _formatQty(double qty) {
    return qty.truncateToDouble() == qty
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);
  }

  /// Resolve the most useful last-activity hint for this row.
  ///
  /// Rules (in order):
  ///   • Out-of-stock + lastStockOutAt → "Out since 5d ago" (red).
  ///   • Otherwise, whichever of lastStockOutAt / lastStockInAt is most recent
  ///     wins. STOCK_OUT framed as "Sold Xago", STOCK_IN as "Stocked in Xago"
  ///     (within 7d) or "Last in: Xago" when older.
  ///   • Nothing if there's no ledger movement at all.
  ({IconData icon, String label, Color fg, Color bg})? _activityHint() {
    final lastIn = product.lastStockInAt;
    final lastOut = product.lastStockOutAt;

    if (product.isOutOfStock && lastOut != null) {
      return (
        icon: Icons.event_busy_outlined,
        label: 'Out since ${_relativeTime(lastOut)}',
        fg: AppColors.error,
        bg: AppColors.errorSoft,
      );
    }

    // Pick the most recent of the two when both exist — STOCK_OUT framed
    // as "Sold X ago" since the merchant cares more about the movement.
    if (lastOut != null && (lastIn == null || lastOut.isAfter(lastIn))) {
      return (
        icon: Icons.point_of_sale_outlined,
        label: 'Sold ${_relativeTime(lastOut)}',
        fg: AppColors.muted,
        bg: AppColors.surfaceTint,
      );
    }

    if (lastIn != null) {
      final ageDays = DateTime.now().difference(lastIn).inDays;
      final label = ageDays <= 7
          ? 'Stocked in ${_relativeTime(lastIn)}'
          : 'Last in: ${_relativeTime(lastIn)}';
      return (
        icon: Icons.south_west_rounded,
        label: label,
        fg: AppColors.muted,
        bg: AppColors.surfaceTint,
      );
    }

    return null;
  }
}

/// Concise relative-time formatter — "5h ago", "2d ago", "1w ago", "3mo ago".
/// Tuned for at-a-glance scanning in dense list rows, not precision.
String _relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  final days = diff.inDays;
  if (days < 7) return '${days}d ago';
  if (days < 30) return '${(days / 7).floor()}w ago';
  if (days < 365) return '${(days / 30).floor()}mo ago';
  return '${(days / 365).floor()}y ago';
}

/// Tiny rounded pill used for the activity + vendor metadata row.
class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 10.5,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
    this.priceStyle,
  });

  final double sell;
  final double cost;
  final double mrp;
  final double? marginPct;
  final ({Color fg, Color bg})? marginPalette;
  final bool isAboveMrp;
  final TextStyle? priceStyle;

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
          style: (priceStyle ?? theme.textTheme.titleMedium)?.copyWith(
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
