/// Dashboard payload, mirroring the backend `GET /dashboard/stats?period=…`
/// response (`backend/src/modules/dashboard/dashboard.service.ts`) and the
/// web client (`merchant-web/src/features/dashboard/stats.ts`).
///
/// Money sections (`kpis`, `trend`, `insights`, `operations.gstMtd`) are null
/// unless the caller holds `reports:view`.
library;

/// Rolling window the period-scoped figures cover.
enum DashboardPeriod {
  today,
  week,
  month;

  /// Backend query value (`?period=`).
  String get query => name;

  /// Segmented-control label.
  String get label => switch (this) {
        DashboardPeriod.today => 'Today',
        DashboardPeriod.week => '7 days',
        DashboardPeriod.month => '30 days',
      };

  /// Phrase used in delta-chip alternatives ("versus …").
  String get prevPhrase => switch (this) {
        DashboardPeriod.today => 'the previous day',
        DashboardPeriod.week => 'the previous 7 days',
        DashboardPeriod.month => 'the previous 30 days',
      };

  static DashboardPeriod fromName(String? value) {
    return DashboardPeriod.values.firstWhere(
      (p) => p.name == value,
      orElse: () => DashboardPeriod.today,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.onboarding,
    required this.actionQueue,
    required this.operations,
    required this.alerts,
    required this.recent,
    this.kpis,
    this.trend,
    this.insights,
  });

  final DashboardOnboarding onboarding;
  final DashboardActionQueue actionQueue;
  final DashboardOperations operations;
  final List<DashboardAlert> alerts;
  final List<DashboardTransaction> recent;

  /// Null without `reports:view`.
  final DashboardKpis? kpis;
  final DashboardTrend? trend;
  final DashboardInsights? insights;

  /// A fresh shop gets guidance, not a wall of zeros.
  bool get isFresh => !onboarding.hasInvoices && onboarding.totalProducts == 0;
}

class DashboardOnboarding {
  const DashboardOnboarding({
    required this.totalProducts,
    required this.activeProducts,
    required this.hasInvoices,
    required this.hasParties,
  });

  final int totalProducts;
  final int activeProducts;
  final bool hasInvoices;
  final bool hasParties;
}

class DashboardActionQueue {
  const DashboardActionQueue({
    required this.orders,
    required this.quotations,
    required this.returns,
    required this.drafts,
    required this.lowStock,
    required this.outOfStock,
  });

  final int orders;
  final int quotations;
  final int returns;
  final int drafts;
  final int lowStock;
  final int outOfStock;
}

class DashboardOperations {
  const DashboardOperations({
    required this.inventoryValue,
    this.till,
    this.gstMtd,
  });

  final double inventoryValue;
  final DashboardTill? till;
  final DashboardGstMtd? gstMtd;
}

class DashboardTill {
  const DashboardTill({
    required this.shiftId,
    required this.openedAt,
    required this.salesCount,
    required this.salesGross,
    required this.expectedCash,
    required this.tenders,
  });

  final int shiftId;
  final DateTime openedAt;
  final int salesCount;
  final double salesGross;
  final double expectedCash;
  final List<DashboardTender> tenders;
}

class DashboardTender {
  const DashboardTender({
    required this.mode,
    required this.amount,
    required this.count,
  });

  final String mode;
  final double amount;
  final int count;
}

class DashboardGstMtd {
  const DashboardGstMtd({
    required this.monthStart,
    required this.outputTax,
    required this.inputTax,
    required this.netPayable,
  });

  final DateTime monthStart;
  final double outputTax;
  final double inputTax;
  final double netPayable;
}

class DashboardAlert {
  const DashboardAlert({
    required this.id,
    required this.severity,
    required this.message,
    required this.href,
  });

  final String id;
  final AlertSeverity severity;
  final String message;
  final String href;
}

enum AlertSeverity { critical, warning, info }

class DashboardTransaction {
  const DashboardTransaction({
    required this.id,
    required this.productId,
    this.type,
    this.direction,
    required this.quantity,
    this.sourceType,
    this.sourceId,
    required this.createdAt,
    this.productName,
  });

  final String id;
  final String productId;
  final String? type;
  final String? direction;
  final double quantity;
  final String? sourceType;
  final String? sourceId;
  final DateTime createdAt;
  final String? productName;

  bool get isIn => direction == 'IN' || type == 'STOCK_IN';
  bool get isOut => direction == 'OUT' || type == 'STOCK_OUT';

  bool get hasSourceDocument =>
      sourceId != null &&
      (sourceType == 'INVOICE' || sourceType == 'CHALLAN');
}

// ── Money sections (reports:view only) ────────────────────────────────

class DashboardKpis {
  const DashboardKpis({
    required this.sales,
    required this.profit,
    required this.receivables,
    required this.payables,
  });

  final KpiMoney sales;
  final KpiProfit profit;
  final KpiBalance receivables;
  final KpiBalance payables;
}

class KpiMoney {
  const KpiMoney({required this.value, required this.prev, this.deltaPct});
  final double value;
  final double prev;
  final int? deltaPct;
}

class KpiProfit {
  const KpiProfit({
    required this.value,
    required this.prev,
    this.deltaPct,
    required this.margin,
  });
  final double value;
  final double prev;
  final int? deltaPct;
  final int margin;
}

class KpiBalance {
  const KpiBalance({required this.outstanding, required this.count});
  final double outstanding;

  /// debtors (receivables) / creditors (payables).
  final int count;
}

class DashboardTrend {
  const DashboardTrend({
    required this.labels,
    required this.sales,
    required this.previous,
    required this.purchases,
    required this.returns,
    required this.paymentSeries,
  });

  final List<String> labels;
  final List<double> sales;
  final List<double> previous;
  final List<double> purchases;
  final List<double> returns;
  final List<PaymentSeries> paymentSeries;
}

class PaymentSeries {
  const PaymentSeries({required this.mode, required this.values});
  final String mode;
  final List<double> values;
}

class DashboardInsights {
  const DashboardInsights({
    required this.topProducts,
    required this.topCategories,
    required this.slowMovers,
  });

  final List<InsightProduct> topProducts;
  final List<InsightCategory> topCategories;
  final List<InsightSlowMover> slowMovers;
}

class InsightProduct {
  const InsightProduct({
    required this.name,
    required this.revenue,
    required this.quantity,
  });
  final String name;
  final double revenue;
  final double quantity;
}

class InsightCategory {
  const InsightCategory({required this.name, required this.revenue});
  final String name;
  final double revenue;
}

class InsightSlowMover {
  const InsightSlowMover({
    required this.name,
    required this.stock,
    required this.sold,
  });
  final String name;
  final double stock;
  final double sold;
}
