import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/parties/presentation/pages/parties_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/stock_adjustments/presentation/pages/stock_adjustments_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_dialog.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_icon_avatar.dart';
import 'package:shopxy/shared/widgets/app_list_tile.dart';
import 'package:shopxy/shared/widgets/app_section_header.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final _pages = const [
    DashboardPage(),
    ProductsPage(),
    InvoicesPage(),
    _MorePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.black, width: 1)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: AppStrings.navDashboard,
            ),
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2_rounded),
              label: AppStrings.navProducts,
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: AppStrings.navInvoices,
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              label: AppStrings.navMore,
            ),
          ],
        ),
      ),
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage();

  Future<void> _logout(BuildContext context) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: AppStrings.logout,
      message: AppStrings.logoutConfirm,
      confirmLabel: AppStrings.logout,
      danger: true,
    );
    if (confirmed && context.mounted) {
      await context.read<AuthProvider>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.navMore)),
      body: ListView(
        children: [
          if (user != null) ...[
            const SizedBox(height: 4),
            AppListTile(
              leading: AppMonogramAvatar(label: user.name, size: 48),
              title: user.name,
              subtitle: user.email,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            const AppDivider.flush(),
          ],
          const AppSectionHeader(title: 'MANAGE'),
          AppListTile(
            leading: const AppIconAvatar.outlined(icon: Icons.category_rounded),
            title: AppStrings.navCategories,
            subtitle: 'Manage product categories',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesPage()),
            ),
          ),
          AppListTile(
            leading: const AppIconAvatar.outlined(icon: Icons.business_rounded),
            title: AppStrings.navVendors,
            subtitle: 'Suppliers you buy from',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorsPage()),
            ),
          ),
          AppListTile(
            leading: const AppIconAvatar.outlined(icon: Icons.groups_rounded),
            title: AppStrings.navParties,
            subtitle: 'Customers you sell to',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PartiesPage()),
            ),
          ),
          AppListTile(
            leading: const AppIconAvatar.outlined(
              icon: Icons.receipt_long_outlined,
            ),
            title: AppStrings.navChallans,
            subtitle: 'Party delivery notes without prices',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChallansPage()),
            ),
          ),
          AppListTile(
            leading: const AppIconAvatar.outlined(icon: Icons.tune_rounded),
            title: 'Stock adjustments',
            subtitle: 'Damage, expired, shrinkage, and count corrections',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StockAdjustmentsPage()),
            ),
          ),
          const SizedBox(height: 8),
          const AppDivider.flush(),
          AppListTile(
            leading: const AppIconAvatar.outlined(icon: Icons.logout_rounded),
            title: AppStrings.logout,
            subtitle: 'Sign out of your account',
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.muted,
            ),
            onTap: () => _logout(context),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text(
              AppStrings.appName,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.muted,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
