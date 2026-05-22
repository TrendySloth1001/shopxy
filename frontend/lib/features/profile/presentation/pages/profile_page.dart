import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/profile/presentation/pages/settings_page.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustments_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';

/// Profile tab — account snapshot + management shortcuts + entry into
/// Settings. Editorial flow, no boxed cards.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
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
          _ProfileHeader(
            name: user?.name ?? '—',
            email: user?.email ?? '',
            role: user?.role,
            memberSince: user?.createdAt,
          ),
          const _SectionGap(),
          const _Eyebrow('MANAGE'),
          const SizedBox(height: AppSizes.sm),
          _ProfileLink(
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
          _ProfileLink(
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
          _ProfileLink(
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
          _ProfileLink(
            icon: Icons.receipt_long_outlined,
            accent: AppColors.accentAmber,
            accentSoft: AppColors.accentAmberSoft,
            title: AppStrings.navChallans,
            subtitle: 'Delivery notes without prices',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChallansPage()),
            ),
          ),
          _ProfileLink(
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
          const _SectionGap(),
          const _Eyebrow('PREFERENCES'),
          const SizedBox(height: AppSizes.sm),
          _ProfileLink(
            icon: Icons.settings_outlined,
            accent: AppColors.black,
            accentSoft: AppColors.heroPanel,
            title: AppStrings.settings,
            subtitle: 'Account, appearance, and more',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
          _ProfileLink(
            icon: Icons.info_outline_rounded,
            accent: AppColors.muted,
            accentSoft: AppColors.heroPanel,
            title: AppStrings.about,
            subtitle: 'Version, privacy and terms',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SettingsPage(initialSection: SettingsSection.about),
              ),
            ),
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Header — large avatar, name, email, role chip
// ─────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.name,
    required this.email,
    this.role,
    this.memberSince,
  });

  final String name;
  final String email;
  final String? role;
  final DateTime? memberSince;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(name: name, size: 76),
              const SizedBox(width: AppSizes.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSizes.sm),
                    Row(
                      children: [
                        _RoleChip(role: role),
                        if (memberSince != null) ...[
                          const SizedBox(width: AppSizes.sm),
                          Text(
                            '${AppStrings.memberSince} '
                            '${DateFormat('MMM yyyy').format(memberSince!)}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppColors.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          // Inline subtle "edit profile" link — no box.
          InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const SettingsPage(initialSection: SettingsSection.account),
              ),
            ),
            customBorder: AppShapes.squircle(AppSizes.radiusFull),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSizes.xs,
                horizontal: AppSizes.xs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: AppColors.brandStrong,
                  ),
                  const SizedBox(width: AppSizes.xs),
                  Text(
                    AppStrings.editProfile,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.brandStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
        vertical: 2,
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

// ─────────────────────────────────────────────────────────────────────
// Public reusable avatar
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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: pair.$1,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.hairline, width: 1),
        image: imageUrl != null && imageUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(imageUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: imageUrl == null || imageUrl!.isEmpty
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

// ─────────────────────────────────────────────────────────────────────
// Editorial primitives shared with dashboard
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

class _SectionGap extends StatelessWidget {
  const _SectionGap();
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

class _ProfileLink extends StatelessWidget {
  const _ProfileLink({
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
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}
