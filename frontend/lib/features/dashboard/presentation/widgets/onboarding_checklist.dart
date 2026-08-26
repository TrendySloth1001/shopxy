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
  const _Step(this.done, this.icon, this.title, this.desc, this.cta, this.onTap);
  final bool done;

  final AppIconData icon;
  final String title;
  final String desc;
  final String cta;
  final VoidCallback onTap;
}

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
        AppIcons.inventory2Rounded,
        l10n.dashboardAddFirstProductTitle,
        l10n.dashboardAddFirstProductDesc,
        l10n.dashboardAddProduct,
        () => dashPush(context, const ProductsPage()),
      ),
      _Step(
        onboarding.hasInvoices,
        AppIcons.receiptLongRounded,
        l10n.dashboardCreateFirstInvoiceTitle,
        l10n.dashboardCreateFirstInvoiceDesc,
        l10n.dashboardNewInvoice,
        () => dashPush(context, const InvoicesPage()),
      ),
      _Step(
        onboarding.hasParties,
        AppIcons.personAddAlt1Rounded,
        l10n.dashboardAddCustomerTitle,
        l10n.dashboardAddCustomerDesc,
        l10n.dashboardAddCustomer,
        () => dashPush(context, const PartiesPage()),
      ),
      _Step(
        payoutsEnabled,
        AppIcons.accountBalanceWalletRounded,
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
              _ProgressRing(completed: completed, total: steps.length),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          _ProgressBar(completed: completed, total: steps.length),
          const SizedBox(height: AppSizes.xs),
          Text(
            l10n.dashboardStepsDone('$completed', '${steps.length}'),
            style: DashText.bodySm.copyWith(fontFeatures: tabularFigures),
          ),
          const SizedBox(height: AppSizes.md),
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSizes.xs),
            _StepRow(step: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return SizedBox(
      width: 48,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(
              value: pct,
              strokeWidth: 4,
              backgroundColor: AppColors.surfaceTint,
              valueColor: AlwaysStoppedAnimation(AppColors.brand),
              strokeCap: StrokeCap.round,
            ),
          ),
          Text(
            '${(pct * 100).round()}%',
            style: DashText.labelMd.copyWith(
              color: AppColors.black,
              fontSize: 11,
              letterSpacing: 0,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.completed, required this.total});
  final int completed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : completed / total;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSizes.radiusFull),
      child: LinearProgressIndicator(
        value: pct,
        minHeight: 8,
        backgroundColor: AppColors.surfaceTint,
        valueColor: AlwaysStoppedAnimation(AppColors.brand),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    final done = step.done;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        children: [
          Container(
            width: AppSizes.huge,
            height: AppSizes.huge,
            decoration: ShapeDecoration(
              color: done ? AppColors.successSoft : AppColors.brandSoft,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              done ? AppIcons.checkCircleRounded : step.icon,
              size: AppSizes.iconMd,
              color: done ? AppColors.success : AppColors.brandStrong,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: DashText.bodyMd.copyWith(
                    color: done ? AppColors.muted : AppColors.black,
                    fontWeight: FontWeight.w600,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (!done) ...[
                  const SizedBox(height: 1),
                  Text(step.desc, style: DashText.bodySm),
                ],
              ],
            ),
          ),
          if (!done) ...[
            const SizedBox(width: AppSizes.sm),
            OutlinedButton(
              onPressed: step.onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.black,
                side: BorderSide(color: AppColors.hairline),
                padding: const EdgeInsets.symmetric(horizontal: AppSizes.md),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: AppShapes.squircle(AppSizes.radiusFull),
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
