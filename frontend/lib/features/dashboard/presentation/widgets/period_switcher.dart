import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Segmented control for the dashboard window (Today / 7 days / 30 days).
/// Mirrors `components/period-switcher.tsx`.
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DashboardPeriod value;
  final ValueChanged<DashboardPeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        color: AppColors.canvas,
        shape: AppShapes.squircle(
          AppSizes.radiusButton,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in DashboardPeriod.values) _segment(p, l10n),
        ],
      ),
    );
  }

  String _periodLabel(DashboardPeriod p, AppLocalizations l10n) =>
      switch (p) {
        DashboardPeriod.today => l10n.dashboardPeriodToday,
        DashboardPeriod.week => l10n.dashboardPeriodWeek,
        DashboardPeriod.month => l10n.dashboardPeriodMonth,
      };

  Widget _segment(DashboardPeriod p, AppLocalizations l10n) {
    final selected = p == value;
    return GestureDetector(
      onTap: () => onChanged(p),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding:
            const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 6),
        decoration: ShapeDecoration(
          color: selected ? AppColors.inverseSurface : Colors.transparent,
          shape: AppShapes.squircle(6),
        ),
        child: Text(
          _periodLabel(p, l10n),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.onInverse : AppColors.muted,
          ),
        ),
      ),
    );
  }
}
