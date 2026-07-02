// Report entities mirroring the backend `reports` module (`/reports/*`).
// Each report takes a `from`/`to` range and returns confirmed-document totals.
// All money is rupees (a Decimal serialised as a number). Numbers are parsed
// defensively so a Decimal-as-string never crashes a strict `as num` cast.

double _d(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

int _i(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

class ReportSummary {
  const ReportSummary({
    required this.invoiceCount,
    required this.subtotal,
    required this.taxableValue,
    required this.taxAmount,
    required this.total,
    this.refunds = 0,
    this.netRevenue = 0,
    this.refundCount = 0,
  });

  final int invoiceCount;
  final double subtotal;
  final double taxableValue;
  final double taxAmount;
  final double total;

  /// Sales-only: gross refunds (incl. tax) on sales in the period, and the
  /// net revenue (`total − refunds`) that headlines the sales report.
  final double refunds;
  final double netRevenue;
  final int refundCount;

  factory ReportSummary.fromJson(Map<String, dynamic> j) => ReportSummary(
        invoiceCount: _i(j['invoiceCount']),
        subtotal: _d(j['subtotal']),
        taxableValue: _d(j['taxableValue']),
        taxAmount: _d(j['taxAmount']),
        total: _d(j['total']),
        refunds: _d(j['refunds']),
        netRevenue: _d(j['netRevenue']),
        refundCount: _i(j['refundCount']),
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
        invoices: _i(j['invoices']),
        amount: _d(j['revenue']),
        tax: _d(j['tax']),
      );

  factory DailyPoint.purchases(Map<String, dynamic> j) => DailyPoint(
        day: DateTime.parse(j['day'] as String),
        invoices: _i(j['invoices']),
        amount: _d(j['spend']),
        tax: _d(j['tax']),
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
        productId: _i(j['productId']),
        productName: (j['productName'] as String?) ?? 'Product',
        productSku: (j['productSku'] as String?) ?? '',
        quantity: _d(j['quantity']),
        amount: _d(j['revenue']),
      );
  factory TopProduct.purchases(Map<String, dynamic> j) => TopProduct(
        productId: _i(j['productId']),
        productName: (j['productName'] as String?) ?? 'Product',
        productSku: (j['productSku'] as String?) ?? '',
        quantity: _d(j['quantity']),
        amount: _d(j['spend']),
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
        name: (j['name'] as String?) ?? 'Customer',
        amount: _d(j['revenue']),
        invoices: _i(j['invoices']),
      );

  factory TopCounterparty.vendor(Map<String, dynamic> j) => TopCounterparty(
        id: (j['vendorId'] as num?)?.toInt(),
        name: (j['name'] as String?) ?? 'Vendor',
        amount: _d(j['spend']),
        invoices: _i(j['invoices']),
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
        daily: ((j['daily'] as List?) ?? const [])
            .map((e) => DailyPoint.sales(e as Map<String, dynamic>))
            .toList(),
        topProducts: ((j['topProducts'] as List?) ?? const [])
            .map((e) => TopProduct.sales(e as Map<String, dynamic>))
            .toList(),
        topCustomers: ((j['topCustomers'] as List?) ?? const [])
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
        daily: ((j['daily'] as List?) ?? const [])
            .map((e) => DailyPoint.purchases(e as Map<String, dynamic>))
            .toList(),
        topProducts: ((j['topProducts'] as List?) ?? const [])
            .map((e) => TopProduct.purchases(e as Map<String, dynamic>))
            .toList(),
        topVendors: ((j['topVendors'] as List?) ?? const [])
            .map((e) => TopCounterparty.vendor(e as Map<String, dynamic>))
            .toList(),
      );
}

class GstRate {
  const GstRate({
    required this.rate,
    required this.taxable,
    required this.tax,
    this.cess = 0,
  });
  final double rate;
  final double taxable;
  final double tax;
  final double cess;

  factory GstRate.fromJson(Map<String, dynamic> j) => GstRate(
        rate: _d(j['rate']),
        taxable: _d(j['taxable']),
        tax: _d(j['tax']),
        cess: _d(j['cess']),
      );
}

/// IGST / CGST / SGST amounts for one column (output, input, or net).
class GstHead {
  const GstHead({required this.igst, required this.cgst, required this.sgst});
  final double igst;
  final double cgst;
  final double sgst;

  factory GstHead.fromJson(Map<String, dynamic> j) => GstHead(
        igst: _d(j['igst']),
        cgst: _d(j['cgst']),
        sgst: _d(j['sgst']),
      );
}

/// Head-wise split (GSTR-3B view): output / input (ITC) / net payable, each
/// broken into IGST, CGST and SGST.
class GstByHead {
  const GstByHead({
    required this.output,
    required this.input,
    required this.netPayable,
  });
  final GstHead output;
  final GstHead input;
  final GstHead netPayable;

  factory GstByHead.fromJson(Map<String, dynamic> j) => GstByHead(
        output: GstHead.fromJson(j['output'] as Map<String, dynamic>),
        input: GstHead.fromJson(j['input'] as Map<String, dynamic>),
        netPayable: GstHead.fromJson(j['netPayable'] as Map<String, dynamic>),
      );
}

/// Output tax reversed on refunded returns in the period (already netted out
/// of the headline figures).
class GstReturns {
  const GstReturns({
    required this.gst,
    required this.igst,
    required this.cgst,
    required this.sgst,
    required this.cess,
  });
  final double gst;
  final double igst;
  final double cgst;
  final double sgst;
  final double cess;

  factory GstReturns.fromJson(Map<String, dynamic> j) => GstReturns(
        gst: _d(j['gst']),
        igst: _d(j['igst']),
        cgst: _d(j['cgst']),
        sgst: _d(j['sgst']),
        cess: _d(j['cess']),
      );
}

class GstReport {
  const GstReport({
    required this.outputTax,
    required this.inputTax,
    required this.netPayable,
    required this.outputCess,
    required this.inputCess,
    required this.netCessPayable,
    required this.byHead,
    required this.returns,
    required this.outputByRate,
    required this.inputByRate,
  });
  final double outputTax;
  final double inputTax;
  final double netPayable;
  final double outputCess;
  final double inputCess;
  final double netCessPayable;
  final GstByHead? byHead;
  final GstReturns? returns;
  final List<GstRate> outputByRate;
  final List<GstRate> inputByRate;

  factory GstReport.fromJson(Map<String, dynamic> j) => GstReport(
        outputTax: _d(j['outputTax']),
        inputTax: _d(j['inputTax']),
        netPayable: _d(j['netPayable']),
        outputCess: _d(j['outputCess']),
        inputCess: _d(j['inputCess']),
        netCessPayable: _d(j['netCessPayable']),
        byHead: j['byHead'] is Map<String, dynamic>
            ? GstByHead.fromJson(j['byHead'] as Map<String, dynamic>)
            : null,
        returns: j['returns'] is Map<String, dynamic>
            ? GstReturns.fromJson(j['returns'] as Map<String, dynamic>)
            : null,
        outputByRate: ((j['outputByRate'] as List?) ?? const [])
            .map((e) => GstRate.fromJson(e as Map<String, dynamic>))
            .toList(),
        inputByRate: ((j['inputByRate'] as List?) ?? const [])
            .map((e) => GstRate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class PnlReport {
  const PnlReport({
    required this.revenue,
    required this.refunds,
    required this.cogs,
    required this.returnedCogs,
    required this.writeoffs,
    required this.grossProfit,
    required this.netProfit,
    required this.grossMargin,
  });
  final double revenue;
  final double refunds;
  final double cogs;
  final double returnedCogs;
  final double writeoffs;
  final double grossProfit;
  final double netProfit;
  final double grossMargin;

  factory PnlReport.fromJson(Map<String, dynamic> j) => PnlReport(
        revenue: _d(j['revenue']),
        refunds: _d(j['refunds']),
        cogs: _d(j['cogs']),
        returnedCogs: _d(j['returnedCogs']),
        writeoffs: _d(j['writeoffs']),
        grossProfit: _d(j['grossProfit']),
        netProfit: _d(j['netProfit']),
        grossMargin: _d(j['grossMargin']),
      );
}

/// Pagination envelope shared by the P&L "products sold" drill-down endpoints.
class ReportPagination {
  const ReportPagination({
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  factory ReportPagination.fromJson(Map<String, dynamic>? j) => ReportPagination(
        page: _i(j?['page']),
        limit: _i(j?['limit']),
        total: _i(j?['total']),
        totalPages: _i(j?['totalPages']),
      );
}

/// One aggregated product row in the P&L "products sold" summary
/// (`/reports/sold-products`).
class SoldProduct {
  const SoldProduct({
    required this.productId,
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.salesCount,
    required this.totalQuantity,
    required this.totalAmount,
    required this.lastSoldAt,
  });
  final int productId;
  final String? productName;
  final String? productSku;
  final String? unit;
  final int salesCount;
  final double totalQuantity;
  final double totalAmount;
  final DateTime? lastSoldAt;

  factory SoldProduct.fromJson(Map<String, dynamic> j) => SoldProduct(
        productId: _i(j['productId']),
        productName: j['productName'] as String?,
        productSku: j['productSku'] as String?,
        unit: j['unit'] as String?,
        salesCount: _i(j['salesCount']),
        totalQuantity: _d(j['totalQuantity']),
        totalAmount: _d(j['totalAmount']),
        lastSoldAt: DateTime.tryParse((j['lastSoldAt'] as String?) ?? ''),
      );
}

/// Grand totals across every matching product (all pages), for the footer.
class SoldTotals {
  const SoldTotals({
    required this.salesCount,
    required this.totalQuantity,
    required this.totalAmount,
  });
  final int salesCount;
  final double totalQuantity;
  final double totalAmount;

  factory SoldTotals.fromJson(Map<String, dynamic>? j) => SoldTotals(
        salesCount: _i(j?['salesCount']),
        totalQuantity: _d(j?['totalQuantity']),
        totalAmount: _d(j?['totalAmount']),
      );
}

/// Paginated `/reports/sold-products` page (the summary).
class SoldProductsPage {
  const SoldProductsPage({
    required this.data,
    required this.pagination,
    required this.totals,
  });
  final List<SoldProduct> data;
  final ReportPagination pagination;
  final SoldTotals totals;

  factory SoldProductsPage.fromJson(Map<String, dynamic> j) => SoldProductsPage(
        data: ((j['data'] as List?) ?? const [])
            .map((e) => SoldProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination:
            ReportPagination.fromJson(j['pagination'] as Map<String, dynamic>?),
        totals: SoldTotals.fromJson(j['totals'] as Map<String, dynamic>?),
      );
}

/// One confirmed sale line in the P&L "products sold" drill-down
/// (`/reports/sold-items`).
class SoldItem {
  const SoldItem({
    required this.productName,
    required this.productSku,
    required this.unit,
    required this.quantity,
    required this.total,
    required this.invoiceId,
    required this.invoiceNo,
    required this.soldAt,
  });
  final String? productName;
  final String? productSku;
  final String? unit;
  final double quantity;
  final double total;
  final int? invoiceId;
  final String? invoiceNo;
  final DateTime? soldAt;

  factory SoldItem.fromJson(Map<String, dynamic> j) => SoldItem(
        productName: j['productName'] as String?,
        productSku: j['productSku'] as String?,
        unit: j['unit'] as String?,
        quantity: _d(j['quantity']),
        total: _d(j['total']),
        invoiceId: (j['invoiceId'] as num?)?.toInt(),
        invoiceNo: j['invoiceNo'] as String?,
        soldAt: DateTime.tryParse((j['soldAt'] as String?) ?? ''),
      );
}

/// Paginated `/reports/sold-items` page (one product's timeline).
class SoldItemsPage {
  const SoldItemsPage({required this.data, required this.pagination});
  final List<SoldItem> data;
  final ReportPagination pagination;

  factory SoldItemsPage.fromJson(Map<String, dynamic> j) => SoldItemsPage(
        data: ((j['data'] as List?) ?? const [])
            .map((e) => SoldItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        pagination:
            ReportPagination.fromJson(j['pagination'] as Map<String, dynamic>?),
      );
}
