import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/dashboard/domain/entities/dashboard_stats.dart';

/// Fetches + parses the v2 dashboard payload. Mirrors the zod schema in
/// `merchant-web/src/features/dashboard/stats.ts`: money sections are
/// nullable, decimals are coerced to doubles.
class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._client);
  final ApiClient _client;

  Future<DashboardStats> getStats(DashboardPeriod period) async {
    final response = await _client.get('/dashboard/stats?period=${period.query}');
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    return DashboardStats(
      onboarding: _onboarding(json['onboarding'] as Map<String, dynamic>?),
      actionQueue: _actionQueue(json['actionQueue'] as Map<String, dynamic>?),
      operations: _operations(json['operations'] as Map<String, dynamic>?),
      alerts: ((json['alerts'] as List?) ?? const [])
          .map((e) => _alert(e as Map<String, dynamic>))
          .toList(),
      recent: ((json['recent'] as List?) ?? const [])
          .map((e) => _transaction(e as Map<String, dynamic>))
          .toList(),
      kpis: _kpis(json['kpis'] as Map<String, dynamic>?),
      trend: _trend(json['trend'] as Map<String, dynamic>?),
      insights: _insights(json['insights'] as Map<String, dynamic>?),
    );
  }

  // ── parsers ─────────────────────────────────────────────────────────

  static DashboardOnboarding _onboarding(Map<String, dynamic>? j) =>
      DashboardOnboarding(
        totalProducts: _int(j?['totalProducts']),
        activeProducts: _int(j?['activeProducts']),
        hasInvoices: (j?['hasInvoices'] as bool?) ?? false,
        hasParties: (j?['hasParties'] as bool?) ?? false,
      );

  static DashboardActionQueue _actionQueue(Map<String, dynamic>? j) =>
      DashboardActionQueue(
        orders: _int(j?['orders']),
        quotations: _int(j?['quotations']),
        returns: _int(j?['returns']),
        drafts: _int(j?['drafts']),
        lowStock: _int(j?['lowStock']),
        outOfStock: _int(j?['outOfStock']),
      );

  static DashboardOperations _operations(Map<String, dynamic>? j) {
    final till = j?['till'] as Map<String, dynamic>?;
    final gst = j?['gstMtd'] as Map<String, dynamic>?;
    return DashboardOperations(
      inventoryValue: _double(j?['inventoryValue']),
      till: till == null
          ? null
          : DashboardTill(
              shiftId: _int(till['shiftId']),
              openedAt: DateTime.parse(till['openedAt'] as String),
              salesCount: _int(till['salesCount']),
              salesGross: _double(till['salesGross']),
              expectedCash: _double(till['expectedCash']),
              tenders: ((till['tenders'] as List?) ?? const [])
                  .map((e) => DashboardTender(
                        mode: (e as Map<String, dynamic>)['mode'] as String,
                        amount: _double(e['amount']),
                        count: _int(e['count']),
                      ))
                  .toList(),
            ),
      gstMtd: gst == null
          ? null
          : DashboardGstMtd(
              monthStart: DateTime.parse(gst['monthStart'] as String),
              outputTax: _double(gst['outputTax']),
              inputTax: _double(gst['inputTax']),
              netPayable: _double(gst['netPayable']),
            ),
    );
  }

  static DashboardAlert _alert(Map<String, dynamic> j) => DashboardAlert(
        id: j['id'] as String,
        severity: switch (j['severity'] as String?) {
          'critical' => AlertSeverity.critical,
          'warning' => AlertSeverity.warning,
          _ => AlertSeverity.info,
        },
        message: j['message'] as String,
        href: (j['href'] as String?) ?? '',
      );

  static DashboardTransaction _transaction(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    return DashboardTransaction(
      id: _int(j['id']),
      productId: _int(j['productId']),
      type: j['type'] as String?,
      direction: j['direction'] as String?,
      quantity: _double(j['quantity']),
      sourceType: j['sourceType'] as String?,
      sourceId: j['sourceId'] as int?,
      createdAt: DateTime.parse(j['createdAt'] as String),
      productName: product?['name'] as String?,
    );
  }

  static DashboardKpis? _kpis(Map<String, dynamic>? j) {
    if (j == null) return null;
    final sales = j['sales'] as Map<String, dynamic>;
    final profit = j['profit'] as Map<String, dynamic>;
    final recv = j['receivables'] as Map<String, dynamic>;
    final pay = j['payables'] as Map<String, dynamic>;
    return DashboardKpis(
      sales: KpiMoney(
        value: _double(sales['value']),
        prev: _double(sales['prev']),
        deltaPct: sales['deltaPct'] as int?,
      ),
      profit: KpiProfit(
        value: _double(profit['value']),
        prev: _double(profit['prev']),
        deltaPct: profit['deltaPct'] as int?,
        margin: _int(profit['margin']),
      ),
      receivables: KpiBalance(
        outstanding: _double(recv['outstanding']),
        count: _int(recv['debtors']),
      ),
      payables: KpiBalance(
        outstanding: _double(pay['outstanding']),
        count: _int(pay['creditors']),
      ),
    );
  }

  static DashboardTrend? _trend(Map<String, dynamic>? j) {
    if (j == null) return null;
    return DashboardTrend(
      labels: ((j['labels'] as List?) ?? const []).cast<String>(),
      sales: _doubleList(j['sales']),
      previous: _doubleList(j['previous']),
      purchases: _doubleList(j['purchases']),
      returns: _doubleList(j['returns']),
      paymentSeries: ((j['paymentSeries'] as List?) ?? const [])
          .map((e) => PaymentSeries(
                mode: (e as Map<String, dynamic>)['mode'] as String,
                values: _doubleList(e['values']),
              ))
          .toList(),
    );
  }

  static DashboardInsights? _insights(Map<String, dynamic>? j) {
    if (j == null) return null;
    return DashboardInsights(
      topProducts: ((j['topProducts'] as List?) ?? const [])
          .map((e) => InsightProduct(
                name: (e as Map<String, dynamic>)['name'] as String,
                revenue: _double(e['revenue']),
                quantity: _double(e['quantity']),
              ))
          .toList(),
      topCategories: ((j['topCategories'] as List?) ?? const [])
          .map((e) => InsightCategory(
                name: (e as Map<String, dynamic>)['name'] as String,
                revenue: _double(e['revenue']),
              ))
          .toList(),
      slowMovers: ((j['slowMovers'] as List?) ?? const [])
          .map((e) => InsightSlowMover(
                name: (e as Map<String, dynamic>)['name'] as String,
                stock: _double(e['stock']),
                sold: _double(e['sold']),
              ))
          .toList(),
    );
  }

  // ── coercion helpers ────────────────────────────────────────────────

  static int _int(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static double _double(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  static List<double> _doubleList(dynamic v) =>
      ((v as List?) ?? const []).map(_double).toList();
}
