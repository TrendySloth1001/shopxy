import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/addresses/presentation/pages/addresses_page.dart';
import 'package:shopxy_customer/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/auth/presentation/widgets/require_auth.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/edit_profile_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/help_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/info_pages.dart';
import 'package:shopxy_customer/features/gst/presentation/pages/gst_details_page.dart';
import 'package:shopxy_customer/features/profile/presentation/pages/notification_preferences_page.dart';
import 'package:shopxy_customer/features/recently_viewed/presentation/pages/recently_viewed_page.dart';
import 'package:shopxy_customer/features/returns/presentation/pages/my_returns_page.dart';
import 'package:shopxy_customer/features/reviews/presentation/pages/my_reviews_page.dart';
import 'package:shopxy_customer/features/coupons/presentation/pages/my_coupons_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/linked_merchants_page.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/my_shops_page.dart';
import 'package:shopxy_customer/features/profile/presentation/widgets/profile_avatar.dart';
import 'package:shopxy_customer/features/wishlist/presentation/pages/wishlist_page.dart';
import 'package:shopxy_customer/shared/constants/app_sizes.dart';
import 'package:shopxy_customer/shared/constants/app_strings.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';
import 'package:shopxy_customer/shared/theme/app_shapes.dart';
import 'package:shopxy_customer/shared/widgets/app_bar.dart';
import 'package:shopxy_customer/shared/widgets/app_button.dart';
import 'package:shopxy_customer/shared/widgets/app_dialog.dart';
import 'package:shopxy_customer/core/icons/app_icons.dart';
import 'package:shopxy_customer/core/icons/app_icon.dart';
import 'package:shopxy_customer/shared/theme/app_text_styles.dart';

class CustomerProfilePage extends StatelessWidget {
  const CustomerProfilePage({super.key});

  Future<void> _logout(BuildContext context) async {
    final ok = await AppConfirmSheet.show(
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
    final auth = context.watch<AuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const AppAppBar(title: AppStrings.navProfile),
      body: auth.isGuest
          ? _GuestProfileBody(theme: theme)
          : _buildSignedInBody(context, theme, auth.user),
    );
  }

  /// Rendered for signed-in users. Pulled out of `build` only so the
  /// guest path stays a clean swap and the existing list keeps its
  /// shape (no rewrite, just relocation).
  Widget _buildSignedInBody(
    BuildContext context,
    ThemeData theme,
    AuthUser? user,
  ) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.lg,
            AppSizes.md,
          ),
          child: Row(
            children: [
              ProfileAvatar(
                name: user?.name ?? '?',
                avatarUrl: user?.avatarUrl,
                size: 72,
              ),
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
          icon: AppIcons.editOutlined,
          title: 'Edit profile',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const EditProfilePage())),
        ),
        _Row(
          icon: AppIcons.storefrontOutlined,
          title: 'Linked merchants',
          subtitle: 'Browse shops you have a relationship with',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const LinkedMerchantsPage()),
          ),
        ),
        _Row(
          icon: AppIcons.receiptLongOutlined,
          title: 'Invoices from shops',
          subtitle: 'Tap a shop to see the invoices it sent you',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyShopsPage())),
        ),
        _Row(
          icon: AppIcons.locationOnOutlined,
          title: 'Delivery addresses',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AddressesPage())),
        ),
        // Orders deliberately omitted — it lives in the bottom nav as
        // its own tab. Keeping it here too made the profile redundant
        // and confused which surface is the source of truth.
        const _SectionLabel(label: 'Activity'),
        _Row(
          icon: AppIcons.favoriteBorderRounded,
          title: 'Wishlist',
          subtitle: 'Items you saved for later',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const WishlistPage())),
        ),
        _Row(
          icon: AppIcons.localOfferOutlined,
          title: 'My coupons',
          subtitle: 'Redeemable promo codes from your shops',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyCouponsPage())),
        ),
        _Row(
          icon: AppIcons.rateReviewOutlined,
          title: 'My reviews',
          subtitle: 'Ratings and reviews you wrote',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyReviewsPage())),
        ),
        _Row(
          icon: AppIcons.assignmentReturnOutlined,
          title: 'Returns',
          subtitle: 'Track your return requests',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const MyReturnsPage())),
        ),
        _Row(
          icon: AppIcons.historyRounded,
          title: 'Recently viewed',
          subtitle: 'Pick up where you left off',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const RecentlyViewedPage())),
        ),
        const _SectionLabel(label: 'Settings'),
        _Row(
          icon: AppIcons.receiptLongOutlined,
          title: 'GST details',
          subtitle: 'Claim input credit on business purchases',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const GstDetailsPage())),
        ),
        _Row(
          icon: AppIcons.notificationsActiveOutlined,
          title: 'Notification preferences',
          subtitle: 'Order updates, deals, account alerts',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NotificationPreferencesPage(),
            ),
          ),
        ),
        _Row(
          icon: AppIcons.helpOutlineRounded,
          title: 'Help & FAQ',
          subtitle: 'Common questions + email support',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HelpAndFaqPage())),
        ),
        const _Gap(),
        _Row(
          icon: AppIcons.infoOutlineRounded,
          title: AppStrings.about,
          subtitle: 'Version 1.0.0',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
        ),
        _Row(
          icon: AppIcons.shieldOutlined,
          title: AppStrings.privacyPolicy,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
        ),
        _Row(
          icon: AppIcons.descriptionOutlined,
          title: AppStrings.termsOfService,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
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
                    const AppIcon(
                      AppIcons.logoutRounded,
                      color: AppColors.error,
                      size: AppSizes.iconMd,
                    ),
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
    );
  }
}

