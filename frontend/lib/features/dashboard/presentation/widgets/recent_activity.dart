import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shopxy/features/challans/presentation/pages/challan_detail_page.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Recent stock movements feed, each row linking to its source document.
/// Mirrors `components/recent-activity.tsx`.
class RecentActivity extends StatelessWidget {
  const RecentActivity({super.key, required this.transactions});
  final List<DashboardTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return DashSection(
      title: l10n.dashboardRecentActivity,
      child: transactions.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSizes.lg),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      size: AppSizes.iconMd, color: AppColors.subtle),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: Text(l10n.dashboardNoRecentMovements,
                        style:
                            DashText.bodyMd.copyWith(color: AppColors.muted)),
                  ),
                ],
              ),
            )
          : Column(
              children: [for (final t in transactions) _ActivityRow(tx: t)],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.tx});
  final DashboardTransaction tx;

  void _openSource(BuildContext context) {
    final id = tx.sourceId;
    if (id == null) return;
    switch (tx.sourceType) {
      case 'INVOICE':
        dashPush(context, InvoiceDetailPage(invoiceId: id));
      case 'CHALLAN':
        dashPush(context, ChallanDetailPage(challanId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isIn = tx.isIn;
    final isOut = tx.isOut;
    final accent = isIn
        ? AppColors.success
        : isOut
            ? AppColors.error
            : AppColors.accentIndigo;
    final accentSoft = isIn
        ? AppColors.successSoft
        : isOut
            ? AppColors.errorSoft
            : AppColors.accentIndigoSoft;
    final icon = isIn
        ? Icons.south_west_rounded
        : isOut
            ? Icons.north_east_rounded
            : Icons.swap_horiz_rounded;
    final sign = isIn ? '+' : (isOut ? '−' : '');
    final time = DateFormat('d MMM · hh:mm a').format(tx.createdAt.toLocal());
    final actionable = tx.hasSourceDocument;

    return InkWell(
      onTap: actionable ? () => _openSource(context) : null,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.hairline)),
        ),
        padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
        child: Row(
          children: [
            Container(
              width: AppSizes.avatarXs,
              height: AppSizes.avatarXs,
              decoration: ShapeDecoration(
                  color: accentSoft,
                  shape: AppShapes.squircle(AppSizes.radiusMd)),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.productName ??
                        l10n.dashboardProductFallback('${tx.productId}'),
                    style: DashText.bodyMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(time, style: DashText.bodySm),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              '$sign${fmtQty(tx.quantity)}',
              style: DashText.titleMd.copyWith(
                color: accent,
                fontFeatures: tabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
