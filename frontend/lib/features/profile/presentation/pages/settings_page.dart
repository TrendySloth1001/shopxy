import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/prefs/locale_prefs.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/custom_fields/presentation/pages/custom_fields_settings_page.dart';
import 'package:shopxy/features/profile/presentation/pages/change_password_page.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_operations_page.dart';
import 'package:shopxy/features/profile/presentation/pages/legal_page.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/core/icons/app_icons.dart';

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
          content: Text(
            '${l10n.profileExportFailed} ${friendlyError(e)}',
          ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileAccountDeleted)),
      );
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
    final l10n = AppLocalizations.of(context);
    final confirmed = await AppConfirmDialog.show(
      context,
      title: l10n.profileLogout,
      message: l10n.profileLogoutConfirm,
      confirmLabel: l10n.profileLogout,
      danger: true,
    );
    if (confirmed && mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  Future<void> _toggleEmailNotifications(bool value) async {
    if (_savingEmailNotifications) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _savingEmailNotifications = true);
    try {
      await context.read<AuthProvider>().updateProfile(emailNotifications: value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.profilePreferenceSaveFailed} ${friendlyError(e)}')),
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
          // ── Account ─────────────────────────────────────────
          _Eyebrow(l10n.profileSectionAccount),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.badgeOutlined,
            title: l10n.profileEditProfile,
            subtitle: user?.name ?? '—',
            trailing: Icon(
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
            trailing: Icon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _SettingRow(
            icon: AppIcons.alternateEmailRounded,
            title: l10n.profileEmail,
            subtitle: user?.email ?? '—',
          ),

          const _Gap(),

          // ── Shop operations ─────────────────────────────────
          // Hidden entirely unless the role can view at least one of the
          // areas inside (hours/shop, payouts, or team).
          if ((user?.canView('shop') ?? false) ||
              (user?.canView('payouts') ?? false) ||
              (user?.canView('team') ?? false)) ...[
            _Eyebrow(l10n.profileSectionShopOperations),
            const SizedBox(height: AppSizes.sm),
            _SettingRow(
              icon: AppIcons.tuneRounded,
              title: l10n.profileShopOperations,
              subtitle: l10n.profileShopOperationsSubtitle,
              trailing: Icon(
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

          // ── Appearance ──────────────────────────────────────
          _Eyebrow(l10n.profileSectionAppearance),
          const SizedBox(height: AppSizes.sm),
          const _ThemeRow(),
          // Currency stays a placeholder row — no `onTap` so it doesn't pretend
          // to be live; the "Coming soon" chip signals the future surface.
          _SettingRow(
            icon: AppIcons.currencyRupeeRounded,
            title: l10n.profileCurrency,
            subtitle: l10n.profileCurrencyIndianRupee,
            trailing: _comingSoonChip(context),
          ),
          // Language is live (multilingual pilot): English + हिन्दी.
          const _LanguageRow(),
          const _DensityRow(),

          const _Gap(),

          // ── Inventory ───────────────────────────────────────
          _Eyebrow(l10n.profileSectionInventory),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.tuneRounded,
            title: l10n.profileCustomFields,
            subtitle: l10n.profileCustomFieldsHint,
            trailing: Icon(
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

          // ── Notifications ───────────────────────────────────
          _Eyebrow(l10n.profileSectionNotifications),
          const SizedBox(height: AppSizes.sm),
          _SettingToggle(
            icon: AppIcons.notificationsNoneRounded,
            title: l10n.profileEmailNotifications,
            subtitle: l10n.profileEmailNotificationsSubtitle,
            value: user?.emailNotifications ?? true,
            onChanged: _savingEmailNotifications ? null : _toggleEmailNotifications,
          ),

          const _Gap(),

          // ── About ───────────────────────────────────────────
          _Eyebrow(l10n.profileSectionAbout),
          const SizedBox(height: AppSizes.sm),
          _SettingRow(
            icon: AppIcons.infoOutlineRounded,
            title: l10n.profileAppVersion,
            subtitle: '1.0.0',
          ),
          _SettingRow(
            icon: AppIcons.shieldOutlined,
            title: l10n.profilePrivacyPolicy,
            trailing: Icon(
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
            trailing: Icon(
              AppIcons.chevronRightRounded,
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
                : Icon(
                    AppIcons.chevronRightRounded,
                    color: AppColors.subtle,
                  ),
            onTap: _exporting ? null : _exportData,
          ),
          _SettingRow(
            icon: AppIcons.deleteForeverRounded,
            title: l10n.profileDeleteAccount,
            subtitle: l10n.profileDeleteAccountSubtitle,
            trailing: Icon(
              AppIcons.chevronRightRounded,
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
                      Icon(
                        AppIcons.logoutRounded,
                        color: AppColors.error,
                        size: AppSizes.iconMd,
                      ),
                      const SizedBox(width: AppSizes.md),
                      Expanded(
                        child: Text(
                          l10n.profileLogout,
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
            child: Icon(
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
                const SizedBox(height: 2),
                Text(
                  prefs.isCompact
                      ? l10n.profileListDensityCompactDesc
                      : l10n.profileListDensityComfortableDesc,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.sm),
                SegmentedButton<ListDensity>(
                  segments: [
                    ButtonSegment(
                      value: ListDensity.comfortable,
                      icon: const Icon(AppIcons.formatLineSpacingRounded,
                          size: AppSizes.iconSm),
                      label: Text(l10n.profileDensityComfortable),
                    ),
                    ButtonSegment(
                      value: ListDensity.compact,
                      icon: const Icon(AppIcons.densitySmallRounded, size: AppSizes.iconSm),
                      label: Text(l10n.profileDensityCompact),
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

/// Three-way picker for [AppThemeMode] — Light, Dark and OLED. Mirrors the
/// web app's theme picker. Writes through [ThemePrefsProvider], which swaps the
/// active palette, persists the choice and rebuilds the whole app live so the
/// theme flips without leaving Settings.
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
            child: Icon(
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
                const SizedBox(height: 2),
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
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: AppSizes.sm),
                // A wrapping chip set (not a SegmentedButton) so the eight
                // themes stay usable on a phone — they flow onto multiple rows
                // instead of squeezing into one. Each chip previews the theme's
                // canvas colour as a swatch dot.
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
                        // Explicit label colour so the chip stays readable in
                        // both states (ChoiceChip otherwise renders unselected
                        // labels from the inverse foreground — invisible here).
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

/// Display label for a theme mode, shown on its picker chip (localized).
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

/// Picker for the UI language — the multilingual pilot (English + हिन्दी).
/// Mirrors [_ThemeRow]: writes through [LocalePrefsProvider], which persists the
/// choice, swaps the Devanagari font and rebuilds the whole app live. Language
/// names are shown as endonyms (each in its own script), the convention for
/// language pickers, so they read the same regardless of the active locale.
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
            child: Icon(
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
                const SizedBox(height: 2),
                Text(
                  l10n.languageSubtitle,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
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

/// Endonym for a language — its own self-name, shown in its own script.
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
            width: AppSizes.xxxl,
            height: AppSizes.xxxl,
            decoration: ShapeDecoration(
              color: AppColors.heroPanel,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: AppSizes.iconMd, color: AppColors.black),
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
              width: AppSizes.xxxl,
              height: AppSizes.xxxl,
              decoration: ShapeDecoration(
                color: AppColors.heroPanel,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: AppSizes.iconMd, color: AppColors.black),
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
                icon: Icon(
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
