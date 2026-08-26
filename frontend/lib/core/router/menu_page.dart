import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/shop_capabilities.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_banners_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_category_taxonomy_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_collections_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_shops_page.dart';
import 'package:shopxy/features/auth/domain/entities/auth_user.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/banners/presentation/pages/merchant_banners_page.dart';
import 'package:shopxy/features/cashier/presentation/pages/cashier_page.dart';
import 'package:shopxy/features/notifications/presentation/pages/invitations_page.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/notifications/presentation/widgets/notification_bell.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/products/presentation/pages/hsn_codes_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/coupons/presentation/pages/merchant_coupons_page.dart';
import 'package:shopxy/features/challans/presentation/pages/archived_challans_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/archived_invoices_page.dart';
import 'package:shopxy/features/quotations/presentation/pages/archived_quotations_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoice_settings_page.dart';
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
import 'package:shopxy/shared/widgets/section_divider.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';

class _MenuItem {
  const _MenuItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.accentSoft,
    required this.builder,
    this.requires,
    this.badgeCount,
  });
  final String Function(AppLocalizations l10n) label;
  final String Function(AppLocalizations l10n) description;
  final AppIconData icon;
  final Color accent;
  final Color accentSoft;
  final WidgetBuilder builder;
  final bool Function(AuthUser user)? requires;

  final int Function(BuildContext context)? badgeCount;

  bool visibleTo(AuthUser? user) =>
      requires == null || (user != null && requires!(user));
}

List<_MenuItem> get _manageItems => [
  _MenuItem(
    label: (l) => l.navMyShop,
    description: (l) => l.menuDescMyShop,
    icon: AppIcons.storefrontOutlined,
    accent: AppColors.brand,
    accentSoft: AppColors.brandSoft,
    builder: (_) => const ShopProfilePage(),
    requires: (u) => u.canView('shop'),
  ),
  _MenuItem(
    label: (l) => l.navTeamRoles,
    description: (l) => l.menuDescTeam,
    icon: AppIcons.groups2Outlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const ShopTeamPage(),
    requires: (u) => u.canView('team'),
  ),
  _MenuItem(
    label: (l) => l.invitationsTitle,
    description: (l) => l.menuDescInvitations,
    icon: AppIcons.markEmailUnreadOutlined,
    accent: AppColors.accentTeal,
    accentSoft: AppColors.accentTealSoft,
    builder: (_) => const InvitationsPage(),
    requires: (u) => u.canView('parties') || u.canView('vendors'),
    badgeCount: (c) => c.select<NotificationsProvider, int>(
      (p) => p.pendingIncoming.length,
    ),
  ),
  _MenuItem(
    label: (l) => l.navCategories,
    description: (l) => l.menuDescCategories,
    icon: AppIcons.categoryOutlined,
    accent: AppColors.accentTeal,
    accentSoft: AppColors.accentTealSoft,
    builder: (_) => const CategoriesPage(),
    requires: (u) => u.canView('products'),
  ),
  _MenuItem(
    label: (l) => l.hsnCodesTitle,
    description: (l) => l.menuDescHsn,
    icon: AppIcons.percentRounded,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const HsnCodesPage(),
    requires: (u) => u.canView('products'),
  ),
  _MenuItem(
    label: (l) => l.profileInvoiceSettingsTitle,
    description: (l) => l.menuDescInvoiceSettings,
    icon: AppIcons.receiptLongOutlined,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const InvoiceSettingsPage(),
    requires: (u) => u.canView('invoices'),
  ),
  _MenuItem(
    label: (l) => l.navVendors,
    description: (l) => l.menuDescVendors,
    icon: AppIcons.storefrontOutlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const VendorsPage(),
    requires: (u) => u.canView('vendors'),
  ),
  _MenuItem(
    label: (l) => l.navParties,
    description: (l) => l.menuDescParties,
    icon: AppIcons.groupsOutlined,
    accent: AppColors.accentRose,
    accentSoft: AppColors.accentRoseSoft,
    builder: (_) => const PartiesPage(),
    requires: (u) => u.canView('parties'),
  ),
  _MenuItem(
    label: (l) => l.navBanners,
    description: (l) => l.menuDescBanners,
    icon: AppIcons.imageOutlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const MerchantBannersPage(),
    requires: (u) => u.canView('marketing'),
  ),
  _MenuItem(
    label: (l) => l.navCoupons,
    description: (l) => l.menuDescCoupons,
    icon: AppIcons.localOfferOutlined,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const MerchantCouponsPage(),
    requires: (u) => u.canView('marketing'),
  ),
];

