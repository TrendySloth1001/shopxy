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

/// [ProfileField] targets that now live on [InvoiceSettingsPage] instead of
/// [EditProfilePage] — the completion meter's "what's left" chips route
/// through this to decide which screen a deep-link opens.
const _kInvoiceSettingsFields = {
  ProfileField.shopGstin,
  ProfileField.shopPan,
  ProfileField.upiVpa,
};

/// Formats the stored `YYYY-MM-DD` (or full ISO datetime) effective-date
/// string for display; falls back to the raw value if parsing fails.
String _formatGstEffectiveFrom(String value) {
  final parsed = DateTime.tryParse(value);
  return parsed != null ? DateFormat('d MMM y').format(parsed) : value;
}

/// Profile tab — polished snapshot of the merchant identity plus the
/// shortcuts that don't deserve a top-level nav slot. One canonical
/// Settings entry (the gear icon in the AppBar); the "Edit profile"
/// pill in the hero goes to the focused name + shop editor.
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

  /// Whether the shop looks genuinely *unstarted* — the gate for the big
  /// "finish setting up your shop" callout. We only nudge with the banner
  /// when none of the invoice-critical fields exist yet; once the merchant
  /// has begun (e.g. only GSTIN left), the completion meter above already
  /// names the exact missing field, so the banner would be redundant and
  /// its generic copy ("add your shop name and state") would contradict
  /// what's actually filled.
  static bool _shopProfileIncomplete(AuthUser u) {
    bool blank(String? v) => v == null || v.trim().isEmpty;
    return blank(u.shopName) && blank(u.shopStateCode) && blank(u.shopGstin);
  }

  /// "Personal details" — the account-holder's own fields (read-only). The
  /// shortcuts that used to live here now belong to the Menu tab; this
  /// screen is solely a snapshot of the profile the user filled in.
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

  /// "Shop details" — the shop identity used on invoices, mirroring the
  /// fields in [EditProfilePage] so this screen reflects what was entered.
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

  /// "Invoice settings" — the tax/payment fields that identify the shop on
  /// its invoices (GSTIN, GST effective date, PAN, UPI ID). A snapshot like
  /// the sections above, but the whole card is tappable through to
  /// [InvoiceSettingsPage] since that's now the only place these fields
  /// are edited.
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

  /// Renders the state as "27 — Maharashtra" when both halves are present,
  /// otherwise whichever one is set (or null so the row shows "Not added").
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

  /// Confirms via a bottom sheet, then clears the session. Unwinding back to
  /// the login screen is the root `_AuthGate`'s job — it watches for the
  /// session ending and pops every pushed route, so this (and every other
  /// logout entry point) doesn't have to remember to.
  static Future<void> _confirmAndLogout(BuildContext context) async {
    final confirmed = await showLogoutConfirmSheet(context);
    if (confirmed != true || !context.mounted) return;
    await context.read<AuthProvider>().logout();
  }
}

// ─────────────────────────────────────────────────────────────────────
// Hero — branded panel with avatar, name, email, role + edit pill
// ─────────────────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({this.user});

  final AuthUser? user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final name = user?.name ?? '—';
    final email = user?.email ?? '';
    // The chip reflects the *shop* role (Owner/Manager/Stockist/Cashier),
    // not the account role — `user.role` is OWNER for every merchant
    // account including staff, which would mislabel everyone "Owner".
    final shopRole = user?.shopRole;
    final memberSince = user?.createdAt;
    final shopName = user?.shopName;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.xl,
        AppSizes.lg,
        AppSizes.lg,
      ),
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(AppSizes.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.brandSoft, AppColors.heroPanel],
        ),
        shadows: AppShadows.floating,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Slightly larger avatar with a ring to feel like a portrait.
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
                    if (shopName != null && shopName.trim().isNotEmpty) ...[
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
          // Edit profile as a proper pill button — more discoverable than
          // the old inline text link, but still subtle (outlined, not
          // primary, so it doesn't fight the Settings gear above).
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfilePage()),
              ),
              icon: const AppIcon(AppIcons.editOutlined, size: AppSizes.iconSm),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// "Complete your shop profile" callout
