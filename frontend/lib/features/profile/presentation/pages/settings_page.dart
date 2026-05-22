import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';

enum SettingsSection { account, appearance, notifications, about }

/// Settings — flat, sectioned, no boxed cards. Pass [initialSection] to
/// open the page focused on a particular cluster (used by the Profile
/// page's "About" deep-link).
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, this.initialSection = SettingsSection.account});

  final SettingsSection initialSection;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _emailNotifications = true;

  Future<void> _logout() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.logout,
      message: AppStrings.logoutConfirm,
      confirmLabel: AppStrings.logout,
      danger: true,
    );
    if (confirmed && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  void _stub(String label) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('$label — ${AppStrings.comingSoon.toLowerCase()}')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.huge),
        children: [
          // ── Account ─────────────────────────────────────────
          const _Eyebrow('ACCOUNT'),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: Icons.badge_outlined,
            title: AppStrings.editProfile,
            subtitle: user?.name ?? '—',
            trailing: _comingSoonChip(context),
            onTap: () => _stub(AppStrings.editProfile),
          ),
          _SettingRow(
            icon: Icons.lock_outline_rounded,
            title: AppStrings.changePassword,
            subtitle: 'Update the password on your account',
            trailing: _comingSoonChip(context),
            onTap: () => _stub(AppStrings.changePassword),
          ),
          _SettingRow(
            icon: Icons.alternate_email_rounded,
            title: AppStrings.email,
            subtitle: user?.email ?? '—',
          ),

          const _Gap(),

          // ── Appearance ──────────────────────────────────────
          const _Eyebrow('APPEARANCE'),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: Icons.palette_outlined,
            title: AppStrings.theme,
            subtitle: AppStrings.themeLight,
            trailing: _comingSoonChip(context),
            onTap: () => _stub(AppStrings.theme),
          ),
          _SettingRow(
            icon: Icons.currency_rupee_rounded,
            title: AppStrings.currency,
            subtitle: 'Indian Rupee (₹)',
          ),
          _SettingRow(
            icon: Icons.language_rounded,
            title: AppStrings.language,
            subtitle: 'English',
            trailing: _comingSoonChip(context),
            onTap: () => _stub(AppStrings.language),
          ),

          const _Gap(),

          // ── Notifications ───────────────────────────────────
          const _Eyebrow('NOTIFICATIONS'),
          const SizedBox(height: AppSizes.sm),
          _SettingToggle(
            icon: Icons.notifications_none_rounded,
            title: 'Email notifications',
            subtitle: 'Low-stock alerts and weekly summary',
            value: _emailNotifications,
            onChanged: (v) => setState(() => _emailNotifications = v),
          ),

          const _Gap(),

          // ── About ───────────────────────────────────────────
          const _Eyebrow('ABOUT'),
          const SizedBox(height: AppSizes.sm),
          const _SettingRow(
            icon: Icons.info_outline_rounded,
            title: AppStrings.appVersion,
            subtitle: '1.0.0',
          ),
          _SettingRow(
            icon: Icons.shield_outlined,
            title: AppStrings.privacyPolicy,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
            onTap: () => _stub(AppStrings.privacyPolicy),
          ),
          _SettingRow(
            icon: Icons.description_outlined,
            title: AppStrings.termsOfService,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
            onTap: () => _stub(AppStrings.termsOfService),
          ),

          const _Gap(),

          // ── Log out ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.sm,
            ),
            child: Material(
              color: AppColors.errorSoft,
              shape: AppShapes.squircle(AppSizes.radiusMd),
              child: InkWell(
                onTap: _logout,
                customBorder: AppShapes.squircle(AppSizes.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Text(
                          AppStrings.logout,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comingSoonChip(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 2,
      ),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        AppStrings.comingSoon,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Layout primitives
// ─────────────────────────────────────────────────────────────────────

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.xl,
      ),
      child: Container(height: 1, color: AppColors.hairline),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: AppColors.black),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSizes.sm),
            trailing!,
          ],
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _SettingToggle extends StatelessWidget {
  const _SettingToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: AppColors.black),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Switch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}
