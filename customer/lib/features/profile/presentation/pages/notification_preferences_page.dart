import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';
import 'package:shopxy_customer/shared/format/friendly_error.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({super.key});

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  bool _saving = false;

  Future<void> _toggle({
    bool? notifyOrders,
    bool? notifyDeals,
    bool? notifyAccount,
    bool? notifyMessages,
    bool? pushEnabled,
    bool? smsEnabled,
  }) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context.read<AuthProvider>().updateNotificationPrefs(
        notifyOrders: notifyOrders,
        notifyDeals: notifyDeals,
        notifyAccount: notifyAccount,
        notifyMessages: notifyMessages,
        pushEnabled: pushEnabled,
        smsEnabled: smsEnabled,
      );
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: friendlyError(e),
        tone: AppSnackbarTone.error,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: 'Notification preferences'),
      body: ListView(
        children: [
          const _SectionHeader(label: 'What we notify you about'),
          _PrefGroup(
            children: [
              _PrefTile(
                title: 'Order updates',
                subtitle: 'Confirmation, dispatch, delivery, returns.',
                icon: AppIcons.localShippingOutlined,
                tint: AppColors.infoSoft,
                iconColor: AppColors.info,
                value: user?.notifyOrders ?? true,
                onChanged: (v) => _toggle(notifyOrders: v),
              ),
              _PrefTile(
                title: 'Deals & price drops',
                subtitle: 'Flash sales, coupons, wishlist deals.',
                icon: AppIcons.localOfferOutlined,
                tint: AppColors.accentAmberSoft,
                iconColor: AppColors.accentAmber,
                value: user?.notifyDeals ?? true,
                onChanged: (v) => _toggle(notifyDeals: v),
              ),
              _PrefTile(
                title: 'Account & security',
                subtitle:
                    'Sign-ins from new devices, password changes, account '
                    'recovery.',
                icon: AppIcons.shieldOutlined,
                tint: AppColors.brandSoft,
                iconColor: AppColors.brandStrong,
                value: user?.notifyAccount ?? true,
                onChanged: (v) => _toggle(notifyAccount: v),
              ),
              _PrefTile(
                title: 'Messages from sellers',
                subtitle:
                    'Shop replies and order-related questions. (Coming with '
                    'the chat surface.)',
                icon: AppIcons.chatBubbleOutline,
                tint: AppColors.accentRoseSoft,
                iconColor: AppColors.accentRose,
                value: user?.notifyMessages ?? true,
                onChanged: (v) => _toggle(notifyMessages: v),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionHeader(label: 'Channels'),
          _PrefGroup(
            children: [
              _PrefTile(
                title: 'Push notifications',
                subtitle:
                    'In-app + lockscreen alerts on this device. Turning '
                    'this off mutes every category above on push.',
                icon: AppIcons.notificationsActiveOutlined,
                tint: AppColors.surfaceTint,
                iconColor: AppColors.black,
                value: user?.pushEnabled ?? true,
                onChanged: (v) => _toggle(pushEnabled: v),
              ),
              _PrefTile(
                title: 'SMS',
                subtitle:
                    'Only for time-sensitive order updates. Carrier rates may '
                    'apply. Off by default.',
                icon: AppIcons.smsOutlined,
                tint: AppColors.surfaceTint,
                iconColor: AppColors.black,
                value: user?.smsEnabled ?? false,
                onChanged: (v) => _toggle(smsEnabled: v),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xl),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.lg,
      AppSizes.lg,
      AppSizes.lg,
      AppSizes.xs,
    ),
    child: Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _PrefGroup extends StatelessWidget {
  const _PrefGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i != 0)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSizes.md),
                child: Divider(height: 1, color: AppColors.hairline),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.tint,
    required this.iconColor,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String subtitle;
  final AppIconData icon;
  final Color tint;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.xs,
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        tileColor: Colors.transparent,
        secondary: Container(
          width: AppSizes.avatarXs,
          height: AppSizes.avatarXs,
          decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: AppIcon(icon, color: iconColor, size: 18),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
        ),
      ),
    );
  }
}
