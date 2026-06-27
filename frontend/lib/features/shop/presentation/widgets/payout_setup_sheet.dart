import 'package:flutter/material.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_payouts_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// One-time startup nudge that prompts the owner to finish payout onboarding.
///
/// Shown from the dashboard while [LinkedAccountProvider.shouldPrompt] is true.
/// "Set up now" pushes the [ShopPayoutsPage]; "Later" just dismisses (the
/// caller marks it dismissed for the session so it doesn't re-nag).
///
/// Returns true when the owner chose to set up now. [hasDraft] switches the copy
/// to "continue" when there's a saved, half-finished onboarding.
Future<bool> showPayoutSetupSheet(BuildContext context, {bool hasDraft = false}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSizes.radiusLg)),
    ),
    builder: (sheetContext) => _PayoutSetupSheet(hasDraft: hasDraft),
  );
  return result ?? false;
}

class _PayoutSetupSheet extends StatelessWidget {
  const _PayoutSetupSheet({required this.hasDraft});
  final bool hasDraft;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSizes.lg, AppSizes.md, AppSizes.lg, AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: AppSizes.handleHeight,
                decoration: ShapeDecoration(
                  color: AppColors.hairline,
                  shape: AppShapes.squircle(AppSizes.radiusFull),
                ),
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.infoSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.account_balance_outlined,
                  color: AppColors.info, size: AppSizes.iconLg),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              hasDraft ? 'Finish setting up payouts' : 'Set up payouts to get paid',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              hasDraft
                  ? 'You started setting up payouts — pick up right where you '
                      'left off. Your saved details are kept securely on this device.'
                  : 'Add your settlement bank account so your share of each order '
                      'can reach you. Your money is held until the order is '
                      'delivered, then settled to your bank — usually within a few days.',
              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              onPressed: () {
                // Capture the navigator BEFORE pop — once the sheet is popped
                // this widget's context is deactivated, so a fresh
                // Navigator.of(context) lookup would throw.
                final navigator = Navigator.of(context);
                navigator.pop(true);
                navigator.push(
                  MaterialPageRoute(builder: (_) => const ShopPayoutsPage()),
                );
              },
              child: Text(hasDraft ? 'Continue' : 'Set up now'),
            ),
            const SizedBox(height: AppSizes.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Later'),
            ),
          ],
        ),
      ),
    );
  }
}
