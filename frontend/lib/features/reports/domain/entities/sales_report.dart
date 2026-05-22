class ReportSummary {
  const ReportSummary({
    required this.invoiceCount,
    required this.subtotal,
    required this.taxAmount,
    required this.discount,
    required this.total,
  });

  final int invoiceCount;
  final double subtotal;
  final double taxAmount;
  final double discount;
  final double total;

  factory ReportSummary.fromJson(Map<String, dynamic> j) => ReportSummary(
        invoiceCount: (j['invoiceCount'] as num).toInt(),
        subtotal: (j['subtotal'] as num).toDouble(),
        taxAmount: (j['taxAmount'] as num).toDouble(),
        discount: (j['discount'] as num).toDouble(),
        total: (j['total'] as num).toDouble(),
      );
}

class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.invoices,
    required this.amount,
    required this.tax,
  });
  final DateTime day;
  final int invoices;
  final double amount;
  final double tax;

  factory DailyPoint.sales(Map<String, dynamic> j) => DailyPoint(
        day: DateTime.parse(j['day'] as String),
        invoices: (j['invoices'] as num).toInt(),
        amount: (j['revenue'] as num).toDouble(),
        tax: (j['tax'] as num).toDouble(),
      );

  factory DailyPoint.purchases(Map<String, dynamic> j) => DailyPoint(
        day: DateTime.parse(j['day'] as String),
        invoices: (j['invoices'] as num).toInt(),
        amount: (j['spend'] as num).toDouble(),
        tax: (j['tax'] as num).toDouble(),
      );
}

class TopProduct {
  const TopProduct({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.quantity,
    required this.amount,
  });
  final int productId;
  final String productName;
  final String productSku;
  final double quantity;
  final double amount;

  factory TopProduct.sales(Map<String, dynamic> j) => TopProduct(
        productId: (j['productId'] as num).toInt(),
        productName: j['productName'] as String,
        productSku: j['productSku'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        amount: (j['revenue'] as num).toDouble(),
      );
  factory TopProduct.purchases(Map<String, dynamic> j) => TopProduct(
        productId: (j['productId'] as num).toInt(),
        productName: j['productName'] as String,
        productSku: j['productSku'] as String,
        quantity: (j['quantity'] as num).toDouble(),
        amount: (j['spend'] as num).toDouble(),
      );
}

class TopCounterparty {
  const TopCounterparty({
    required this.id,
    required this.name,
    required this.amount,
    required this.invoices,
  });
  final int? id;
  final String name;
  final double amount;
  final int invoices;

  factory TopCounterparty.customer(Map<String, dynamic> j) => TopCounterparty(
        id: (j['partyId'] as num?)?.toInt(),
        name: j['name'] as String,
        amount: (j['revenue'] as num).toDouble(),
        invoices: (j['invoices'] as num).toInt(),
      );

  factory TopCounterparty.vendor(Map<String, dynamic> j) => TopCounterparty(
        id: (j['vendorId'] as num?)?.toInt(),
        name: j['name'] as String,
        amount: (j['spend'] as num).toDouble(),
        invoices: (j['invoices'] as num).toInt(),
      );
}

class SalesReport {
  const SalesReport({
    required this.summary,
    required this.daily,
    required this.topProducts,
    required this.topCustomers,
  });
  final ReportSummary summary;
  final List<DailyPoint> daily;
  final List<TopProduct> topProducts;
  final List<TopCounterparty> topCustomers;

  factory SalesReport.fromJson(Map<String, dynamic> j) => SalesReport(
        summary: ReportSummary.fromJson(j['summary'] as Map<String, dynamic>),
        daily: (j['daily'] as List)
            .map((e) => DailyPoint.sales(e as Map<String, dynamic>))
            .toList(),
        topProducts: (j['topProducts'] as List)
            .map((e) => TopProduct.sales(e as Map<String, dynamic>))
            .toList(),
        topCustomers: (j['topCustomers'] as List)
            .map((e) => TopCounterparty.customer(e as Map<String, dynamic>))
            .toList(),
      );
}

class PurchasesReport {
  const PurchasesReport({
    required this.summary,
    required this.daily,
    required this.topProducts,
    required this.topVendors,
  });
  final ReportSummary summary;
  final List<DailyPoint> daily;
  final List<TopProduct> topProducts;
  final List<TopCounterparty> topVendors;

  factory PurchasesReport.fromJson(Map<String, dynamic> j) => PurchasesReport(
        summary: ReportSummary.fromJson(j['summary'] as Map<String, dynamic>),
        daily: (j['daily'] as List)
            .map((e) => DailyPoint.purchases(e as Map<String, dynamic>))
            .toList(),
        topProducts: (j['topProducts'] as List)
            .map((e) => TopProduct.purchases(e as Map<String, dynamic>))
            .toList(),
        topVendors: (j['topVendors'] as List)
            .map((e) => TopCounterparty.vendor(e as Map<String, dynamic>))
            .toList(),
      );
}

class GstRate {
  const GstRate({required this.rate, required this.taxable, required this.tax});
  final double rate;
  final double taxable;
  final double tax;

  factory GstRate.fromJson(Map<String, dynamic> j) => GstRate(
        rate: (j['rate'] as num).toDouble(),
        taxable: (j['taxable'] as num).toDouble(),
        tax: (j['tax'] as num).toDouble(),
      );
}

class GstReport {
  const GstReport({
    required this.outputTax,
    required this.inputTax,
    required this.netPayable,
    required this.outputByRate,
    required this.inputByRate,
  });
  final double outputTax;
  final double inputTax;
  final double netPayable;
  final List<GstRate> outputByRate;
  final List<GstRate> inputByRate;

  factory GstReport.fromJson(Map<String, dynamic> j) => GstReport(
        outputTax: (j['outputTax'] as num).toDouble(),
        inputTax: (j['inputTax'] as num).toDouble(),
        netPayable: (j['netPayable'] as num).toDouble(),
        outputByRate: (j['outputByRate'] as List)
            .map((e) => GstRate.fromJson(e as Map<String, dynamic>))
            .toList(),
        inputByRate: (j['inputByRate'] as List)
            .map((e) => GstRate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PnlReport {
  const PnlReport({
    required this.revenue,
    required this.cogs,
    required this.writeoffs,
    required this.grossProfit,
    required this.netProfit,
    required this.grossMargin,
  });
  final double revenue;
  final double cogs;
  final double writeoffs;
  final double grossProfit;
  final double netProfit;
  final double grossMargin;

  factory PnlReport.fromJson(Map<String, dynamic> j) => PnlReport(
        revenue: (j['revenue'] as num).toDouble(),
        cogs: (j['cogs'] as num).toDouble(),
        writeoffs: (j['writeoffs'] as num).toDouble(),
        grossProfit: (j['grossProfit'] as num).toDouble(),
        netProfit: (j['netProfit'] as num).toDouble(),
        grossMargin: (j['grossMargin'] as num).toDouble(),
      );
}
