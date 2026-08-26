import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/logout_confirm_sheet.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_settings_page.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy/features/profile/presentation/pages/settings_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shadows.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/theme/app_text_styles.dart';

const _kInvoiceSettingsFields = {
  ProfileField.shopGstin,
  ProfileField.shopPan,
  ProfileField.upiVpa,
};

String _formatGstEffectiveFrom(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed != null ? DateFormat('d MMM y').format(parsed) : value;
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.profileNavProfile,
        actions: [
          IconButton(
            tooltip: l10n.profileSettings,
            icon: const AppIcon(AppIcons.settingsOutlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
          top: FloatingAppBar.contentTopInset(context),
          bottom: AppSizes.huge,
        ),
        children: [
          _ProfileHero(user: user),
          if (user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: _ProfileCompletion(
                user: user,
                onComplete: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
              ),
            ),
          if (user != null && user.isShopOwner && _shopProfileIncomplete(user))
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSizes.lg,
                AppSizes.md,
                AppSizes.lg,
                0,
              ),
              child: _ShopSetupCallout(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
              ),
            ),
          const SizedBox(height: AppSizes.xl),
          if (user != null) ...[
            _personalSection(context, user),
            const SizedBox(height: AppSizes.xl),
            _shopSection(context, user),
            const SizedBox(height: AppSizes.xl),
            _invoiceSettingsSection(context, user),
            const SizedBox(height: AppSizes.xl),
            _LogoutTile(onTap: () => _confirmAndLogout(context)),
          ],
          const SizedBox(height: AppSizes.huge),
          Center(
            child: Text(
              '${AppStrings.appName} · ${l10n.profileAppTagline}',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
        ],
      ),
    );
  }

  static bool _shopProfileIncomplete(AuthUser u) {
    bool blank(String? v) => v == null || v.trim().isEmpty;
    return blank(u.shopName) && blank(u.shopStateCode) && blank(u.shopGstin);
  }

  static Widget _personalSection(BuildContext context, AuthUser user) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accentIndigo;
    final accentSoft = AppColors.accentIndigoSoft;
    return _DetailSection(
      icon: AppIcons.personOutline,
      title: l10n.profilePersonalDetails,
      rows: [
        _DetailRow(
          icon: AppIcons.badgeOutlined,
          label: l10n.profileFieldName,
          value: user.name,
          accent: accent,
          accentSoft: accentSoft,
        ),
        _DetailRow(
          icon: AppIcons.alternateEmail,
          label: l10n.profileEmail,
          value: user.email,
          accent: accent,
          accentSoft: accentSoft,
          copyable: true,
        ),
        _DetailRow(
          icon: AppIcons.callOutlined,
          label: l10n.profileFieldPhone,
          value: user.phoneNumber,
          accent: accent,
          accentSoft: accentSoft,
          copyable: true,
        ),
      ],
    );
  }

  static Widget _shopSection(BuildContext context, AuthUser user) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.brandStrong;
    final accentSoft = AppColors.brandSoft;
    return _DetailSection(
      icon: AppIcons.storefrontOutlined,
      title: l10n.profileShopDetails,
      rows: [
        _DetailRow(
          icon: AppIcons.storefrontOutlined,
          label: l10n.profileFieldShopName,
          value: user.shopName,
          accent: accent,
          accentSoft: accentSoft,
        ),
        _DetailRow(
          icon: AppIcons.locationOnOutlined,
          label: l10n.profileFieldAddress,
          value: user.shopAddress,
          accent: accent,
          accentSoft: accentSoft,
        ),
        _DetailRow(
          icon: AppIcons.locationCityOutlined,
          label: l10n.profileFieldCity,
          value: user.shopCity,
          accent: accent,
          accentSoft: accentSoft,
        ),
        _DetailRow(
          icon: AppIcons.mapOutlined,
          label: l10n.profileFieldState,
          value: _composeState(user),
          accent: accent,
          accentSoft: accentSoft,
        ),
        _DetailRow(
          icon: AppIcons.markunreadMailboxOutlined,
          label: l10n.profileFieldPinCode,
          value: user.shopPinCode,
          accent: accent,
          accentSoft: accentSoft,
        ),
      ],
    );
  }

  static Widget _invoiceSettingsSection(BuildContext context, AuthUser user) {
    final l10n = AppLocalizations.of(context);
    final accent = AppColors.accentAmber;
    final accentSoft = AppColors.accentAmberSoft;
    return _DetailSection(
      icon: AppIcons.receiptLongOutlined,
      title: l10n.profileInvoiceSettingsTitle,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InvoiceSettingsPage()),
      ),
      rows: [
        _DetailRow(
          icon: AppIcons.receiptLongOutlined,
          label: l10n.profileFieldGstin,
          value: user.shopGstin,
          accent: accent,
          accentSoft: accentSoft,
          copyable: true,
        ),
        if (user.gstEffectiveFrom != null)
          _DetailRow(
            icon: AppIcons.calendarTodayOutlined,
            label: l10n.profileGstEffectiveFrom,
            value: _formatGstEffectiveFrom(user.gstEffectiveFrom!),
            accent: accent,
            accentSoft: accentSoft,
          ),
        _DetailRow(
          icon: AppIcons.creditCardOutlined,
          label: l10n.profileFieldPan,
          value: user.shopPan,
          accent: accent,
          accentSoft: accentSoft,
          copyable: true,
        ),
        _DetailRow(
          icon: AppIcons.accountBalanceWalletOutlined,
          label: l10n.profileFieldUpiId,
          value: user.upiVpa,
          accent: accent,
          accentSoft: accentSoft,
          copyable: true,
        ),
      ],
    );
  }

  static String? _composeState(AuthUser u) {
    final code = u.shopStateCode?.trim();
    final name = u.shopState?.trim();
    final hasCode = code != null && code.isNotEmpty;
    final hasName = name != null && name.isNotEmpty;
    if (hasCode && hasName) return '$code — $name';
    if (hasName) return name;
    if (hasCode) return code;
    return null;
  }

  static Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showLogoutConfirmSheet(context);
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = user?.name ?? '—';
    final email = user?.email ?? '';
    final shopRole = user?.shopRole;
    final memberSince = user?.createdAt;
    final shopName = user?.shopName;
    final avatarUrl = user?.avatarUrl;
    final bgImage = (avatarUrl == null || avatarUrl.isEmpty)
        ? null
        : resolveImageUrl(avatarUrl);
    final isDark = theme.brightness == Brightness.dark;
    final tint = bgImage == null ? 1.0 : (isDark ? 0.55 : 0.3);

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(AppSizes.radiusLg),
        shadows: AppShadows.floating,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (bgImage != null)
            Positioned.fill(
              child: Transform.scale(
                scale: 1.4,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: 14,
                    sigmaY: 14,
                    tileMode: TileMode.decal,
                  ),
                  child: Image.network(
                    bgImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.brandSoft.withValues(alpha: tint),
                    AppColors.heroPanel.withValues(
                      alpha: (tint + 0.15).clamp(0.0, 1.0),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.xl,
              AppSizes.lg,
              AppSizes.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.xs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surface,
                        boxShadow: AppShadows.floating,
                      ),
                      child: ProfileAvatar(
                        name: name,
                        imageUrl: user?.avatarUrl,
                        size: 76,
                      ),
                    ),
                    const SizedBox(width: AppSizes.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleLarge?.extraBold,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (shopName != null &&
                              shopName.trim().isNotEmpty) ...[
                            const SizedBox(height: AppSizes.xxs),
                            Text(
                              shopName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: AppColors.brandStrong,
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: AppSizes.xs),
                          Text(
                            email,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSizes.sm),
                          Wrap(
                            spacing: AppSizes.xs,
                            runSpacing: AppSizes.xs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _RoleChip(shopRole: shopRole),
                              if (memberSince != null)
                                _MetaChip(
                                  icon: AppIcons.calendarTodayOutlined,
                                  label:
                                      '${l10n.profileMemberSince} ${MaterialLocalizations.of(context).formatMonthYear(memberSince)}',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    ),
                    icon: const AppIcon(
                      AppIcons.editOutlined,
                      size: AppSizes.iconSm,
                    ),
                    label: Text(l10n.profileEditProfile),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.brandStrong,
                      backgroundColor: AppColors.surface,
                      side: BorderSide(color: AppColors.hairline),
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSizes.md,
                        horizontal: AppSizes.lg,
                      ),
                      textStyle: theme.textTheme.labelLarge?.bold,
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

class _ShopSetupCallout extends StatelessWidget {
  const _ShopSetupCallout({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Material(
      color: AppColors.tileBg(AppColors.accentAmberSoft),
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Row(
            children: [
              Container(
                width: AppSizes.xxxl,
                height: AppSizes.xxxl,
                decoration: ShapeDecoration(
                  color: AppColors.surface,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: AppIcon(
                  AppIcons.storefrontRounded,
                  size: AppSizes.iconMd,
                  color: AppColors.accentAmber,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileFinishShopSetup,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      l10n.profileFinishShopSetupBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              AppIcon(
                AppIcons.chevronRightRounded,
                color: AppColors.accentAmber,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCompletion extends StatelessWidget {
  const _ProfileCompletion({required this.user, required this.onComplete});

  final AuthUser user;
  final VoidCallback onComplete;

  static List<({String label, bool filled, ProfileField target})> _fields(
    AuthUser u,
    AppLocalizations l10n,
  ) {
    bool ok(String? v) => v != null && v.trim().isNotEmpty;
    return [
      (
        label: l10n.profileFieldName,
        filled: ok(u.name),
        target: ProfileField.name,
      ),
      (
        label: l10n.profileFieldPhoto,
        filled: ok(u.avatarUrl),
        target: ProfileField.photo,
      ),
      (
        label: l10n.profileFieldPhone,
        filled: ok(u.phoneNumber),
        target: ProfileField.phone,
      ),
      (
        label: l10n.profileFieldShopName,
        filled: ok(u.shopName),
        target: ProfileField.shopName,
      ),
      (
        label: l10n.profileFieldAddress,
        filled: ok(u.shopAddress),
        target: ProfileField.shopAddress,
      ),
      (
        label: l10n.profileFieldCity,
        filled: ok(u.shopCity),
        target: ProfileField.shopCity,
      ),
      (
        label: l10n.profileFieldState,
        filled: ok(u.shopState),
        target: ProfileField.shopState,
      ),
      (
        label: l10n.profileFieldStateCode,
        filled: ok(u.shopStateCode),
        target: ProfileField.shopState,
      ),
      (
        label: l10n.profileFieldPinCode,
        filled: ok(u.shopPinCode),
        target: ProfileField.shopPinCode,
      ),
      (
        label: l10n.profileFieldGstin,
        filled: ok(u.shopGstin),
        target: ProfileField.shopGstin,
      ),
      (
        label: l10n.profileFieldPan,
        filled: ok(u.shopPan),
        target: ProfileField.shopPan,
      ),
      (
        label: l10n.profileFieldUpiId,
        filled: ok(u.upiVpa),
        target: ProfileField.upiVpa,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final fields = _fields(user, l10n);
    final total = fields.length;
    final filled = fields.where((f) => f.filled).length;
    final percent = ((filled / total) * 100).round();
    final missing = fields.where((f) => !f.filled).toList();

    if (percent >= 100) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusLg,
          side: BorderSide(color: AppColors.hairline),
        ),
        shadows: AppShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.profileCompletionTitle} $percent%',
                      style: theme.textTheme.titleSmall?.bold,
                    ),
                    const SizedBox(height: AppSizes.xxs),
                    Text(
                      '$filled / $total ${l10n.profileCompletionDetailsAdded}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onComplete,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.brandStrong,
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(l10n.profileCompleteIt),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSizes.radiusFull),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: AppColors.surfaceTint,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: AppSizes.md),
            Text(
              l10n.profileWhatsLeft,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                for (final m in missing)
                  Material(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _kInvoiceSettingsFields.contains(m.target)
                              ? InvoiceSettingsPage(focusField: m.target)
                              : EditProfilePage(focusField: m.target),
                        ),
                      ),
                      customBorder: AppShapes.squircle(AppSizes.radiusFull),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.sm,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AppIcon(
                              AppIcons.addRounded,
                              size: AppSizes.iconSm,
                              color: AppColors.brandStrong,
                            ),
                            const SizedBox(width: AppSizes.xxs),
                            Text(
                              m.label,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.brandStrong,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

const double _kDetailRowIndent = AppSizes.lg + _kDetailIconSize + AppSizes.md;
const double _kDetailIconSize = 36;

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.rows,
    this.onTap,
  });
  final AppIconData icon;
  final String title;
  final List<Widget> rows;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) {
        children.add(
          const Divider(
            height: 1,
            indent: _kDetailRowIndent,
            endIndent: AppSizes.lg,
          ),
        );
      }
      children.add(rows[i]);
    }
    final shape = AppShapes.squircle(
      AppSizes.radiusLg,
      side: BorderSide(color: AppColors.hairline),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
          child: Row(
            children: [
              AppIcon(icon, size: AppSizes.iconSm, color: AppColors.muted),
              const SizedBox(width: AppSizes.sm),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (onTap != null)
                AppIcon(
                  AppIcons.chevronRightRounded,
                  size: AppSizes.iconSm,
                  color: AppColors.subtle,
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.sm),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: AppColors.surface,
            shape: shape,
            shadows: AppShadows.floating,
          ),
          child: onTap == null
              ? Column(children: children)
              : InkWell(
                  onTap: onTap,
                  child: Column(children: children),
                ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.accentSoft,
    this.copyable = false,
  });

  final AppIconData icon;
  final String label;
  final String? value;
  final Color accent;
  final Color accentSoft;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final text = value?.trim() ?? '';
    final hasValue = text.isNotEmpty;
    final canCopy = copyable && hasValue;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          Container(
            width: _kDetailIconSize,
            height: _kDetailIconSize,
            decoration: ShapeDecoration(
              color: hasValue ? accentSoft : AppColors.surfaceTint,
              shape: AppShapes.squircle(AppSizes.radiusSm),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              icon,
              size: AppSizes.iconMd,
              color: hasValue ? accent : AppColors.subtle,
            ),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSizes.xxs),
                Text(
                  hasValue ? text : l10n.profileNotAdded,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: hasValue ? AppColors.black : AppColors.subtle,
                    fontWeight: hasValue ? FontWeight.w600 : FontWeight.w400,
                    fontStyle: hasValue ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          if (canCopy) ...[
            const SizedBox(width: AppSizes.sm),
            AppIcon(
              AppIcons.copyRounded,
              size: AppSizes.iconSm,
              color: AppColors.subtle,
            ),
          ],
        ],
      ),
    );

    if (!canCopy) return content;
    return InkWell(
      onTap: () {
        Clipboard.setData(ClipboardData(text: text));
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(l10n.profileCopied),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
      },
      child: content,
    );
  }
}

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final shape = AppShapes.squircle(
      AppSizes.radiusLg,
      side: BorderSide(color: AppColors.hairline),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      child: Material(
        color: AppColors.surface,
        shape: shape,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md + 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(
                  AppIcons.logoutRounded,
                  color: AppColors.error,
                  size: AppSizes.iconMd,
                ),
                const SizedBox(width: AppSizes.sm),
                Text(
                  l10n.profileLogout,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({this.shopRole});
  final String? shopRole;

  static String _label(AppLocalizations l10n, String? role) {
    switch (role) {
      case 'OWNER':
        return l10n.profileRoleOwner;
      case 'MANAGER':
        return l10n.profileRoleManager;
      case 'STOCKIST':
        return l10n.profileRoleStockist;
      case 'CASHIER':
        return l10n.profileRoleCashier;
      default:
        return l10n.profileRoleStaff;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isOwner = shopRole == 'OWNER';
    final label = _label(l10n, shopRole);
    final bg = isOwner ? AppColors.brandSoft : AppColors.accentIndigoSoft;
    final fg = isOwner ? AppColors.brandStrong : AppColors.accentIndigo;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 3),
      decoration: ShapeDecoration(
        color: bg,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final AppIconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: 3),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSizes.iconSm, color: AppColors.muted),
          const SizedBox(width: AppSizes.xs),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = AppSizes.avatarSm,
  });

  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final pair = _paletteFor(name);
    final resolved = (imageUrl == null || imageUrl!.isEmpty)
        ? null
        : resolveImageUrl(imageUrl!);

    final monogram = Text(
      letter,
      style: TextStyle(
        color: pair.$2,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: pair.$1, shape: BoxShape.circle),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline, width: 1),
      ),
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      child: resolved == null
          ? monogram
          : Image.network(
              resolved,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => monogram,
              frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                  wasSynchronouslyLoaded || frame != null ? child : monogram,
            ),
    );
  }

  static (Color, Color) _paletteFor(String name) {
    final pairs = <(Color, Color)>[
      (AppColors.brandSoft, AppColors.brandStrong),
      (AppColors.accentTealSoft, AppColors.accentTeal),
      (AppColors.accentIndigoSoft, AppColors.accentIndigo),
      (AppColors.accentAmberSoft, AppColors.accentAmber),
      (AppColors.accentRoseSoft, AppColors.accentRose),
    ];
    var hash = 0;
    for (final c in name.codeUnits) {
      hash = (hash * 31 + c) & 0x7fffffff;
    }
    return pairs[hash % pairs.length];
  }
}
