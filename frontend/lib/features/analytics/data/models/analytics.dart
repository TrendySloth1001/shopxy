class AnalyticsTotals {
  const AnalyticsTotals({
    required this.impressions,
    required this.taps,
    required this.views,
    required this.addToCart,
    required this.purchases,
    required this.wishlistAdd,
    required this.ctr,
    required this.cvr,
  });

  final int impressions;
  final int taps;
  final int views;
  final int addToCart;
  final int purchases;
  final int wishlistAdd;
  final double ctr;
  final double cvr;

  factory AnalyticsTotals.fromJson(Map<String, dynamic> j) => AnalyticsTotals(
        impressions: j['impressions'] as int? ?? 0,
        taps: j['taps'] as int? ?? 0,
        views: j['views'] as int? ?? 0,
        addToCart: j['addToCart'] as int? ?? 0,
        purchases: j['purchases'] as int? ?? 0,
        wishlistAdd: j['wishlistAdd'] as int? ?? 0,
        ctr: (j['ctr'] as num?)?.toDouble() ?? 0,
        cvr: (j['cvr'] as num?)?.toDouble() ?? 0,
      );
}

class ProductAnalyticsRow {
  const ProductAnalyticsRow({
    required this.productId,
    required this.productName,
    required this.impressions,
    required this.taps,
    required this.views,
    required this.addToCart,
    required this.purchases,
    required this.wishlistAdd,
    required this.ctr,
    required this.cvr,
  });

  final int productId;
  final String productName;
  final int impressions;
  final int taps;
  final int views;
  final int addToCart;
  final int purchases;
  final int wishlistAdd;
  final double ctr;
  final double cvr;

  factory ProductAnalyticsRow.fromJson(Map<String, dynamic> j) =>
      ProductAnalyticsRow(
        productId: j['productId'] as int,
        productName: j['productName'] as String,
        impressions: j['impressions'] as int? ?? 0,
        taps: j['taps'] as int? ?? 0,
        views: j['views'] as int? ?? 0,
        addToCart: j['addToCart'] as int? ?? 0,
        purchases: j['purchases'] as int? ?? 0,
        wishlistAdd: j['wishlistAdd'] as int? ?? 0,
        ctr: (j['ctr'] as num?)?.toDouble() ?? 0,
        cvr: (j['cvr'] as num?)?.toDouble() ?? 0,
      );
}

class ProductAnalytics {
  const ProductAnalytics({
    required this.from,
    required this.to,
    required this.totals,
    required this.products,
  });

  final DateTime from;
  final DateTime to;
  final AnalyticsTotals totals;
  final List<ProductAnalyticsRow> products;

  factory ProductAnalytics.fromJson(Map<String, dynamic> j) => ProductAnalytics(
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        totals: AnalyticsTotals.fromJson(j['totals'] as Map<String, dynamic>),
        products: (j['products'] as List<dynamic>)
            .map((e) => ProductAnalyticsRow.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