List<_MenuItem> get _operationItems => [
  _MenuItem(
    label: (l) => l.navPointOfSale,
    description: (l) => l.menuDescPos,
    icon: AppIcons.pointOfSaleRounded,
    accent: AppColors.brand,
    accentSoft: AppColors.brandSoft,
    builder: (_) => const PosPage(),
    requires: (u) => u.canView('invoices'),
  ),
  _MenuItem(
    label: (l) => l.navCashier,
    description: (l) => l.menuDescCashier,
    icon: AppIcons.calculateOutlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const CashierPage(),
    requires: (u) => u.canView('invoices'),
  ),
  _MenuItem(
    label: (l) => l.navScanToConsole,
    description: (l) => l.menuDescScan,
    icon: AppIcons.qrCodeScannerRounded,
    accent: AppColors.accentTeal,
    accentSoft: AppColors.accentTealSoft,
    builder: (_) => const ScanConsolePage(),
    requires: (u) => u.canView('products'),
  ),
  _MenuItem(
    label: (l) => l.navQuotations,
    description: (l) => l.menuDescQuotations,
    icon: AppIcons.requestQuoteOutlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const QuotationsPage(),
    requires: (u) => u.canView('quotations'),
  ),
  _MenuItem(
    label: (l) => l.navArchivedInvoices,
    description: (l) => l.menuDescArchivedInvoices,
    icon: AppIcons.archiveOutlined,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const ArchivedInvoicesPage(),
    requires: (u) => u.canView('invoices'),
  ),
  _MenuItem(
    label: (l) => l.navArchivedChallans,
    description: (l) => l.menuDescArchivedChallans,
    icon: AppIcons.archiveOutlined,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const ArchivedChallansPage(),
    requires: (u) => u.canView('challans'),
  ),
  _MenuItem(
    label: (l) => l.navArchivedQuotations,
    description: (l) => l.menuDescArchivedQuotations,
    icon: AppIcons.archiveOutlined,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const ArchivedQuotationsPage(),
    requires: (u) => u.canView('quotations'),
  ),
  _MenuItem(
    label: (l) => l.navChallans,
    description: (l) => l.menuDescChallans,
    icon: AppIcons.assignmentOutlined,
    accent: AppColors.accentAmber,
    accentSoft: AppColors.accentAmberSoft,
    builder: (_) => const ChallansPage(),
    requires: (u) => u.canView('challans'),
  ),
  _MenuItem(
    label: (l) => l.navStockAdjustments,
    description: (l) => l.menuDescStockAdj,
    icon: AppIcons.tuneRounded,
    accent: AppColors.brand,
    accentSoft: AppColors.brandSoft,
    builder: (_) => const StockAdjustmentsPage(),
    requires: (u) => u.canView('stock'),
  ),
  _MenuItem(
    label: (l) => l.navReturns,
    description: (l) => l.menuDescReturns,
    icon: AppIcons.assignmentReturnOutlined,
    accent: AppColors.accentRose,
    accentSoft: AppColors.accentRoseSoft,
    builder: (_) => const MerchantReturnsPage(),
    requires: (u) => u.canView('orders'),
  ),
  _MenuItem(
    label: (l) => l.navReports,
    description: (l) => l.menuDescReports,
    icon: AppIcons.summarizeOutlined,
    accent: AppColors.brandStrong,
    accentSoft: AppColors.brandSoft,
    builder: (_) => const ReportsPage(),
    requires: (u) => u.canView('reports'),
  ),
];

