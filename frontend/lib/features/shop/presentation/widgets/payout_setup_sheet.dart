import 'package:flutter/material.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_payouts_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

Future<bool> showPayoutSetupSheet(
  BuildContext context, {
  bool hasDraft = false,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AppSizes.radiusLg),
      ),
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
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.lg,
          AppSizes.md,
          AppSizes.lg,
          AppSizes.lg,
        ),
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
              child: AppIcon(
                AppIcons.accountBalanceOutlined,
                color: AppColors.info,
                size: AppSizes.iconLg,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              hasDraft ? l10n.shopSheetFinishTitle : l10n.shopSheetSetupTitle,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              hasDraft ? l10n.shopSheetFinishBody : l10n.shopSheetSetupBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: AppSizes.xl),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.inverseSurface,
                foregroundColor: AppColors.onInverse,
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              ),
              onPressed: () {
                final navigator = Navigator.of(context);
                navigator.pop(true);
                navigator.push(
                  MaterialPageRoute(builder: (_) => const ShopPayoutsPage()),
                );
              },
              child: Text(hasDraft ? l10n.shopContinue : l10n.shopSetUpNow),
            ),
            const SizedBox(height: AppSizes.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.shopLater),
            ),
          ],
        ),
      ),
    );
  }
}