/// Public-browse profile body: a sign-in hero card and a slim set of
/// non-user-scoped settings (Help, About, Privacy, Terms). Authed-only
/// rows (Edit profile, Linked merchants, Addresses, Wishlist, etc.) are
/// omitted entirely rather than gated per-row — the page itself is the
/// gate, which matches how Amazon/Flipkart present "You" for guests.
class _GuestProfileBody extends StatelessWidget {
  const _GuestProfileBody({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: AppSizes.huge),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.lg,
            AppSizes.xl,
            AppSizes.lg,
            AppSizes.lg,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.lg),
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(
                AppSizes.radiusLg,
                side: const BorderSide(color: AppColors.hairline, width: 1),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: AppSizes.avatarMd,
                      height: AppSizes.avatarMd,
                      decoration: ShapeDecoration(
                        color: AppColors.heroPanel,
                        shape: AppShapes.squircle(AppSizes.radiusMd),
                      ),
                      alignment: Alignment.center,
                      child: const AppIcon(
                        AppIcons.personOutlineRounded,
                        size: 28,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome to ShopXY',
                            style: theme.textTheme.titleMedium?.extraBold,
                          ),
                          const SizedBox(height: AppSizes.xxs),
                          Text(
                            'Sign in to track orders, save items and get '
                            'invitations from your shops.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.lg),
                AppButton.primary(
                  label: 'Sign in',
                  icon: AppIcons.loginRounded,
                  fullWidth: true,
                  onPressed: () => requireAuth(
                    context,
                    reason:
                        'Sign in to access orders, saved items, addresses '
                        'and shop invitations.',
                  ),
                ),
              ],
            ),
          ),
        ),
        const _SectionLabel(label: 'About'),
        _Row(
          icon: AppIcons.helpOutlineRounded,
          title: 'Help & FAQ',
          subtitle: 'Common questions + email support',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const HelpAndFaqPage())),
        ),
        _Row(
          icon: AppIcons.infoOutlineRounded,
          title: AppStrings.about,
          subtitle: 'Version 1.0.0',
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const AboutPage())),
        ),
        _Row(
          icon: AppIcons.shieldOutlined,
          title: AppStrings.privacyPolicy,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PrivacyPolicyPage())),
        ),
        _Row(
          icon: AppIcons.descriptionOutlined,
          title: AppStrings.termsOfService,
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const TermsOfServicePage())),
        ),
      ],
    );
  }
}

class _Gap extends StatelessWidget {
  const _Gap();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: AppSizes.lg,
      vertical: AppSizes.xl,
    ),
    child: Container(height: 1, color: AppColors.hairline),
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.lg,
      AppSizes.lg,
      AppSizes.lg,
      AppSizes.xs,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.muted,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final AppIconData icon;
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
              child: AppIcon(icon, size: 18, color: AppColors.black),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.bodyLarge?.semibold),
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
            const AppIcon(
              AppIcons.chevronRightRounded,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}
