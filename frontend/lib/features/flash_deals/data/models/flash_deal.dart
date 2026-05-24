enum FlashDealStatus { active, scheduled, past }

extension FlashDealStatusX on FlashDealStatus {
  String get wire {
    switch (this) {
      case FlashDealStatus.active:
        return 'active';
      case FlashDealStatus.scheduled:
        return 'scheduled';
      case FlashDealStatus.past:
        return 'past';
    }
  }

  String get label {
    switch (this) {
      case FlashDealStatus.active:
        return 'Live';
      case FlashDealStatus.scheduled:
        return 'Scheduled';
      case FlashDealStatus.past:
        return 'Past';
    }
  }
}

class FlashDealProductRef {
  const FlashDealProductRef({
    required this.id,
    required this.name,
    required this.sku,
    required this.mrp,
    required this.sellingPrice,
    this.imageUrl,
  });

  final int id;
  final String name;
  final String sku;
  final double mrp;
  final double sellingPrice;
  final String? imageUrl;

  factory FlashDealProductRef.fromJson(Map<String, dynamic> j) {
    final imgs = j['images'] as List<dynamic>?;
    return FlashDealProductRef(
      id: j['id'] as int,
      name: j['name'] as String,
      sku: j['sku'] as String,
      mrp: _toDouble(j['mrp']),
      sellingPrice: _toDouble(j['sellingPrice']),
      imageUrl: (imgs != null && imgs.isNotEmpty)
          ? (imgs.first as Map<String, dynamic>)['url'] as String?
          : null,
    );
  }
}

class FlashDeal {
  const FlashDeal({
    required this.id,
    required this.productId,
    required this.flashPrice,
    required this.stockLimit,
    required this.soldCount,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    this.product,
  });

  final int id;
  final int productId;
  final double flashPrice;
  final int stockLimit;
  final int soldCount;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;
  final FlashDealProductRef? product;

  /// 0..1, clamped. The merchant list uses this for the progress bar
  /// and the customer card mirrors the same math.
  double get soldPct {
    if (stockLimit <= 0) return 1;
    return (soldCount / stockLimit).clamp(0.0, 1.0);
  }

  int get discountPct {
    if (product == null || product!.mrp <= 0) return 0;
    return (((product!.mrp - flashPrice) / product!.mrp) * 100).round();
  }

  FlashDealStatus derivedStatus(DateTime now) {
    if (!isActive) return FlashDealStatus.past;
    if (startAt.isAfter(now)) return FlashDealStatus.scheduled;
    if (endAt.isBefore(now)) return FlashDealStatus.past;
    return FlashDealStatus.active;
  }

  factory FlashDeal.fromJson(Map<String, dynamic> j) => FlashDeal(
        id: j['id'] as int,
        productId: j['productId'] as int,
        flashPrice: _toDouble(j['flashPrice']),
        stockLimit: j['stockLimit'] as int,
        soldCount: (j['soldCount'] as int?) ?? 0,
        startAt: DateTime.parse(j['startAt'] as String),
        endAt: DateTime.parse(j['endAt'] as String),
        isActive: (j['isActive'] as bool?) ?? true,
        product: j['product'] != null
            ? FlashDealProductRef.fromJson(
                j['product'] as Map<String, dynamic>,
              )
            : null,
      );
}

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}
