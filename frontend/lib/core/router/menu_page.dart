import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_bank_offers_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_banners_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_category_taxonomy_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_collections_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_shops_page.dart';
import 'package:shopxy/features/analytics/presentation/pages/merchant_analytics_page.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/banners/presentation/pages/merchant_banners_page.dart';
import 'package:shopxy/features/cashier/presentation/pages/cashier_page.dart';
import 'package:shopxy/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/coupons/presentation/pages/merchant_coupons_page.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/pos/presentation/pages/pos_page.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart';
import 'package:shopxy/features/profile/presentation/pages/settings_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/quotations_page.dart';
import 'package:shopxy/features/reports/presentation/pages/reports_page.dart';
import 'package:shopxy/features/returns/presentation/pages/merchant_returns_page.dart';
import 'package:shopxy/features/scan_console/presentation/pages/scan_console_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_profile_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_team_page.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustments_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';

/// One menu row — a feature the user can open. Pushes [builder] on tap.
/// [requires] gates it by shop capability (null = visible to any team member).
class _MenuItem {
  const _MenuItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.builder,
    this.requires,
  });
  final String Function(AppLocalizations l10n) label;
  final String Function(AppLocalizations l10n) description;
  final IconData icon;
  final Color accent;
  final Color accentSoft;
  final WidgetBuilder builder;
  final bool Function(AuthUser user)? requires;

  bool visibleTo(AuthUser? user) =>
      requires == null || (user != null && requires!(user));
}

List<_MenuItem> get _manageItems => [
      _MenuItem(
        label: (l) => l.navMyShop,
        description: (l) => l.menuDescMyShop,
        icon: Icons.storefront_outlined,
        accent: AppColors.brand,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const ShopProfilePage(),
        requires: (u) => u.canView('shop'),
      ),
      _MenuItem(
        label: (l) => l.navTeamRoles,
        description: (l) => l.menuDescTeam,
        icon: Icons.groups_2_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const ShopTeamPage(),
        requires: (u) => u.canView('team'),
      ),
      _MenuItem(
        label: (l) => l.navCategories,
        description: (l) => l.menuDescCategories,
        icon: Icons.category_outlined,
        accent: AppColors.accentTeal,
        accentSoft: AppColors.accentTealSoft,
        builder: (_) => const CategoriesPage(),
        requires: (u) => u.canView('products'),
      ),
      _MenuItem(
        label: (l) => l.navVendors,
        description: (l) => l.menuDescVendors,
        icon: Icons.storefront_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const VendorsPage(),
        requires: (u) => u.canView('vendors'),
      ),
      _MenuItem(
        label: (l) => l.navParties,
        description: (l) => l.menuDescParties,
        icon: Icons.groups_outlined,
        accent: AppColors.accentRose,
        accentSoft: AppColors.accentRoseSoft,
        builder: (_) => const PartiesPage(),
        requires: (u) => u.canView('parties'),
      ),
      _MenuItem(
        label: (l) => l.navBanners,
        description: (l) => l.menuDescBanners,
        icon: Icons.image_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const MerchantBannersPage(),
        requires: (u) => u.canView('marketing'),
      ),
      _MenuItem(
        label: (l) => l.navCoupons,
        description: (l) => l.menuDescCoupons,
        icon: Icons.local_offer_outlined,
        accent: AppColors.accentAmber,
        accentSoft: AppColors.accentAmberSoft,
        builder: (_) => const MerchantCouponsPage(),
        requires: (u) => u.canView('marketing'),
      ),
    ];

// Invoices is intentionally omitted here — it's a primary bottom-nav tab now.
List<_MenuItem> get _operationItems => [
      _MenuItem(
        label: (l) => l.navPointOfSale,
        description: (l) => l.menuDescPos,
        icon: Icons.point_of_sale_rounded,
        accent: AppColors.brand,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const PosPage(),
        requires: (u) => u.canView('invoices'),
      ),
      _MenuItem(
        label: (l) => l.navCashier,
        description: (l) => l.menuDescCashier,
        icon: Icons.calculate_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const CashierPage(),
        requires: (u) => u.canView('invoices'),
      ),
      _MenuItem(
        label: (l) => l.navScanToConsole,
        description: (l) => l.menuDescScan,
        icon: Icons.qr_code_scanner_rounded,
        accent: AppColors.accentTeal,
        accentSoft: AppColors.accentTealSoft,
        builder: (_) => const ScanConsolePage(),
        requires: (u) => u.canView('products'),
      ),
      _MenuItem(
        label: (l) => l.navQuotations,
        description: (l) => l.menuDescQuotations,
        icon: Icons.request_quote_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const QuotationsPage(),
        requires: (u) => u.canView('quotations'),
      ),
      _MenuItem(
        label: (l) => l.navChallans,
        description: (l) => l.menuDescChallans,
        icon: Icons.assignment_outlined,
        accent: AppColors.accentAmber,
        accentSoft: AppColors.accentAmberSoft,
        builder: (_) => const ChallansPage(),
        requires: (u) => u.canView('challans'),
      ),
      _MenuItem(
        label: (l) => l.navStockAdjustments,
        description: (l) => l.menuDescStockAdj,
        icon: Icons.tune_rounded,
        accent: AppColors.brand,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const StockAdjustmentsPage(),
        requires: (u) => u.canView('stock'),
      ),
      _MenuItem(
        label: (l) => l.navReturns,
        description: (l) => l.menuDescReturns,
        icon: Icons.assignment_return_outlined,
        accent: AppColors.accentRose,
        accentSoft: AppColors.accentRoseSoft,
        builder: (_) => const MerchantReturnsPage(),
        requires: (u) => u.canView('orders'),
      ),
      _MenuItem(
        label: (l) => l.navReports,
        description: (l) => l.menuDescReports,
        icon: Icons.summarize_outlined,
        accent: AppColors.brandStrong,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const ReportsPage(),
        requires: (u) => u.canView('reports'),
      ),
      _MenuItem(
        label: (l) => l.navAnalytics,
        description: (l) => l.menuDescAnalytics,
        icon: Icons.bar_chart_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const MerchantAnalyticsPage(),
        requires: (u) => u.canView('reports'),
      ),
    ];

