import 'package:shopxy/features/auth/domain/entities/auth_user.dart';

const List<String> kPermissionAreas = [
  'dashboard',
  'products',
  'orders',
  'invoices',
  'quotations',
  'challans',
  'payments',
  'parties',
  'stock',
  'vendors',
  'marketing',
  'shop',
  'reports',
  'payouts',
  'team',
];

const Set<String> kViewOnlyAreas = {'dashboard', 'reports'};

extension ShopCapabilities on AuthUser {
  bool get isShopOwner => shopRole == 'OWNER';

  bool canView(String area) =>
      isShopOwner ||
      shopPermissions.contains('$area:view') ||
      shopPermissions.contains('$area:manage');

  bool canManage(String area) =>
      isShopOwner || shopPermissions.contains('$area:manage');

  bool get canWriteProducts => canManage('products');
  bool get canViewProducts => canView('products');
  bool get canWriteOrders => canManage('orders');
  bool get canViewOrders => canView('orders');
  bool get canWriteInvoices => canManage('invoices');
  bool get canViewQuotations => canView('quotations');
  bool get canWriteQuotations => canManage('quotations');
  bool get canViewChallans => canView('challans');
  bool get canWriteChallans => canManage('challans');
  bool get canWritePayments => canManage('payments');
  bool get canWriteParties => canManage('parties');
  bool get canWriteStock => canManage('stock');
  bool get canWriteVendors => canManage('vendors');
  bool get canWriteMarketing => canManage('marketing');
  bool get canWriteShop => canManage('shop');
  bool get canViewReports => canView('reports');
  bool get canManageBilling => canManage('payouts');
  bool get canViewBilling => canView('payouts');
  bool get canViewTeam => canView('team');
  bool get canManageTeam => canManage('team');

  String get shopRoleLabel {
    if (shopRole == 'OWNER') return 'Owner';
    final name = shopRoleName?.trim();
    if (name != null && name.isNotEmpty) return name;
    switch (shopRole) {
      case 'MANAGER':
        return 'Manager';
      case 'STOCKIST':
        return 'Stockist';
      case 'CASHIER':
        return 'Cashier';
      default:
        return 'Staff';
    }
  }
}
