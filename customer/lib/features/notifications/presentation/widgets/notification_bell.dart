import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  Future<void> _open(BuildContext context) async {
    final signedIn = await requireAuth(
      context,
      reason: 'Sign in to see your orders, invitations and shop updates.',
    );
    if (!signedIn || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsProvider, int>((p) => p.unread);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => _open(context),
      icon: SizedBox(
        width: AppSizes.xxl,
        height: AppSizes.xxl,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(child: AppIcon(AppIcons.notificationsNoneRounded)),
            if (unread > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: AppSizes.iconSm,
                    minHeight: AppSizes.iconSm,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: AppSizes.xs),
                  decoration: const BoxDecoration(
                    color: AppColors.error,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    unread > 99 ? '99+' : '$unread',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