List<_MenuItem> get _adminItems => [
      _MenuItem(
        label: (l) => l.navBannerManager,
        description: (l) => l.menuDescBannerManager,
        icon: Icons.view_carousel_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const AdminBannersPage(),
      ),
      _MenuItem(
        label: (l) => l.navCategoryTaxonomy,
        description: (l) => l.menuDescCategoryTaxonomy,
        icon: Icons.account_tree_outlined,
        accent: AppColors.accentTeal,
        accentSoft: AppColors.accentTealSoft,
        builder: (_) => const AdminCategoryTaxonomyPage(),
      ),
      _MenuItem(
        label: (l) => l.navCollections,
        description: (l) => l.menuDescCollections,
        icon: Icons.collections_bookmark_outlined,
        accent: AppColors.accentRose,
        accentSoft: AppColors.accentRoseSoft,
        builder: (_) => const AdminCollectionsPage(),
      ),
      _MenuItem(
        label: (l) => l.navBankOffers,
        description: (l) => l.menuDescBankOffers,
        icon: Icons.account_balance_outlined,
        accent: AppColors.info,
        accentSoft: AppColors.infoSoft,
        builder: (_) => const AdminBankOffersPage(),
      ),
      _MenuItem(
        label: (l) => l.navShopVerification,
        description: (l) => l.menuDescShopVerification,
        icon: Icons.verified_user_outlined,
        accent: AppColors.brandStrong,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const AdminShopsPage(),
      ),
    ];

List<_MenuItem> get _accountItems => [
      _MenuItem(
        label: (l) => l.navProfile,
        description: (l) => l.menuDescProfile,
        icon: Icons.person_outline_rounded,
        accent: AppColors.brand,
        accentSoft: AppColors.brandSoft,
        builder: (_) => const ProfilePage(),
      ),
      _MenuItem(
        label: (l) => l.profileSettings,
        description: (l) => l.menuDescSettings,
        icon: Icons.settings_outlined,
        accent: AppColors.accentIndigo,
        accentSoft: AppColors.accentIndigoSoft,
        builder: (_) => const SettingsPage(),
      ),
    ];

/// The "Menu" bottom-nav tab — every secondary feature grouped into
/// iOS-Settings-style rounded sections (replaces the old slide-out drawer).
class MenuPage extends StatelessWidget {
  const MenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = context.watch<AuthProvider>().user;
    final manage = _manageItems.where((s) => s.visibleTo(user)).toList();
    final ops = _operationItems.where((s) => s.visibleTo(user)).toList();
    final isAdmin = user?.isPlatformAdmin == true;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(
        title: l10n.navMenu,
        actions: [
          const NotificationBell(),
          IconButton(
            tooltip: l10n.navProfile,
            icon: ProfileAvatar(
              name: user?.name ?? '',
              imageUrl: user?.avatarUrl,
              size: 30,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.only(
            top: AppSizes.sm + FloatingAppBar.contentTopInset(context),
            bottom: AppSizes.huge),
        children: [
          if (manage.isNotEmpty)
            _MenuGroup(
              title: l10n.navSectionManage,
              sectionIcon: Icons.work_outline_rounded,
              items: manage,
            ),
          if (ops.isNotEmpty)
            _MenuGroup(
              title: l10n.navSectionOperations,
              sectionIcon: Icons.build_outlined,
              items: ops,
            ),
          if (isAdmin)
            _MenuGroup(
              title: l10n.navSectionPlatformAdmin,
              sectionIcon: Icons.shield_outlined,
              items: _adminItems,
            ),
          _MenuGroup(
            title: l10n.profileSectionAccount,
            sectionIcon: Icons.person_outline_rounded,
            items: _accountItems,
          ),
        ],
      ),
    );
  }
}

/// A titled group of rows inside one rounded surface card (iOS Settings look).
/// The section title carries a small leading icon.
class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.title,
    required this.sectionIcon,
    required this.items,
  });
  final String title;
  final IconData sectionIcon;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        // Divider inset past the icon square, aligned under the label.
        rows.add(const Padding(
          padding: EdgeInsets.only(left: AppSizes.md + 40 + AppSizes.md),
          child: Divider(height: 1),
        ));
      }
      rows.add(_MenuRow(item: items[i]));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSizes.lg, AppSizes.md, AppSizes.lg, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSizes.md, 0, 0, AppSizes.sm),
            child: Row(
              children: [
                Icon(sectionIcon,
                    size: AppSizes.iconSm, color: AppColors.muted),
                const SizedBox(width: AppSizes.sm),
                Text(
                  title.toUpperCase(),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: AppColors.surface,
              shape: AppShapes.squircle(
                AppSizes.radiusMd,
                side: BorderSide(color: AppColors.hairline),
              ),
            ),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final _MenuItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: item.builder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md, vertical: AppSizes.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: ShapeDecoration(
                color: item.accentSoft,
                shape: AppShapes.squircle(10),
              ),
              alignment: Alignment.center,
              child: Icon(item.icon, size: 22, color: item.accent),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.label(l10n),
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppColors.black,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.description(l10n),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.subtle),
          ],
        ),
      ),
    );
  }
}