// ─────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────
// Profile completion meter — % filled + what's left
// ─────────────────────────────────────────────────────────────────────

class _ProfileCompletion extends StatelessWidget {
  const _ProfileCompletion({required this.user, required this.onComplete});

  final AuthUser user;
  final VoidCallback onComplete;

  /// Fields that make an invoice look professional + let a customer reach
  /// the shop. Kept in lockstep with the web `profileCompletion` helper so
  /// both apps show the same percentage. [label] is a localized display
  /// string resolved from [l10n] at build time.
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

    // Fully complete — nothing to nudge.
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
                // Each missing field is a tappable chip that deep-links into
                // the editor focused on exactly that field — no more hunting
                // down the form for the one thing that's left.
                for (final m in missing)
                  Material(
                    color: AppColors.brandSoft,
                    shape: AppShapes.squircle(AppSizes.radiusFull),
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => _kInvoiceSettingsFields.contains(m.target)
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

// ─────────────────────────────────────────────────────────────────────
// Section primitives
// ─────────────────────────────────────────────────────────────────────

/// The left inset a divider needs so it starts under the row's text, not
/// under its leading icon: horizontal padding + icon width + icon gap.
const double _kDetailRowIndent = AppSizes.lg + _kDetailIconSize + AppSizes.md;
const double _kDetailIconSize = 36;

/// A titled, read-only group of profile fields. A section header (small
/// icon + label) sits above a bordered surface card whose rows are
/// separated by inset hairlines — the same "card of facts" treatment as
/// the completion meter, so the whole screen reads as one calm snapshot.
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

  /// When set, the whole card becomes tappable (with a trailing chevron
  /// next to the header) — used when this section is really a shortcut to
  /// another screen rather than a plain read-only snapshot.
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

/// One field line inside a [_DetailSection]: a soft-tinted leading icon,
/// a small label, and the value beneath it. Filled `copyable` fields
/// (email/phone/GSTIN/PAN/UPI) tap to copy — a frequent merchant need —
/// with a subtle copy glyph as the affordance. Blank fields fall back to
/// a muted "Not added" so the layout stays stable and gaps stay legible.
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

/// The destructive "Log out" action at the foot of the screen — a full-width
/// card with a centred red label. Tapping opens a confirmation bottom sheet
/// (see [ProfilePage._confirmAndLogout]) rather than logging out instantly.
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

// ─────────────────────────────────────────────────────────────────────
// Meta chips (role + member-since)
// ─────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────
// Public reusable avatar — kept identical, other features import this.
// ─────────────────────────────────────────────────────────────────────

/// Circular user avatar. Uses [imageUrl] when supplied, otherwise falls
/// back to a brand-tinted monogram of the first letter of [name].
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
      // The hairline is a FOREGROUND decoration, not a border on the one above.
      // A border in the background decoration is reported as padding, so the
      // content box shrinks by the stroke on every edge while the child is
      // still asked for `size` — the image then overflows its box and gets
      // clipped, which is what cut the discs off. Painted in front, the ring
      // costs no layout space: this widget measures exactly `size`, and the
      // picture fills the whole circle.
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
              // Every failure falls back to the monogram. The previous
              // DecorationImage had no error path at all and nulled the child
              // whenever a URL existed, so a fetch that failed left an empty
              // coloured circle with no letter in it — which is what a missing
              // avatar looked like. It fails for ordinary reasons: the login
              // screen renders before the network is usable, and a remembered
              // account carries the avatar URL it was cached with, which 404s
              // once that user changes their picture.
              errorBuilder: (_, _, _) => monogram,
              // Same letter while the bytes are in flight, so the circle is
              // never momentarily blank; the image simply replaces it.
              frameBuilder: (_, child, frame, wasSynchronouslyLoaded) =>
                  wasSynchronouslyLoaded || frame != null ? child : monogram,
            ),
    );
  }

  /// Picks one of a handful of soft/strong pairs based on the user's
  /// name. Stable across reloads — same name → same colour.
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
