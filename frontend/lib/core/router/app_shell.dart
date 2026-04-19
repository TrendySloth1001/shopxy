import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/presentation/pages/categories_page.dart';
import 'package:shopxy/features/challans/presentation/pages/challans_page.dart';
import 'package:shopxy/features/dashboard/presentation/pages/dashboard_page.dart';
import 'package:shopxy/features/invoices/presentation/pages/invoices_page.dart';
import 'package:shopxy/features/products/presentation/pages/products_page.dart';
import 'package:shopxy/features/vendors/presentation/pages/vendors_page.dart';
import 'package:shopxy/shared/constants/app_strings.dart';

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
    final theme = Theme.of(context);

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        backgroundColor: theme.scaffoldBackgroundColor,
        indicatorColor: theme.colorScheme.primaryContainer,
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
    );
  }
}

class _MorePage extends StatelessWidget {
  const _MorePage();

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.logout),
        content: const Text(AppStrings.logoutConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(AppStrings.cancel)),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text(AppStrings.logout),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
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
          // User info tile
          if (user != null)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(user.email, style: theme.textTheme.bodySmall),
            ),
          const Divider(height: 1),
          _MoreTile(
            icon: Icons.category_rounded,
            iconColor: theme.colorScheme.tertiary,
            title: AppStrings.navCategories,
            subtitle: 'Manage product categories',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CategoriesPage()),
            ),
          ),
          _MoreTile(
            icon: Icons.business_rounded,
            iconColor: theme.colorScheme.secondary,
            title: AppStrings.navVendors,
            subtitle: 'Manage suppliers and vendors',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VendorsPage()),
            ),
          ),
          _MoreTile(
            icon: Icons.receipt_long_outlined,
            iconColor: Colors.orange,
            title: AppStrings.navChallans,
            subtitle: 'Party delivery notes without prices',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChallansPage()),
            ),
          ),
          const Divider(height: 1),
          _MoreTile(
            icon: Icons.logout_rounded,
            iconColor: theme.colorScheme.error,
            title: AppStrings.logout,
            subtitle: 'Sign out of your account',
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: onTap,
    );
  }
}
