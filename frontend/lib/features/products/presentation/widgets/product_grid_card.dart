import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class ProductGridCard extends StatelessWidget {
  const ProductGridCard({
    super.key,
    required this.product,
    this.onTap,
    this.showCategory = true,
  });

  final Product product;
  final VoidCallback? onTap;
  final bool showCategory;

  double? get _marginPct {
    if (product.sellingPrice <= 0) return null;
    return ((product.sellingPrice - product.purchasePrice) /
            product.sellingPrice) *
        100;
  }

  ({Color fg, Color bg}) _marginPalette(double m) {
    if (m < 20) {
      return m < 5
          ? (fg: AppColors.error, bg: AppColors.errorSoft)
          : (fg: AppColors.warning, bg: AppColors.warningSoft);
    }
    return (fg: AppColors.success, bg: AppColors.successSoft);
  }

  bool get _isAboveMrp =>
      product.mrp > 0 && product.sellingPrice > product.mrp + 0.005;

  ({Color fg, Color bg, AppIconData icon}) _stockPalette() {
    if (product.isOutOfStock) {
      return (
        fg: AppColors.error,
        bg: AppColors.errorSoft,
        icon: AppIcons.errorOutlineRounded,
      );
    }
    if (product.isLowStock) {
      return (
        fg: AppColors.warning,
        bg: AppColors.warningSoft,
        icon: AppIcons.warningAmberRounded,
      );
    }
    return (
      fg: AppColors.success,
      bg: AppColors.successSoft,
      icon: AppIcons.checkCircleOutlineRounded,
    );
  }

  String _stockLabel(AppLocalizations l10n) {
    final qty = _fmt(product.stockQuantity);
    if (product.isOutOfStock) return l10n.productsOutOfStockLabel;
    if (product.isLowStock) {
      return '$qty ${product.unit} · ${l10n.productsReorderAt} '
          '${_fmt(product.lowStockThreshold)}';
    }
    return '$qty ${product.unit} ${l10n.productsInStockSuffix}';
  }

  ({AppIconData icon, String label, Color fg, Color bg})? _activityHint(
    AppLocalizations l10n,
  ) {
    final lastIn = product.lastStockInAt;
    final lastOut = product.lastStockOutAt;
    if (product.isOutOfStock && lastOut != null) {
      return (
        icon: AppIcons.eventBusyOutlined,
        label: '${l10n.productsOutSince} ${_relativeTime(lastOut)}',
        fg: AppColors.error,
        bg: AppColors.errorSoft,
      );
    }
    if (lastOut != null && (lastIn == null || lastOut.isAfter(lastIn))) {
      return (
        icon: AppIcons.pointOfSaleOutlined,
        label: '${l10n.productsSold} ${_relativeTime(lastOut)}',
        fg: AppColors.muted,
        bg: AppColors.surfaceTint,
      );
    }
    if (lastIn != null) {
      final ageDays = DateTime.now().difference(lastIn).inDays;
      return (
        icon: AppIcons.southWestRounded,
        label: ageDays <= 7
            ? '${l10n.productsStockedIn} ${_relativeTime(lastIn)}'
            : '${l10n.productsLastIn} ${_relativeTime(lastIn)}',
        fg: AppColors.muted,
        bg: AppColors.surfaceTint,
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final margin = _marginPct;
    final stock = _stockPalette();
    final activity = _activityHint(l10n);
    final hasVendor =
        product.lastVendorName != null && product.lastVendorName!.isNotEmpty;
    final hasDescription = product.description?.trim().isNotEmpty ?? false;

    return Material(
      color: AppColors.surface,
      shape: AppShapes.squircle(
        AppSizes.radiusLg,
        side: BorderSide(color: AppColors.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _ProductImage(product: product),
                  if (product.isOutOfStock || product.isLowStock)
                    Positioned(
                      top: AppSizes.sm,
                      left: AppSizes.sm,
                      child: _Pill(
                        icon: stock.icon,
                        label: product.isOutOfStock
                            ? l10n.productsOutOfStockLabel
                            : l10n.productsLowStock,
                        fg: stock.fg,
                        bg: stock.bg,
                        bold: true,
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSizes.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xxs),
                  _identifiers(theme),
                  if (hasDescription) ...[
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      product.description!.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        height: 1.3,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSizes.sm,
                    runSpacing: 2,
                    children: [
                      Text(
                        '${AppStrings.currencySymbol}${_fmt(product.sellingPrice)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: AppColors.black,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.0,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      if (margin != null)
                        _Pill(
                          label: '${margin.toStringAsFixed(0)}%',
                          fg: _marginPalette(margin).fg,
                          bg: _marginPalette(margin).bg,
                          bold: true,
                        ),
                      if (_isAboveMrp)
                        _Pill(
                          icon: AppIcons.errorOutlineRounded,
                          label: l10n.productsAboveMrp,
                          fg: AppColors.warning,
                          bg: AppColors.warningSoft,
                        ),
                    ],
                  ),
                  if (product.purchasePrice > 0) ...[
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      '${l10n.productsCostPrefix} ${AppStrings.currencySymbol}${_fmt(product.purchasePrice)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _Pill(
                      icon: stock.icon,
                      label: _stockLabel(l10n),
                      fg: stock.fg,
                      bg: stock.bg,
                      bold: true,
                    ),
                  ),
                  if (activity != null || hasVendor) ...[
                    const SizedBox(height: AppSizes.xs),
                    Wrap(
                      spacing: AppSizes.xs,
                      runSpacing: 4,
                      children: [
                        if (activity != null)
                          _Pill(
                            icon: activity.icon,
                            label: activity.label,
                            fg: activity.fg,
                            bg: activity.bg,
                          ),
                        if (hasVendor)
                          _Pill(
                            icon: AppIcons.storefrontOutlined,
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
    );
  }

  Widget _identifiers(ThemeData theme) {
    final base = theme.textTheme.bodySmall?.copyWith(
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
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: AppIcon(
              resolveCategoryIcon(product.category!.iconName),
              size: 12,
              color: AppColors.muted,
            ),
          ),
        ),
      );
      spans.add(TextSpan(text: product.category!.name));
    }
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(style: base, children: spans),
    );
  }
}

String _fmt(double v) =>
    v.truncateToDouble() == v ? v.toInt().toString() : v.toStringAsFixed(2);

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

class _ProductImage extends StatelessWidget {
  const _ProductImage({required this.product});
  final Product product;

  static List<(Color, Color)> get _accents => [
    (AppColors.brandSoft, AppColors.brandStrong),
    (AppColors.accentTealSoft, AppColors.accentTeal),
    (AppColors.accentIndigoSoft, AppColors.accentIndigo),
    (AppColors.accentAmberSoft, AppColors.accentAmber),
    (AppColors.accentRoseSoft, AppColors.accentRose),
    (AppColors.successSoft, AppColors.success),
  ];

  @override
  Widget build(BuildContext context) {
    final raw = product.primaryImageUrl ?? '';
    final (bg, fg) = _accents[product.id.hashCode.abs() % _accents.length];
    Widget monogram() => Container(
      color: AppColors.tileBg(bg),
      alignment: Alignment.center,
      child: Text(
        product.name.trim().isEmpty
            ? '?'
            : product.name.trim()[0].toUpperCase(),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
          fontSize: 40,
          letterSpacing: -0.5,
        ),
      ),
    );
    if (raw.isEmpty) return monogram();
    final decodeWidth =
        (MediaQuery.sizeOf(context).width / 2 *
                MediaQuery.devicePixelRatioOf(context))
            .round();
    return CachedNetworkImage(
      imageUrl: resolveImageUrl(raw),
      fit: BoxFit.cover,
      memCacheWidth: decodeWidth,
      placeholder: (_, _) => ColoredBox(color: AppColors.heroPanel),
      errorWidget: (_, _, _) => monogram(),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fg,
    required this.bg,
    this.icon,
    this.bold = false,
  });
  final String label;
  final Color fg;
  final Color bg;
  final AppIconData? icon;
  final bool bold;

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
          if (icon != null) ...[
            AppIcon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
