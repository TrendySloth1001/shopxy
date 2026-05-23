import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';

/// Renders a brand-tinted card on top of the Home page when there are
/// unaccepted invitations. Tapping it pushes the Notifications tab.
///
/// Returns [SizedBox.shrink] when there's nothing pending, so callers
/// can include it unconditionally without a layout gap.
class HomePendingInviteCallout extends StatelessWidget {
  const HomePendingInviteCallout({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = context.watch<NotificationsProvider>();
    final pending = n.pendingIncoming;
    if (pending.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final first = pending.first;
    final shopName = first.fromShopName ?? first.fromUserName ?? 'A shop';
    final extra = pending.length - 1;
    final body = extra > 0
        ? '$shopName and $extra other${extra == 1 ? "" : "s"} are waiting for your reply.'
        : '$shopName wants to add you. Tap to review.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xs,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Material(
        color: AppColors.brandSoft,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: const BorderSide(color: AppColors.brand),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: AppShapes.squircle(AppSizes.radiusLg),
          child: Padding(
            padding: const EdgeInsets.all(AppSizes.lg),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.mark_email_unread_rounded,
                    color: AppColors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have a pending invitation',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppColors.brandStrong,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.brandStrong,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.brandStrong,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
