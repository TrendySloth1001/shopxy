import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/notifications/presentation/pages/notifications_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';

/// AppBar action that opens the notifications inbox and surfaces a
/// small unread badge on the bell glyph.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsProvider, int>((p) => p.unread);
    return IconButton(
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsPage()),
      ),
      icon: SizedBox(
        width: AppSizes.xxxl,
        height: AppSizes.xxxl,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Center(child: Icon(Icons.notifications_none_rounded)),
            if (unread > 0)
              Positioned(
                right: -AppSizes.xs,
                top: -AppSizes.xs,
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
