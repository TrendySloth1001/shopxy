import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
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

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text(AppStrings.navProfile),
        actions: [
          IconButton(
            tooltip: AppStrings.settings,
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
          if (user != null && _shopProfileIncomplete(user))
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
          const _SectionLabel(text: 'Manage your business'),
          const SizedBox(height: AppSizes.sm),
          _ManageCard(
            children: [
              _ManageTile(
                icon: Icons.category_outlined,
                accent: AppColors.accentTeal,
                accentSoft: AppColors.accentTealSoft,
                title: AppStrings.navCategories,
                subtitle: 'Product categories and grouping',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CategoriesPage()),
                ),
              ),
              _ManageTile(
                icon: Icons.storefront_outlined,
                accent: AppColors.accentIndigo,
                accentSoft: AppColors.accentIndigoSoft,
                title: AppStrings.navVendors,
                subtitle: 'Suppliers you buy from',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VendorsPage()),
                ),
              ),
              _ManageTile(
                icon: Icons.groups_outlined,
                accent: AppColors.accentRose,
                accentSoft: AppColors.accentRoseSoft,
                title: AppStrings.navParties,
                subtitle: 'Customers you sell to',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PartiesPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          const _SectionLabel(text: 'Operations'),
          const SizedBox(height: AppSizes.sm),
          _ManageCard(
            children: [
              _ManageTile(
                icon: Icons.receipt_long_outlined,
                accent: AppColors.brandStrong,
                accentSoft: AppColors.brandSoft,
                title: AppStrings.navInvoices,
                subtitle: 'Sales, purchase and credit notes',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvoicesPage()),
                ),
              ),
              _ManageTile(
                icon: Icons.assignment_outlined,
                accent: AppColors.accentAmber,
                accentSoft: AppColors.accentAmberSoft,
                title: AppStrings.navChallans,
                subtitle: 'Delivery notes without prices',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChallansPage()),
                ),
              ),
              _ManageTile(
                icon: Icons.tune_rounded,
                accent: AppColors.brand,
                accentSoft: AppColors.brandSoft,
                title: 'Stock adjustments',
                subtitle: 'Damage, expiry, shrinkage corrections',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockAdjustmentsPage()),
                ),
              ),
              _ManageTile(
                icon: Icons.insights_outlined,
                accent: AppColors.brandStrong,
                accentSoft: AppColors.brandSoft,
                title: 'Reports',
                subtitle: 'Sales, purchases, GST and P&L',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ReportsPage()),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.huge),
          Center(
            child: Text(
              '${AppStrings.appName} · ${AppStrings.appTagline}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.muted,
                    letterSpacing: 1.2,
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
    final name = user?.name ?? '—';
    final email = user?.email ?? '';
    final role = user?.role;
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
        gradient: const LinearGradient(
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
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                        letterSpacing: -0.4,
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
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _RoleChip(role: role),
                        if (memberSince != null)
                          _MetaChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                'Since ${DateFormat('MMM yyyy').format(memberSince)}',
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
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text(AppStrings.editProfile),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.brandStrong,
                backgroundColor: AppColors.white,
                side: const BorderSide(color: AppColors.hairline),
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
    return Material(
      color: AppColors.accentAmberSoft,
      shape: AppShapes.squircle(AppSizes.radiusMd),
      child: InkWell(
        onTap: onTap,
        customBorder: AppShapes.squircle(AppSizes.radiusMd),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: ShapeDecoration(
                  color: AppColors.white,
                  shape: AppShapes.squircle(AppSizes.radiusSm),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: AppColors.accentAmber,
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish setting up your shop',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Add your shop name, GSTIN and state so invoices print correctly.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
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
              letterSpacing: 0.4,
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
          const Padding(
            padding: EdgeInsets.only(left: AppSizes.lg + 36 + AppSizes.md),
            child: Divider(height: 1, color: AppColors.hairline),
          ),
        );
      }
      rows.add(children[i]);
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.white,
        shape: AppShapes.squircle(
          AppSizes.radiusMd,
          side: const BorderSide(color: AppColors.hairline),
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
      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg,
          vertical: AppSizes.md,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: ShapeDecoration(
                color: accentSoft,
                shape: AppShapes.squircle(AppSizes.radiusSm),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
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
            const Icon(Icons.chevron_right_rounded, color: AppColors.subtle),
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
  const _RoleChip({this.role});
  final String? role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwner = role == 'OWNER';
    final label = isOwner
        ? AppStrings.roleOwner
        : (role == null || role!.isEmpty ? AppStrings.roleStaff : role!);
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
          letterSpacing: 0.4,
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
        color: AppColors.white,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.muted),
          const SizedBox(width: 4),
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
    this.size = 40,
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
    const pairs = <(Color, Color)>[
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
