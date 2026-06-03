import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/pages/custom_fields_settings_page.dart';
import 'package:shopxy/features/profile/presentation/pages/change_password_page.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_operations_page.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
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
  bool _savingEmailNotifications = false;
  bool _exporting = false;

  Future<void> _exportData() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await context.read<AuthProvider>().exportData();
      final dir = await getTemporaryDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${dir.path}/shopxy-data-$ts.json');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'Your ShopXY data export',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Export failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteAccount() async {
    final password = await _DeleteAccountDialog.show(context);
    if (password == null || !mounted) return;
    try {
      await context.read<AuthProvider>().deleteAccount(password);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

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

  Future<void> _toggleEmailNotifications(bool value) async {
    if (_savingEmailNotifications) return;
    setState(() => _savingEmailNotifications = true);
    try {
      await context.read<AuthProvider>().updateProfile(emailNotifications: value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preference: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _savingEmailNotifications = false);
    }
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
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ),
          ),
          _SettingRow(
            icon: Icons.lock_outline_rounded,
            title: AppStrings.changePassword,
            subtitle: 'Update the password on your account',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _SettingRow(
            icon: Icons.alternate_email_rounded,
            title: AppStrings.email,
            subtitle: user?.email ?? '—',
          ),

          const _Gap(),

          // ── Shop operations ─────────────────────────────────
          // Hidden entirely unless the role can view at least one of the
          // areas inside (hours/shop, payouts, or team).
          if ((user?.canView('shop') ?? false) ||
              (user?.canView('payouts') ?? false) ||
              (user?.canView('team') ?? false)) ...[
            const _Eyebrow('SHOP OPERATIONS'),
            const SizedBox(height: AppSizes.sm),
            _SettingRow(
              icon: Icons.tune_rounded,
              title: 'Shop operations',
              subtitle: 'Hours, vacation mode, payouts, KYC, team',
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.subtle,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopOperationsPage()),
              ),
            ),
            const _Gap(),
          ],

          // ── Appearance ──────────────────────────────────────
          const _Eyebrow('APPEARANCE'),
          const SizedBox(height: AppSizes.sm),
          // Theme / language are placeholder rows — no `onTap` so
          // they don't pretend to be live. The "Coming soon" chip
          // signals the future surface without inviting taps that
          // do nothing.
          _SettingRow(
            icon: Icons.palette_outlined,
            title: AppStrings.theme,
            subtitle: AppStrings.themeLight,
            trailing: _comingSoonChip(context),
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
          ),
          const _NavigationStyleRow(),
          const _DensityRow(),

          const _Gap(),

          // ── Inventory ───────────────────────────────────────
          const _Eyebrow('INVENTORY'),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: Icons.tune_rounded,
            title: AppStrings.customFields,
            subtitle: AppStrings.customFieldsHint,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const CustomFieldsSettingsPage(),
              ),
            ),
          ),

          const _Gap(),

          // ── Notifications ───────────────────────────────────
          const _Eyebrow('NOTIFICATIONS'),
          const SizedBox(height: AppSizes.sm),
          _SettingToggle(
            icon: Icons.notifications_none_rounded,
            title: 'Email notifications',
            subtitle: 'Low-stock alerts and weekly summary',
            value: user?.emailNotifications ?? true,
            onChanged: _savingEmailNotifications ? null : _toggleEmailNotifications,
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
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage.privacy()),
            ),
          ),
          _SettingRow(
            icon: Icons.description_outlined,
            title: AppStrings.termsOfService,
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage.terms()),
            ),
          ),

          const _Gap(),

          // ── Danger zone ─────────────────────────────────────
          // DPDP §11/§12 affordances. Kept above the logout row so the
          // destructive actions live together at the bottom of the page.
          const _Eyebrow('DANGER ZONE'),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: Icons.download_rounded,
            title: 'Export my data',
            subtitle:
                'Download a JSON copy of every record tied to your account.',
            trailing: _exporting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.subtle,
                  ),
            onTap: _exporting ? null : _exportData,
          ),
          _SettingRow(
            icon: Icons.delete_forever_rounded,
            title: 'Delete account',
            subtitle:
                'Permanently erase your account. Shop owners with invoices '
                'in the past 8 years must contact support (Companies Act / GST '
                'retention).',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.error,
            ),
            onTap: _deleteAccount,
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

/// Two-way picker for [ListDensity]. Drives list-row padding on the
/// products page (and any future inventory-heavy list) so the user
/// can opt into a compact mode that fits more rows per screen.
class _DensityRow extends StatelessWidget {
  const _DensityRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.density_medium_rounded,
              size: 18,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'List density',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prefs.isCompact
                      ? 'Tighter rows — more products per screen.'
                      : 'Comfortable spacing (default).',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.sm),
                SegmentedButton<ListDensity>(
                  segments: const [
                    ButtonSegment(
                      value: ListDensity.comfortable,
                      icon: Icon(Icons.format_line_spacing_rounded, size: 16),
                      label: Text('Comfortable'),
                    ),
                    ButtonSegment(
                      value: ListDensity.compact,
                      icon: Icon(Icons.density_small_rounded, size: 16),
                      label: Text('Compact'),
                    ),
                  ],
                  selected: {prefs.density},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) => prefs.setDensity(set.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Two-way picker for [NavigationStyle]. Tapping a segment writes
/// through the [NavigationPrefsProvider] which persists the choice and
/// rebuilds [AppShell] live — so the user sees the layout swap without
/// leaving Settings.
class _NavigationStyleRow extends StatelessWidget {
  const _NavigationStyleRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.dashboard_customize_outlined,
              size: 18,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Navigation style',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prefs.isSidebar
                      ? 'Left-side rail with destinations stacked vertically.'
                      : 'Bottom tab bar (default).',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.sm),
                SegmentedButton<NavigationStyle>(
                  segments: const [
                    ButtonSegment(
                      value: NavigationStyle.bottomBar,
                      icon: Icon(Icons.dock_rounded, size: 16),
                      label: Text('Bottom bar'),
                    ),
                    ButtonSegment(
                      value: NavigationStyle.sidebar,
                      icon: Icon(Icons.view_sidebar_outlined, size: 16),
                      label: Text('Sidebar'),
                    ),
                  ],
                  selected: {prefs.style},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) => prefs.setStyle(set.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onChanged == null ? null : () => onChanged!(!value),
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

/// Password-gated confirmation for DPDP §12 erasure. Returns the
/// entered password on confirm and `null` on cancel — the caller then
/// invokes [AuthProvider.deleteAccount] and routes the user out.
class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      builder: (_) => const _DeleteAccountDialog(),
    );
  }

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Delete account'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This permanently erases your account and revokes every '
            'session. Owners whose invoices are still inside the 8-year '
            'Companies Act / GST retention window cannot delete in-app — '
            'contact support@shopxy.example for a controlled wipe.',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Current password',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_password.text.isEmpty) return;
            Navigator.pop(context, _password.text);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
