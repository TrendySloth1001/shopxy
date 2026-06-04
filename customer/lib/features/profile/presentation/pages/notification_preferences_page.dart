import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_snackbar.dart';

/// Per-category notification preferences. Each row toggles a
/// `notify*` flag on the user row; the channel rows at the bottom
/// mute push / SMS entirely regardless of the category flags. The
/// save call is per-toggle (no global "save" button) so the UI feels
/// instant on a flaky network — failures pop a toast and revert.
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
        message: e.toString().replaceFirst('Exception: ', ''),
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
          _PrefTile(
            title: 'Order updates',
            subtitle: 'Confirmation, dispatch, delivery, returns.',
            icon: Icons.local_shipping_outlined,
            tint: AppColors.infoSoft,
            iconColor: AppColors.info,
            value: user?.notifyOrders ?? true,
            onChanged: (v) => _toggle(notifyOrders: v),
          ),
          _PrefTile(
            title: 'Deals & price drops',
            subtitle: 'Flash sales, coupons, wishlist deals.',
            icon: Icons.local_offer_outlined,
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
            icon: Icons.shield_outlined,
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
            icon: Icons.chat_bubble_outline,
            tint: AppColors.accentRoseSoft,
            iconColor: AppColors.accentRose,
            value: user?.notifyMessages ?? true,
            onChanged: (v) => _toggle(notifyMessages: v),
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionHeader(label: 'Channels'),
          _PrefTile(
            title: 'Push notifications',
            subtitle:
                'In-app + lockscreen alerts on this device. Turning '
                'this off mutes every category above on push.',
            icon: Icons.notifications_active_outlined,
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
            icon: Icons.sms_outlined,
            tint: AppColors.surfaceTint,
            iconColor: AppColors.black,
            value: user?.smsEnabled ?? false,
            onChanged: (v) => _toggle(smsEnabled: v),
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
  final IconData icon;
  final Color tint;
  final Color iconColor;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.xs),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
        secondary: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: tint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: iconColor, size: 18),
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
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
      ),
    );
  }
}
