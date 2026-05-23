import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Always-visible KPI strip above the product list. Reads from the
/// DashboardProvider that's already populated for the home tab so we
/// don't fire a second round of stats queries.
///
/// Each KPI is tappable: the low-stock and out-of-stock counts apply
/// the matching list filter; the total-products and stock-value pills
/// clear filters (act as the "All" reset).
class ProductsKpiStrip extends StatelessWidget {
  const ProductsKpiStrip({
    super.key,
    required this.onTapAll,
    required this.onTapLowStock,
    required this.onTapOutOfStock,
  });

  final VoidCallback onTapAll;
  final VoidCallback onTapLowStock;
  final VoidCallback onTapOutOfStock;

  String _formatInt(int v) => NumberFormat.decimalPattern('en_IN').format(v);

  String _formatMoney(double v) {
    // Compact Indian formatting: 8.52L, 1.23Cr.
    if (v.abs() >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)}Cr';
    if (v.abs() >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)}L';
    return NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(v);
  }

  @override
  Widget build(BuildContext context) {
    final stats = context.watch<DashboardProvider>().stats;

    // Loading skeleton when dashboard hasn't loaded yet — same vertical
    // height so the page doesn't jump when stats arrive.
    if (stats == null) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
        child: SizedBox(height: 64),
      );
    }

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
            child: _KpiCell(
              label: 'Products',
              value: _formatInt(stats.activeProducts),
              tone: _Tone.neutral,
              onTap: onTapAll,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _KpiCell(
              label: 'Low',
              value: _formatInt(stats.lowStockCount),
              tone: stats.lowStockCount > 0 ? _Tone.warning : _Tone.neutral,
              onTap: onTapLowStock,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: _KpiCell(
              label: 'Out',
              value: _formatInt(stats.outOfStockCount),
              tone: stats.outOfStockCount > 0 ? _Tone.error : _Tone.neutral,
              onTap: onTapOutOfStock,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            flex: 2,
            child: _KpiCell(
              label: 'Stock value',
              value: _formatMoney(stats.totalStockValue),
              tone: _Tone.brand,
              onTap: onTapAll,
            ),
          ),
        ],
      ),
    );
  }
}

enum _Tone { neutral, warning, error, brand }

class _KpiCell extends StatelessWidget {
  const _KpiCell({
    required this.label,
    required this.value,
    required this.tone,
    required this.onTap,
  });

  final String label;
  final String value;
  final _Tone tone;
  final VoidCallback onTap;

  ({Color fg, Color bg, Color border}) _palette() {
    return switch (tone) {
      _Tone.warning => (
          fg: AppColors.warning,
          bg: AppColors.warningSoft,
          border: AppColors.warning,
        ),
      _Tone.error => (
          fg: AppColors.error,
          bg: AppColors.errorSoft,
          border: AppColors.error,
        ),
      _Tone.brand => (
          fg: AppColors.brandStrong,
          bg: AppColors.brandSoft,
          border: AppColors.brand,
        ),
      _Tone.neutral => (
          fg: AppColors.black,
          bg: AppColors.white,
          border: AppColors.hairline,
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = _palette();
    return Material(
      color: p.bg,
      shape: AppShapes.squircle(
        AppSizes.radiusMd,
        side: BorderSide(color: p.border, width: tone == _Tone.neutral ? 1 : 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.sm,
            vertical: AppSizes.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tone == _Tone.neutral ? AppColors.muted : p.fg,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: p.fg,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
