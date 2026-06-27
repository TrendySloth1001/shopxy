import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/pos/presentation/pages/pos_page.dart';
import 'package:shopxy/features/reports/presentation/pages/reports_page.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustments_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// Compact operations strip: open till (if the viewer has one), GST liability
/// month-to-date, and current inventory value. Mirrors `components/operations.tsx`.
class Operations extends StatelessWidget {
  const Operations({super.key, required this.operations});
  final DashboardOperations operations;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      if (operations.till != null) _TillTile(till: operations.till!),
      if (operations.gstMtd != null)
        _Tile(
          icon: Icons.receipt_long_outlined,
          iconColor: AppColors.accentIndigo,
          label: 'GST this month',
          value: inr.format(operations.gstMtd!.netPayable),
          sub: '${inr.format(operations.gstMtd!.outputTax)} output tax collected',
          onTap: () => dashPush(context, const ReportsPage()),
        ),
      _Tile(
        icon: Icons.inventory_2_outlined,
        iconColor: AppColors.brandStrong,
        label: 'Inventory value',
        value: inr.format(operations.inventoryValue),
        sub: 'Cost basis of stock on hand',
        onTap: () => dashPush(context, const StockAdjustmentsPage()),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Eyebrow('Operations'),
        const SizedBox(height: AppSizes.md),
        LayoutBuilder(
          builder: (context, c) {
            final cols = responsiveCols(c.maxWidth, base: 1, sm: 2, lg: 3);
            return ResponsiveGrid(columns: cols, children: tiles);
          },
        ),
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DashCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: AppSizes.iconSm, color: iconColor),
              const SizedBox(width: AppSizes.sm),
              Flexible(
                child: Text(label,
                    style: DashText.labelMd, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(value,
              style:
                  DashText.headlineSm.copyWith(fontFeatures: tabularFigures)),
          const SizedBox(height: AppSizes.xs),
          Text(sub,
              style: DashText.bodySm,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TillTile extends StatelessWidget {
  const _TillTile({required this.till});
  final DashboardTill till;

  @override
  Widget build(BuildContext context) {
    final since = DateFormat('hh:mm a').format(till.openedAt.toLocal());
    final topTenders = till.tenders
        .take(3)
        .map((t) => '${t.mode} ${inr.format(t.amount)}')
        .join(' · ');
    final salesLabel = till.salesCount == 1 ? '1 sale' : '${till.salesCount} sales';
    return DashCard(
      onTap: () => dashPush(context, const PosPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.storefront_outlined,
                  size: AppSizes.iconSm, color: AppColors.success),
              const SizedBox(width: AppSizes.sm),
              Flexible(
                child: Text('Open till · since $since',
                    style: DashText.labelMd, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Text(inr.format(till.expectedCash),
              style:
                  DashText.headlineSm.copyWith(fontFeatures: tabularFigures)),
          const SizedBox(height: AppSizes.xs),
          Text(
            topTenders.isEmpty ? salesLabel : '$salesLabel · $topTenders',
            style: DashText.bodySm,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
