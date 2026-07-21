import 'package:flutter/material.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';
import 'package:shopxy/features/dashboard/presentation/widgets/dashboard_ui.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/shop/presentation/widgets/payout_setup_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class _Step {
  const _Step(this.done, this.title, this.desc, this.cta, this.onTap);
  final bool done;
  final String title;
  final String desc;
  final String cta;
  final VoidCallback onTap;
}

/// First-run setup checklist, shown in place of the KPI grid until the shop
/// has products and invoices. Mirrors `components/onboarding-checklist.tsx`.
class OnboardingChecklist extends StatelessWidget {
  const OnboardingChecklist({
    super.key,
    required this.onboarding,
    required this.payoutsEnabled,
  });

  final DashboardOnboarding onboarding;
  final bool payoutsEnabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final steps = <_Step>[
      _Step(
        onboarding.totalProducts > 0,
        l10n.dashboardAddFirstProductTitle,
        l10n.dashboardAddFirstProductDesc,
        l10n.dashboardAddProduct,
        () => dashPush(context, const ProductsPage()),
      ),
      _Step(
        onboarding.hasInvoices,
        l10n.dashboardCreateFirstInvoiceTitle,
        l10n.dashboardCreateFirstInvoiceDesc,
        l10n.dashboardNewInvoice,
        () => dashPush(context, const InvoicesPage()),
      ),
      _Step(
        onboarding.hasParties,
        l10n.dashboardAddCustomerTitle,
        l10n.dashboardAddCustomerDesc,
        l10n.dashboardAddCustomer,
        () => dashPush(context, const PartiesPage()),
      ),
      _Step(
        payoutsEnabled,
        l10n.dashboardSetUpPayoutsTitle,
        l10n.dashboardSetUpPayoutsDesc,
        l10n.dashboardSetUp,
        () => showPayoutSetupSheet(context),
      ),
    ];
    final completed = steps.where((s) => s.done).length;

    return DashCard(
      padding: const EdgeInsets.all(AppSizes.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.dashboardGetShopReady,
                      style: DashText.headlineSm,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Text(
                      l10n.dashboardOnboardingSubtitle,
                      style: DashText.bodyMd.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Text(
                l10n.dashboardStepsDone('$completed', '${steps.length}'),
                style: DashText.labelMd.copyWith(fontFeatures: tabularFigures),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: AppColors.hairline),
            _StepRow(step: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
      child: Row(
        children: [
          AppIcon(
            step.done ? AppIcons.checkCircleRounded : AppIcons.circleOutlined,
            size: AppSizes.iconMd,
            color: step.done ? AppColors.success : AppColors.subtle,
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: DashText.bodyMd.copyWith(
                    color: step.done ? AppColors.muted : AppColors.black,
                    decoration: step.done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!step.done) Text(step.desc, style: DashText.bodySm),
              ],
            ),
          ),
          if (!step.done) ...[
            const SizedBox(width: AppSizes.sm),
            OutlinedButton(
              onPressed: step.onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: BorderSide(color: AppColors.hairline),
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: AppShapes.squircle(AppSizes.radiusButton),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.cta,
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
          ],
        ],
      ),
    );
  }
}
