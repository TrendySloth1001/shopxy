import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/network/image_url.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy/features/profile/presentation/pages/settings_page.dart';
import 'package:shopxy/features/reports/presentation/pages/reports_page.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustments_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shadows.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

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
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: Text(l10n.profileNavProfile),
        actions: [
          IconButton(
            tooltip: l10n.profileSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.huge),
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
          ..._businessSection(context, user),
          ..._operationsSection(context, user),
          const SizedBox(height: AppSizes.huge),
          Center(
            child: Text(
              '${AppStrings.appName} · ${l10n.profileAppTagline}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                  ),
            ),
          ),
          const SizedBox(height: AppSizes.lg),
        ],
      ),
    );
  }

  /// Heuristic for whether the shop profile is materially blank. We don't
  /// require every field — just enough that an invoice header would look
  /// professional. Used to gate the "complete your shop profile" callout.
  static bool _shopProfileIncomplete(AuthUser u) {
    return (u.shopName == null || u.shopName!.trim().isEmpty) ||
        (u.shopStateCode == null || u.shopStateCode!.trim().isEmpty) ||
        (u.shopGstin == null || u.shopGstin!.trim().isEmpty);
  }

  /// "Manage your business" — only the tiles this role can act on. The
  /// section header is dropped entirely if the role has none of them.
  static List<Widget> _businessSection(BuildContext context, AuthUser? user) {
    if (user == null) return const [];
    final l10n = AppLocalizations.of(context);
    final tiles = <Widget>[
      if (user.canView('products'))
        _ManageTile(
          icon: Icons.category_outlined,
          accent: AppColors.accentTeal,
          accentSoft: AppColors.accentTealSoft,
          title: l10n.profileNavCategories,
          subtitle: l10n.profileCategoriesSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CategoriesPage()),
          ),
        ),
      if (user.canView('vendors'))
        _ManageTile(
          icon: Icons.storefront_outlined,
          accent: AppColors.accentIndigo,
          accentSoft: AppColors.accentIndigoSoft,
          title: l10n.profileNavVendors,
          subtitle: l10n.profileVendorsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VendorsPage()),
          ),
        ),
      if (user.canView('parties'))
        _ManageTile(
          icon: Icons.groups_outlined,
          accent: AppColors.accentRose,
          accentSoft: AppColors.accentRoseSoft,
          title: l10n.profileNavParties,
          subtitle: l10n.profilePartiesSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PartiesPage()),
          ),
        ),
    ];
    if (tiles.isEmpty) return const [];
    return [
      _SectionLabel(text: l10n.profileManageBusiness),
      const SizedBox(height: AppSizes.sm),
      _ManageCard(children: tiles),
      const SizedBox(height: AppSizes.lg),
    ];
  }

  /// "Operations" — invoicing/inventory tiles gated by capability.
  /// Reports stays for everyone (it's a read-only insight surface).
  static List<Widget> _operationsSection(BuildContext context, AuthUser? user) {
    if (user == null) return const [];
    final l10n = AppLocalizations.of(context);
    final tiles = <Widget>[
      if (user.canView('invoices'))
        _ManageTile(
          icon: Icons.receipt_long_outlined,
          accent: AppColors.brandStrong,
          accentSoft: AppColors.brandSoft,
          title: l10n.profileNavInvoices,
          subtitle: l10n.profileInvoicesSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvoicesPage()),
          ),
        ),
      if (user.canView('challans'))
        _ManageTile(
          icon: Icons.assignment_outlined,
          accent: AppColors.accentAmber,
          accentSoft: AppColors.accentAmberSoft,
          title: l10n.profileNavChallans,
          subtitle: l10n.profileChallansSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ChallansPage()),
          ),
        ),
      if (user.canView('stock'))
        _ManageTile(
          icon: Icons.tune_rounded,
          accent: AppColors.brand,
          accentSoft: AppColors.brandSoft,
          title: l10n.profileStockAdjustments,
          subtitle: l10n.profileStockAdjustmentsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const StockAdjustmentsPage()),
          ),
        ),
      if (user.canView('reports'))
        _ManageTile(
          icon: Icons.insights_outlined,
          accent: AppColors.brandStrong,
          accentSoft: AppColors.brandSoft,
          title: l10n.profileReports,
          subtitle: l10n.profileReportsSubtitle,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ReportsPage()),
          ),
        ),
    ];
    if (tiles.isEmpty) return const [];
    return [
      _SectionLabel(text: l10n.profileOperations),
      const SizedBox(height: AppSizes.sm),
      _ManageCard(children: tiles),
    ];
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
          colors: [
            AppColors.brandSoft,
            AppColors.heroPanel,
          ],
        ),
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
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (shopName != null && shopName.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
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
                    const SizedBox(height: 4),
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
                            icon: Icons.calendar_today_outlined,
                            label:
                                '${l10n.profileMemberSince} ${DateFormat('MMM yyyy').format(memberSince)}',
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
              icon: const Icon(Icons.edit_outlined, size: AppSizes.iconSm),
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
                textStyle: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                child: Icon(
                  Icons.storefront_rounded,
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
                    const SizedBox(height: 2),
                    Text(
                      l10n.profileFinishShopSetupBody,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
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
  static List<({String label, bool filled})> _fields(
      AuthUser u, AppLocalizations l10n) {
    bool ok(String? v) => v != null && v.trim().isNotEmpty;
    return [
      (label: l10n.profileFieldName, filled: ok(u.name)),
      (label: l10n.profileFieldPhoto, filled: ok(u.avatarUrl)),
      (label: l10n.profileFieldPhone, filled: ok(u.phoneNumber)),
      (label: l10n.profileFieldShopName, filled: ok(u.shopName)),
      (label: l10n.profileFieldAddress, filled: ok(u.shopAddress)),
      (label: l10n.profileFieldCity, filled: ok(u.shopCity)),
      (label: l10n.profileFieldState, filled: ok(u.shopState)),
      (label: l10n.profileFieldStateCode, filled: ok(u.shopStateCode)),
      (label: l10n.profileFieldPinCode, filled: ok(u.shopPinCode)),
      (label: l10n.profileFieldGstin, filled: ok(u.shopGstin)),
      (label: l10n.profileFieldPan, filled: ok(u.shopPan)),
      (label: l10n.profileFieldUpiId, filled: ok(u.upiVpa)),
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
    final missing = fields.where((f) => !f.filled).map((f) => f.label).toList();

    // Fully complete — nothing to nudge.
    if (percent >= 100) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline),
        ),
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
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$filled / $total ${l10n.profileCompletionDetailsAdded}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.muted),
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
              valueColor:
                  AlwaysStoppedAnimation<Color>(AppColors.brand),
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.sm,
                      vertical: 2,
                    ),
                    decoration: ShapeDecoration(
                      color: AppColors.surfaceTint,
                      shape: AppShapes.squircle(AppSizes.radiusFull),
                    ),
                    child: Text(
                      m,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: AppColors.muted),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.xl),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.muted,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// Card shell that wraps a list of [_ManageTile]s, drawing a single
/// rounded border so the grouping feels like one surface rather than a
/// flat list of rows. Hairline dividers between rows.
class _ManageCard extends StatelessWidget {
  const _ManageCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: const EdgeInsets.only(left: AppSizes.lg + AppSizes.xxxl + AppSizes.md),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: BorderSide(color: AppColors.hairline),
        ),
      ),
      child: Column(children: rows),
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppShapes.squircleRadius(AppSizes.radiusMd),
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
                color: accentSoft,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: AppSizes.iconMd, color: accent),
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
            Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
          ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 3,
      ),
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
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 3,
      ),
      decoration: ShapeDecoration(
        color: AppColors.surface,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: AppColors.muted),
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pair.$1,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline, width: 1),
        image: resolved != null
            ? DecorationImage(
                image: NetworkImage(resolved),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: resolved == null
          ? Text(
              letter,
              style: TextStyle(
                color: pair.$2,
                fontSize: size * 0.4,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            )
          : null,
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
