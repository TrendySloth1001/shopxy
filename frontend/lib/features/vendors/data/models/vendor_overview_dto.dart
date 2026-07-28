import 'package:shopxy/features/vendors/domain/entities/vendor_overview.dart';

class VendorOverviewDto {
  /// Prisma `Decimal` columns serialize to JSON as strings. Funnel every
  /// money/quantity field through this so a stray `String is not num` cast
  /// can never happen.
  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static double? _dn(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static VendorOverview fromJson(Map<String, dynamic> json) {
    final v = json['vendor'] as Map<String, dynamic>;
    final linked = v['linkedUser'] as Map<String, dynamic>?;
    final counts = (json['counts'] as Map<String, dynamic>?) ?? const {};
    final totals = (json['totals'] as List<dynamic>? ?? const [])
        .map((t) => VendorTotal(
              type: (t as Map<String, dynamic>)['type'] as String,
              count: t['count'] as int? ?? 0,
              total: _d(t['total']),
            ))
        .toList();

    return VendorOverview(
      id: v['id'].toString(),
      name: v['name'] as String,
      contactName: v['contactName'] as String?,
      phone: v['phone'] as String?,
      email: v['email'] as String?,
      address: v['address'] as String?,
      city: v['city'] as String?,
      state: v['state'] as String?,
      stateCode: v['stateCode'] as String?,
      pinCode: v['pinCode'] as String?,
      panNumber: v['panNumber'] as String?,
      gstin: v['gstin'] as String?,
      isActive: v['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(v['createdAt'] as String),
      updatedAt: DateTime.parse(v['updatedAt'] as String),
      linkedUser: linked == null
          ? null
          : VendorLinkedUser(
              id: linked['id'].toString(),
              // Name only — the server sends `{id, name, avatarUrl}` and no
              // email by design. Casting one threw the Null-is-not-a-String
              // crash on every linked vendor.
              name: linked['name'] as String? ?? '',
            ),
      invoiceCount: counts['invoices'] as int? ?? 0,
      stockInCount: counts['stockIns'] as int? ?? 0,
      totals: totals,
      recentInvoices: (json['recentInvoices'] as List<dynamic>? ?? const [])
          .map((e) => _invoiceFromJson(e as Map<String, dynamic>))
          .toList(),
      recentStockIns: (json['recentStockIns'] as List<dynamic>? ?? const [])
          .map((e) => _stockInFromJson(e as Map<String, dynamic>))
          .toList(),
      lastActivityAt: json['lastActivityAt'] == null
          ? null
          : DateTime.parse(json['lastActivityAt'] as String),
      balance: _d(json['balance']),
    );
  }

  static VendorInvoiceRef _invoiceFromJson(Map<String, dynamic> j) {
    return VendorInvoiceRef(
      id: j['id'].toString(),
      invoiceNo: j['invoiceNo'] as String,
      type: j['type'] as String,
      status: j['status'] as String,
      invoiceDate: DateTime.parse(j['invoiceDate'] as String),
      total: _d(j['total']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
    );
  }

  static VendorStockInRef _stockInFromJson(Map<String, dynamic> j) {
    final p = j['product'] as Map<String, dynamic>;
    return VendorStockInRef(
      id: j['id'].toString(),
      productId: p['id'].toString(),
      productName: p['name'] as String,
      productSku: p['sku'] as String,
      unit: p['unit'] as String? ?? 'PCS',
      quantity: _d(j['quantity']),
      unitCost: _dn(j['unitCost']),
      totalValue: _dn(j['totalValue']),
      createdAt: DateTime.parse(j['createdAt'] as String),
      reasonCode: j['reasonCode'] as String,
      sourceType: j['sourceType'] as String? ?? 'MANUAL',
    );
  }
}
