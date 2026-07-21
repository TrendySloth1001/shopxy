import 'package:flutter/material.dart';
import 'package:shopxy/features/cashier/presentation/pages/cashier_page.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/reports/presentation/pages/reports_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

/// Session-scoped dismissed alert ids — survives rebuilds + period reloads,
/// resets when the app restarts (mirrors the web's sessionStorage).
final Set<String> _dismissed = <String>{};

/// CTA label per alert id (the message already carries the detail).
String _ctaLabel(AppLocalizations l10n, String id) => switch (id) {
  'low-stock' => l10n.dashboardAlertReorder,
  'gst-due' => l10n.dashboardAlertFileGst,
  'sales-drop' => l10n.dashboardAlertViewReport,
  'till-open' => l10n.dashboardAlertOpenTill,
  _ => l10n.dashboardView,
};

/// Dismissible smart-alert notifications. Mirrors `components/alerts.tsx`.
class Alerts extends StatefulWidget {
  const Alerts({super.key, required this.alerts});
  final List<DashboardAlert> alerts;

  @override
  State<Alerts> createState() => _AlertsState();
}

class _AlertsState extends State<Alerts> {
  void _openHref(String href) {
    final Widget page = switch (href) {
      '/dashboard/products' => const ProductsPage(),
      '/dashboard/cashier' => const CashierPage(),
      _ => const ReportsPage(), // reports + any other money path
    };
    dashPush(context, page);
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.alerts
        .where((a) => !_dismissed.contains(a.id))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: ShapeDecoration(
        color: AppColors.canvas,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
        shadows: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: AppColors.hairline),
            _AlertRow(
              alert: visible[i],
              onAction: () => _openHref(visible[i].href),
              onDismiss: () => setState(() => _dismissed.add(visible[i].id)),
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({
    required this.alert,
    required this.onAction,
    required this.onDismiss,
  });

  final DashboardAlert alert;
  final VoidCallback onAction;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, iconColor) = switch (alert.severity) {
      AlertSeverity.critical => (AppIcons.errorOutlineRounded, AppColors.error),
      AlertSeverity.warning => (
        AppIcons.warningAmberRounded,
        AppColors.warning,
      ),
      AlertSeverity.info => (
        AppIcons.infoOutlineRounded,
        AppColors.brandStrong,
      ),
    };
    final cta = _ctaLabel(l10n, alert.id);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSizes.md),
          Expanded(child: Text(alert.message, style: DashText.bodyMd)),
          const SizedBox(width: AppSizes.sm),
          OutlinedButton(
            onPressed: onAction,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.black,
              side: BorderSide(color: AppColors.hairline),
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: AppShapes.squircle(AppSizes.radiusButton),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cta,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSizes.xxs),
                const AppIcon(AppIcons.arrowForwardRounded, size: 14),
              ],
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: const AppIcon(AppIcons.closeRounded, size: 16),
            color: AppColors.subtle,
            visualDensity: VisualDensity.compact,
            tooltip: l10n.dashboardDismiss,
          ),
        ],
      ),
    );
  }
}
