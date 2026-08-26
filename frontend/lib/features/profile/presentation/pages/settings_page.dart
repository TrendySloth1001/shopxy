import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/config/app_environment.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';
import 'package:shopxy/core/haptics/haptics_prefs.dart';
import 'package:shopxy/core/prefs/locale_prefs.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/logout_confirm_sheet.dart';
import 'package:shopxy/features/custom_fields/presentation/pages/custom_fields_settings_page.dart';
import 'package:shopxy/features/developer/presentation/pages/environment_page.dart';
import 'package:shopxy/features/auth/presentation/pages/sessions_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_settings_page.dart';
import 'package:shopxy/features/profile/presentation/pages/change_password_page.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_operations_page.dart';
import 'package:shopxy/features/profile/presentation/pages/about_page.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

enum SettingsSection { account, appearance, notifications, about }

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.initialSection = SettingsSection.account,
  });

  final SettingsSection initialSection;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _savingEmailNotifications = false;
  bool _exporting = false;

  Future<void> _exportData() async {
    if (_exporting) return;
    final l10n = AppLocalizations.of(context);
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
          text: l10n.profileDataExportShareText,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.profileExportFailed} ${friendlyError(e)}'),
        ),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context);
    final password = await _DeleteAccountDialog.show(context);
    if (password == null || !mounted) return;
    try {
      await context.read<AuthProvider>().deleteAccount(password);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileAccountDeleted)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          duration: AppDurations.snackbarLong,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirmed = await showLogoutConfirmSheet(context);
    if (confirmed == true && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (_savingEmailNotifications) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _savingEmailNotifications = true);
    try {
      await context.read<AuthProvider>().updateProfile(
        emailNotifications: value,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${l10n.profilePreferenceSaveFailed} ${friendlyError(e)}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _savingEmailNotifications = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: FloatingAppBar(title: l10n.profileSettings),
      body: ListView(
        padding: EdgeInsets.only(
          top: FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge,
        ),
        children: [
          _Eyebrow(l10n.profileSectionAccount),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.badgeOutlined,
            title: l10n.profileEditProfile,
            subtitle: user?.name ?? '—',
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ),
          ),
          _SettingRow(
            icon: AppIcons.lockOutlineRounded,
            title: l10n.profileChangePassword,
            subtitle: l10n.profileChangePasswordSubtitle,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _SettingRow(
            icon: AppIcons.shieldOutlined,
            title: l10n.profileDevicesSessions,
            subtitle: l10n.profileDevicesSessionsSubtitle,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SessionsPage()),
            ),
          ),
          _SettingRow(
            icon: AppIcons.alternateEmailRounded,
            title: l10n.profileEmail,
            subtitle: user?.email ?? '—',
          ),

          const _Gap(),

          if ((user?.canView('shop') ?? false) ||
              (user?.canView('payouts') ?? false) ||
              (user?.canView('team') ?? false)) ...[
            _Eyebrow(l10n.profileSectionShopOperations),
            const SizedBox(height: AppSizes.sm),
            _SettingRow(
              icon: AppIcons.tuneRounded,
              title: l10n.profileShopOperations,
              subtitle: l10n.profileShopOperationsSubtitle,
              trailing: AppIcon(
                AppIcons.chevronRightRounded,
                color: AppColors.subtle,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShopOperationsPage()),
              ),
            ),
            const _Gap(),
          ],

          if (user?.canView('invoices') ?? false) ...[
            _Eyebrow(l10n.profileSectionInvoicing),
            const SizedBox(height: AppSizes.sm),
            _SettingRow(
              icon: AppIcons.receiptLongOutlined,
              title: l10n.profileInvoiceSettingsTitle,
              subtitle: l10n.profileInvoiceSettingsSubtitle,
              trailing: AppIcon(
                AppIcons.chevronRightRounded,
                color: AppColors.subtle,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InvoiceSettingsPage()),
              ),
            ),
            const _Gap(),
          ],

          _Eyebrow(l10n.profileSectionAppearance),
          const SizedBox(height: AppSizes.sm),
          const _ThemeRow(),
          _SettingRow(
            icon: AppIcons.currencyRupeeRounded,
            title: l10n.profileCurrency,
            subtitle: l10n.profileCurrencyIndianRupee,
            trailing: _comingSoonChip(context),
          ),
          const _LanguageRow(),
          const _DensityRow(),
          const _HapticsRow(),

          const _Gap(),

          _Eyebrow(l10n.profileSectionInventory),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.tuneRounded,
            title: l10n.profileCustomFields,
            subtitle: l10n.profileCustomFieldsHint,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
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

          _Eyebrow(l10n.profileSectionNotifications),
          const SizedBox(height: AppSizes.sm),
          _SettingToggle(
            icon: AppIcons.notificationsNoneRounded,
            title: l10n.profileEmailNotifications,
            subtitle: l10n.profileEmailNotificationsSubtitle,
            value: user?.emailNotifications ?? true,
            onChanged: _savingEmailNotifications
                ? null
                : _toggleEmailNotifications,
          ),

          const _Gap(),

          _Eyebrow(l10n.profileSectionAbout),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.infoOutlineRounded,
            title: AppStrings.appName,
            subtitle: AppStrings.appBy,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          _SettingRow(
            icon: AppIcons.shieldOutlined,
            title: l10n.profilePrivacyPolicy,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage.privacy()),
            ),
          ),
          _SettingRow(
            icon: AppIcons.descriptionOutlined,
            title: l10n.profileTermsOfService,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LegalPage.terms()),
            ),
          ),

          if (isDeveloperAccount(user?.email)) ...[
            const _Gap(),
            const _Eyebrow('DEVELOPER'),
            const SizedBox(height: AppSizes.sm),
            _SettingRow(
              icon: AppIcons.settingsOutlined,
              title: 'Environment',
              subtitle:
                  AppEnvironments.matching(AppConfig.apiBaseUrl)?.label ??
                  AppConfig.apiBaseUrl,
              trailing: AppIcon(
                AppIcons.chevronRightRounded,
                color: AppColors.subtle,
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EnvironmentPage()),
              ),
            ),
          ],

          const _Gap(),

          _Eyebrow(l10n.profileSectionDangerZone),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.downloadRounded,
            title: l10n.profileExportMyData,
            subtitle: l10n.profileExportMyDataSubtitle,
            trailing: _exporting
                ? const SizedBox(
                    width: AppSizes.xl,
                    height: AppSizes.xl,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : AppIcon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.subtle,
                  ),
            onTap: _exporting ? null : _exportData,
          ),
          _SettingRow(
            icon: AppIcons.deleteForeverRounded,
            title: l10n.profileDeleteAccount,
            subtitle: l10n.profileDeleteAccountSubtitle,
            trailing: AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.error,
            ),
            onTap: _deleteAccount,
          ),

          const _Gap(),

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
                      AppIcon(
                        AppIcons.logoutRounded,
                        color: AppColors.error,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Text(
                          l10n.profileLogout,
                          style: Theme.of(context).textTheme.bodyLarge
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
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 2),
      decoration: ShapeDecoration(
        color: AppColors.heroPanel,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        AppLocalizations.of(context).profileComingSoon,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

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

class _DensityRow extends StatelessWidget {
  const _DensityRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<NavigationPrefsProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              AppIcons.densityMediumRounded,
              size: AppSizes.iconMd,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileListDensity,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  prefs.isCompact
                      ? l10n.profileListDensityCompactDesc
                      : l10n.profileListDensityComfortableDesc,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                SegmentedButton<ListDensity>(
                  segments: [
                    ButtonSegment(
                      value: ListDensity.comfortable,
                      icon: const AppIcon(
                        AppIcons.formatLineSpacingRounded,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(l10n.profileDensityComfortable),
                    ),
                    ButtonSegment(
                      value: ListDensity.compact,
                      icon: const AppIcon(
                        AppIcons.densitySmallRounded,
                        size: AppSizes.iconSm,
                      ),
                      label: Text(l10n.profileDensityCompact),
                    ),
                  ],
                  selected: {prefs.density},
                  showSelectedIcon: false,
                  onSelectionChanged: (set) => prefs.setDensity(set.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(
                      theme.textTheme.labelMedium?.bold,
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

class _HapticsRow extends StatelessWidget {
  const _HapticsRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<HapticsPrefsProvider>();
    final l10n = AppLocalizations.of(context);
    return _SettingToggle(
      icon: AppIcons.vibrationRounded,
      title: l10n.profileHapticFeedback,
      subtitle: l10n.profileHapticFeedbackSubtitle,
      value: prefs.enabled,
      onChanged: (value) {
        prefs.setEnabled(value);
        if (value) AppHaptics.selection();
      },
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<ThemePrefsProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              AppIcons.paletteOutlined,
              size: AppSizes.iconMd,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.theme,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  switch (prefs.mode) {
                    AppThemeMode.light => l10n.themeLightDesc,
                    AppThemeMode.beige => l10n.themeBeigeDesc,
                    AppThemeMode.rose => l10n.themeRoseDesc,
                    AppThemeMode.sage => l10n.themeSageDesc,
                    AppThemeMode.dark => l10n.themeDarkDesc,
                    AppThemeMode.oled => l10n.themeOledDesc,
                    AppThemeMode.midnight => l10n.themeMidnightDesc,
                    AppThemeMode.nord => l10n.themeNordDesc,
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    for (final mode in AppThemeMode.values)
                      ChoiceChip(
                        avatar: Container(
                          decoration: BoxDecoration(
                            color: ThemePrefsProvider.paletteFor(mode).canvas,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.hairline),
                          ),
                        ),
                        label: Text(_themeLabel(l10n, mode)),
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: prefs.mode == mode
                              ? AppColors.onInverse
                              : AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        selected: prefs.mode == mode,
                        onSelected: (_) => prefs.setMode(mode),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _themeLabel(AppLocalizations l10n, AppThemeMode mode) => switch (mode) {
  AppThemeMode.light => l10n.themeLight,
  AppThemeMode.beige => l10n.themeBeige,
  AppThemeMode.rose => l10n.themeRose,
  AppThemeMode.sage => l10n.themeSage,
  AppThemeMode.dark => l10n.themeDark,
  AppThemeMode.oled => l10n.themeOled,
  AppThemeMode.midnight => l10n.themeMidnight,
  AppThemeMode.nord => l10n.themeNord,
};

class _LanguageRow extends StatelessWidget {
  const _LanguageRow();

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<LocalePrefsProvider>();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              AppIcons.languageRounded,
              size: AppSizes.iconMd,
              color: AppColors.black,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.language,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.black,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  l10n.languageSubtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.muted,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    for (final lang in AppLanguage.values)
                      ChoiceChip(
                        label: Text(_languageLabel(lang)),
                        labelStyle: theme.textTheme.labelMedium?.copyWith(
                          color: prefs.language == lang
                              ? AppColors.onInverse
                              : AppColors.black,
                          fontWeight: FontWeight.w600,
                        ),
                        selected: prefs.language == lang,
                        onSelected: (_) => prefs.setLanguage(lang),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _languageLabel(AppLanguage lang) => switch (lang) {
  AppLanguage.english => 'English',
  AppLanguage.hindi => 'हिन्दी',
};

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final AppIconData icon;
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
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(icon, size: AppSizes.iconMd, color: AppColors.black),
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
                  const SizedBox(height: AppSizes.xxs),
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

  final AppIconData icon;
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
              width: AppSizes.xxxl,
              height: AppSizes.xxxl,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: AppIcon(
                icon,
                size: AppSizes.iconMd,
                color: AppColors.black,
              ),
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
                  const SizedBox(height: AppSizes.xxs),
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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.profileDeleteAccount),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.profileDeleteAccountDialogBody,
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: AppSizes.md),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            decoration: InputDecoration(
              labelText: l10n.profileCurrentPassword,
              suffixIcon: IconButton(
                icon: AppIcon(
                  _obscure
                      ? AppIcons.visibilityOutlined
                      : AppIcons.visibilityOffOutlined,
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
          child: Text(l10n.profileCancel),
        ),
        TextButton(
          onPressed: () {
            if (_password.text.isEmpty) return;
            Navigator.pop(context, _password.text);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.error),
          child: Text(l10n.profileDelete),
        ),
      ],
    );
  }
}
