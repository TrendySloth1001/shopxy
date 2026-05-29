import 'package:flutter/material.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';

/// Which caution screen the info sheet is explaining.
enum CautionInfoVariant {
  /// The per-party ledger screen (`CautionHistoryPage`).
  history,

  /// The shop-wide pending-requests inbox (`CautionRequestsPage`).
  requests,
}

/// Explains the caution section to the merchant: what it is and what each
/// action does. Flat, divider-separated rows — no boxes.
Future<void> showCautionInfoSheet(
  BuildContext context, {
  required CautionInfoVariant variant,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: AppShapes.squircleTop(AppSizes.bottomSheetRadius),
    builder: (_) => _CautionInfoBody(variant: variant),
  );
}

class _CautionInfoBody extends StatelessWidget {
  const _CautionInfoBody({required this.variant});

  final CautionInfoVariant variant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRequests = variant == CautionInfoVariant.requests;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSizes.md),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.hairline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, 0, AppSizes.lg, AppSizes.md),
            child: Text(
              isRequests ? 'Caution requests' : 'Caution deposits',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSizes.lg, 0, AppSizes.lg, AppSizes.md),
            child: Text(
              isRequests
                  ? 'Customers can ask to place a caution deposit with you. '
                      'Review each request here — approving it adds the amount '
                      'to that party\'s held balance.'
                  : 'A caution deposit is security money a party places with '
                      'you. This screen shows the running balance you hold for '
                      'them and every movement on it.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.muted,
                height: 1.4,
              ),
            ),
          ),
          const AppDivider.flush(),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: isRequests ? _requestRows() : _historyRows(),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
        ],
      ),
    );
  }

  List<Widget> _requestRows() => const [
        _InfoRow(
          icon: Icons.check_rounded,
          color: AppColors.success,
          title: 'Approve',
          body: 'Confirms the deposit and adds it to the party\'s held '
              'balance. Shows up as a Deposit in their ledger.',
        ),
        AppDivider.inset(leading: 48),
        _InfoRow(
          icon: Icons.close_rounded,
          color: AppColors.error,
          title: 'Decline',
          body: 'Rejects the request. You can add an optional reason that the '
              'customer will see.',
        ),
        AppDivider.inset(leading: 48),
        _InfoRow(
          icon: Icons.shopping_basket_outlined,
          color: AppColors.brandStrong,
          title: 'Plans to buy',
          body: 'Items the customer intends to purchase against the deposit, '
              'if they attached a basket.',
        ),
      ];

  List<Widget> _historyRows() => const [
        _InfoRow(
          icon: Icons.south_west_rounded,
          color: AppColors.success,
          title: 'Deposit',
          body: 'Money taken in — increases the balance you hold.',
        ),
        AppDivider.inset(leading: 48),
        _InfoRow(
          icon: Icons.north_east_rounded,
          color: AppColors.error,
          title: 'Refund',
          body: 'Money returned to the party — reduces the held balance.',
        ),
        AppDivider.inset(leading: 48),
        _InfoRow(
          icon: Icons.call_merge_rounded,
          color: AppColors.brand,
          title: 'Set-off',
          body: 'Part of the deposit applied against one of their invoices.',
        ),
        AppDivider.inset(leading: 48),
        _InfoRow(
          icon: Icons.gavel_rounded,
          color: AppColors.error,
          title: 'Forfeited',
          body: 'Amount you kept, e.g. on breach of terms. GST may apply on '
              'forfeiture.',
        ),
      ];
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
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
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
