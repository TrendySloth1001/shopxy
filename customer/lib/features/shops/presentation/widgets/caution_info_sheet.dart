import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bottom_sheet.dart';
import 'package:shopxy_customer/shared/widgets/app_divider.dart';

/// Explains the caution-deposit section to the customer: what it is and what
/// each action on the screen does. Flat, divider-separated rows — no boxes.
Future<void> showCautionInfoSheet(BuildContext context) {
  return showAppBottomSheet<void>(
    context,
    title: 'About caution deposits',
    builder: (_) => const _CautionInfoBody(),
  );
}

class _CautionInfoBody extends StatelessWidget {
  const _CautionInfoBody();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, 0, AppSizes.lg, AppSizes.md),
            child: Text(
              'A caution deposit is money you place with a shop as security — '
              'held against future purchases or as a guarantee. The shop can '
              'return it, adjust it against an invoice, or forfeit it as per '
              'your agreement.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
          const AppDivider.flush(),
          const _InfoRow(
            icon: Icons.add_rounded,
            color: AppColors.brand,
            title: 'Post a deposit',
            body: 'Enter an amount and how you\'re paying, then send the '
                'shop a request. It joins your held balance once the shop '
                'approves it.',
          ),
          const AppDivider.inset(leading: 48),
          const _InfoRow(
            icon: Icons.close_rounded,
            color: AppColors.error,
            title: 'Cancel',
            body: 'Withdraws a request that is still pending. Approved '
                'deposits can\'t be cancelled here — ask the shop to refund '
                'them.',
          ),
          const AppDivider.flush(),
          // ── How the history reads ──
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.sm),
            child: Text(
              'IN YOUR HISTORY',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const _InfoRow(
            icon: Icons.south_west_rounded,
            color: AppColors.success,
            title: 'Deposit',
            body: 'Money added to your held balance.',
          ),
          const AppDivider.inset(leading: 48),
          const _InfoRow(
            icon: Icons.north_east_rounded,
            color: AppColors.error,
            title: 'Refund',
            body: 'Money the shop returned to you.',
          ),
          const AppDivider.inset(leading: 48),
          const _InfoRow(
            icon: Icons.call_merge_rounded,
            color: AppColors.accentIndigo,
            title: 'Adjusted to invoice',
            body: 'Part of your deposit was applied to one of your invoices.',
          ),
          const AppDivider.inset(leading: 48),
          const _InfoRow(
            icon: Icons.gavel_rounded,
            color: AppColors.error,
            title: 'Forfeited',
            body: 'The shop kept the amount as per your agreement.',
          ),
          const SizedBox(height: AppSizes.lg),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSizes.xs),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: AppColors.muted, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