List<_MenuItem> get _adminItems => [
  _MenuItem(
    label: (l) => l.navBannerManager,
    description: (l) => l.menuDescBannerManager,
    icon: AppIcons.viewCarouselOutlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const AdminBannersPage(),
  ),
  _MenuItem(
    label: (l) => l.navCategoryTaxonomy,
    description: (l) => l.menuDescCategoryTaxonomy,
    icon: AppIcons.accountTreeOutlined,
    accent: AppColors.accentTeal,
    accentSoft: AppColors.accentTealSoft,
    builder: (_) => const AdminCategoryTaxonomyPage(),
  ),
  _MenuItem(
    label: (l) => l.navCollections,
    description: (l) => l.menuDescCollections,
    icon: AppIcons.collectionsBookmarkOutlined,
    accent: AppColors.accentRose,
    accentSoft: AppColors.accentRoseSoft,
    builder: (_) => const AdminCollectionsPage(),
  ),
  _MenuItem(
    label: (l) => l.navShopVerification,
    description: (l) => l.menuDescShopVerification,
    icon: AppIcons.verifiedUserOutlined,
    accent: AppColors.brandStrong,
    accentSoft: AppColors.brandSoft,
    builder: (_) => const AdminShopsPage(),
  ),
];

List<_MenuItem> get _accountItems => [
  _MenuItem(
    label: (l) => l.navProfile,
    description: (l) => l.menuDescProfile,
    icon: AppIcons.personOutlineRounded,
    accent: AppColors.brand,
    accentSoft: AppColors.brandSoft,
    builder: (_) => const ProfilePage(),
  ),
  _MenuItem(
    label: (l) => l.profileSettings,
    description: (l) => l.menuDescSettings,
    icon: AppIcons.settingsOutlined,
    accent: AppColors.accentIndigo,
    accentSoft: AppColors.accentIndigoSoft,
    builder: (_) => const SettingsPage(),
  ),
];

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  State<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage> {
  final _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
  }

  @override
  void dispose() {
    _scrollHaptics.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

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
        controller: _scrollCtrl,
        padding: EdgeInsets.only(
          top: AppSizes.sm + FloatingAppBar.contentTopInset(context),
          bottom: FloatingBottomNav.contentBottomInset(context) + AppSizes.sm,
        ),
        children: [
          if (manage.isNotEmpty)
            _MenuGroup(
              title: l10n.navSectionManage,
              sectionIcon: AppIcons.workOutlineRounded,
              items: manage,
            ),
          if (ops.isNotEmpty)
            _MenuGroup(
              title: l10n.navSectionOperations,
              sectionIcon: AppIcons.buildOutlined,
              items: ops,
            ),
          if (isAdmin)
            _MenuGroup(
              title: l10n.navSectionPlatformAdmin,
              sectionIcon: AppIcons.shieldOutlined,
              items: _adminItems,
            ),
          _MenuGroup(
            title: l10n.profileSectionAccount,
            sectionIcon: AppIcons.personOutlineRounded,
            items: _accountItems,
          ),
        ],
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({
    required this.title,
    required this.sectionIcon,
    required this.items,
  });
  final String title;
  final AppIconData sectionIcon;
  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        rows.add(
          const Padding(
            padding: EdgeInsets.only(left: AppSizes.md + 40 + AppSizes.md),
            child: Divider(height: 1),
          ),
        );
      }
      rows.add(_MenuRow(item: items[i]));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSizes.sm),
            child: SectionDivider(label: title, icon: sectionIcon),
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
    final badge = item.badgeCount?.call(context) ?? 0;
    return InkWell(
      onTap: () {
        AppHaptics.selection();
        Navigator.push(context, MaterialPageRoute(builder: item.builder));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.md,
        ),
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
              child: AppIcon(item.icon, size: 22, color: item.accent),
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
                  const SizedBox(height: AppSizes.xxs),
                  Text(
                    item.description(l10n),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            if (badge > 0) ...[
              _MenuBadge(count: badge),
              const SizedBox(width: AppSizes.sm),
            ],
            AppIcon(
              AppIcons.chevronRightRounded,
              size: 20,
              color: AppColors.subtle,
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuBadge extends StatelessWidget {
  const _MenuBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: AppSizes.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.xs,
        vertical: AppSizes.xxs,
      ),
      decoration: ShapeDecoration(
        color: AppColors.error,
        shape: AppShapes.squircle(AppSizes.radiusFull),
      ),
      alignment: Alignment.center,
      child: Text(
        count > 99 ? '99+' : '$count',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          height: 1.1,
        ),
      ),
    );
  }
}
