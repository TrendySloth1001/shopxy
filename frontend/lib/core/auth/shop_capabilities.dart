import 'package:shopxy/features/auth/domain/entities/auth_user.dart';

/// The 12 permission areas — mirror of the backend (permissions.ts).
/// Each (except `reports`) has a `:view` and a `:manage` right.
const List<String> kPermissionAreas = [
  'dashboard',
  'products',
  'orders',
  'invoices',
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

/// Areas with no write surface — only `:view` is grantable.
const Set<String> kViewOnlyAreas = {'dashboard', 'reports'};

/// Client-side mirror of the backend permission gate (requireArea /
/// hasRight). The server is the real boundary; these decide what the UI
/// *shows*. Rules, identical to the backend:
///   • OWNER bypasses everything.
///   • `manage` implies `view`.
///   • no grant → denied (fail-closed).
extension ShopCapabilities on AuthUser {
  bool get isShopOwner => shopRole == 'OWNER';

  /// Can the user see this area at all? (view, or manage which implies it)
  bool canView(String area) =>
      isShopOwner ||
      shopPermissions.contains('$area:view') ||
      shopPermissions.contains('$area:manage');

  /// Can the user change things in this area?
  bool canManage(String area) =>
      isShopOwner || shopPermissions.contains('$area:manage');

  // ── Convenience getters used across the merchant UI ───────────────
  bool get canWriteProducts => canManage('products');
  bool get canViewProducts => canView('products');
  bool get canWriteOrders => canManage('orders');
  bool get canViewOrders => canView('orders');
  bool get canWriteInvoices => canManage('invoices');
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
    // Legacy fallback for rows that predate roleName.
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
