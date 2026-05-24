import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/addresses_page.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/orders/presentation/pages/my_orders_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/info_pages.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/linked_merchants_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';

class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: AppStrings.logout,
      message: AppStrings.logoutConfirm,
      confirmLabel: AppStrings.logout,
      danger: true,
    );
    if (ok && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: AppStrings.navProfile),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSizes.huge),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg, AppSizes.lg, AppSizes.lg, AppSizes.md,
            ),
            child: Row(
              children: [
                _Avatar(name: user?.name ?? '?', size: 72),
                const SizedBox(width: AppSizes.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name ?? '—',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        user?.email ?? '',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                        ),
                      ),
                      if (user?.createdAt != null) ...[
                        const SizedBox(height: AppSizes.xs),
                        Text(
                          '${AppStrings.memberSince} '
                          '${DateFormat('MMM yyyy').format(user!.createdAt)}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const _Gap(),
          _Row(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ),
          ),
          _Row(
            icon: Icons.storefront_outlined,
            title: 'Linked merchants',
            subtitle: 'Browse shops you have a relationship with',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LinkedMerchantsPage()),
            ),
          ),
          _Row(
            icon: Icons.location_on_outlined,
            title: 'Delivery addresses',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AddressesPage()),
            ),
          ),
          // Orders used to live in the bottom nav; surfaced here so it
          // stays one tap from the profile root.
          _Row(
            icon: Icons.receipt_long_outlined,
            title: AppStrings.myOrders,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyOrdersPage()),
            ),
          ),
          const _Gap(),
          _Row(
            icon: Icons.info_outline_rounded,
            title: AppStrings.about,
            subtitle: 'Version 1.0.0',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
          ),
          _Row(
            icon: Icons.shield_outlined,
            title: AppStrings.privacyPolicy,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PrivacyPolicyPage()),
            ),
          ),
          _Row(
            icon: Icons.description_outlined,
            title: AppStrings.termsOfService,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TermsOfServicePage()),
            ),
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
                onTap: () => _logout(context),
                customBorder: AppShapes.squircle(AppSizes.radiusMd),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.lg,
                    vertical: AppSizes.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded,
                          color: AppColors.error, size: AppSizes.iconMd),
                      const SizedBox(width: AppSizes.md),
                      Text(
                        AppStrings.logout,
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
          ),
        ],
      ),
    );
  }

}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.brandSoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          color: AppColors.brandStrong,
          fontSize: size * 0.4,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.xl,
        ),
        child: Container(height: 1, color: AppColors.hairline),
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.lg, vertical: AppSizes.md,
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
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
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
