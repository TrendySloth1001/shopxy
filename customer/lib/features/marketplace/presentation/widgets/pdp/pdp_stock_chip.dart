import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class PdpStockChip extends StatelessWidget {
  const PdpStockChip({
    super.key,
    required this.stockQuantity,
    required this.lowStockThreshold,
  });
  final double stockQuantity;
  final double lowStockThreshold;

  @override
  Widget build(BuildContext context) {
    if (stockQuantity <= 0) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.sm,
          AppSizes.lg,
          0,
        ),
        child: _Pill(
          icon: AppIcons.blockRounded,
          label: 'Out of stock',
          fg: AppColors.error,
          bg: AppColors.errorSoft,
        ),
      );
    }
    final floor = lowStockThreshold > 5 ? lowStockThreshold : 5;
    if (stockQuantity > floor) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.sm,
        AppSizes.lg,
        0,
      ),
      child: _Pill(
        icon: AppIcons.localFireDepartmentRounded,
        label: 'Only ${stockQuantity.toStringAsFixed(0)} left',
        fg: AppColors.warning,
        bg: AppColors.warningSoft,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });
  final AppIconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: AppSizes.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppSizes.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, color: fg, size: AppSizes.iconSm),
            const SizedBox(width: AppSizes.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
