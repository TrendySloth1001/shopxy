import 'package:shopxy/features/parties/domain/entities/party_overview.dart';

class PartyOverviewDto {
  /// Prisma `Decimal` columns serialize to JSON as strings. Funnel every
  /// money/quantity field through this so a stray `String is not num` cast
  /// can never happen.
  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static PartyOverview fromJson(Map<String, dynamic> json) {
    final p = json['party'] as Map<String, dynamic>;
    final linked = p['linkedUser'] as Map<String, dynamic>?;
    final counts = (json['counts'] as Map<String, dynamic>?) ?? const {};
    final totals = (json['totals'] as List<dynamic>? ?? const [])
        .map((t) => PartyTotal(
              type: (t as Map<String, dynamic>)['type'] as String,
              count: t['count'] as int? ?? 0,
              total: _d(t['total']),
            ))
        .toList();

    return PartyOverview(
      id: p['id'].toString(),
      name: p['name'] as String,
      contactName: p['contactName'] as String?,
      phone: p['phone'] as String?,
      email: p['email'] as String?,
      address: p['address'] as String?,
      city: p['city'] as String?,
      state: p['state'] as String?,
      stateCode: p['stateCode'] as String?,
      pinCode: p['pinCode'] as String?,
      panNumber: p['panNumber'] as String?,
      gstin: p['gstin'] as String?,
      isActive: p['isActive'] as bool? ?? true,
      isSystem: p['isSystem'] as bool? ?? false,
      createdAt: DateTime.parse(p['createdAt'] as String),
      updatedAt: DateTime.parse(p['updatedAt'] as String),
      linkedUser: linked == null
          ? null
          : PartyLinkedUser(
              id: linked['id'].toString(),
              name: linked['name'] as String,
              email: linked['email'] as String,
            ),
      invoiceCount: counts['invoices'] as int? ?? 0,
      challanCount: counts['challans'] as int? ?? 0,
      totals: totals,
      recentInvoices: (json['recentInvoices'] as List<dynamic>? ?? const [])
          .map((e) => _invoiceFromJson(e as Map<String, dynamic>))
          .toList(),
      recentChallans: (json['recentChallans'] as List<dynamic>? ?? const [])
          .map((e) => _challanFromJson(e as Map<String, dynamic>))
          .toList(),
      lastActivityAt: json['lastActivityAt'] == null
          ? null
          : DateTime.parse(json['lastActivityAt'] as String),
      balance: _d(json['balance']),
    );
  }

  static PartyInvoiceRef _invoiceFromJson(Map<String, dynamic> j) {
    return PartyInvoiceRef(
      id: j['id'].toString(),
      invoiceNo: j['invoiceNo'] as String,
      type: j['type'] as String,
      status: j['status'] as String,
      invoiceDate: DateTime.parse(j['invoiceDate'] as String),
      total: _d(j['total']),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
    );
  }

  static PartyChallanRef _challanFromJson(Map<String, dynamic> j) {
    return PartyChallanRef(
      id: j['id'].toString(),
      challanNo: j['challanNo'] as String,
      status: j['status'] as String,
      createdAt: DateTime.parse(j['createdAt'] as String),
      itemCount: ((j['_count'] as Map?)?['items'] as int?) ?? 0,
      invoiceId: j['invoiceId']?.toString(),
    );
  }
}
