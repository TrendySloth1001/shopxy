class Promotion {
  const Promotion({
    required this.id,
    required this.shopId,
    required this.productId,
    required this.productName,
    required this.budgetPaise,
    required this.dailyCapPaise,
    required this.cpmPaise,
    required this.startAt,
    required this.endAt,
    required this.isActive,
    required this.deliveredImpressions,
    required this.spendPaise,
    required this.spendTodayPaise,
    this.pausedReason,
  });

  final int id;
  final int shopId;
  final int productId;
  final String productName;
  final int budgetPaise;
  final int dailyCapPaise;
  final int cpmPaise;
  final DateTime startAt;
  final DateTime endAt;
  final bool isActive;
  final int deliveredImpressions;
  final int spendPaise;
  final int spendTodayPaise;
  final String? pausedReason;

  double get spendPctOfBudget =>
      budgetPaise == 0 ? 0 : (spendPaise / budgetPaise).clamp(0.0, 1.0);
  double get spendPctOfDailyCap =>
      dailyCapPaise == 0
          ? 0
          : (spendTodayPaise / dailyCapPaise).clamp(0.0, 1.0);

  String statusLabel(DateTime now) {
    if (!isActive) {
      switch (pausedReason) {
        case 'budget_exhausted':
          return 'Budget exhausted';
        case 'daily_cap_reached':
          return 'Daily cap reached';
        case 'window_ended':
          return 'Ended';
        case 'cancelled_by_merchant':
          return 'Cancelled';
        default:
          return 'Paused';
      }
    }
    if (now.isBefore(startAt)) return 'Scheduled';
    if (now.isAfter(endAt)) return 'Ended';
    return 'Live';
  }

  factory Promotion.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    return Promotion(
      id: j['id'] as int,
      shopId: j['shopId'] as int,
      productId: j['productId'] as int,
      productName: product?['name'] as String? ?? 'Product #${j['productId']}',
      budgetPaise: j['budgetPaise'] as int,
      dailyCapPaise: j['dailyCapPaise'] as int,
      cpmPaise: j['cpmPaise'] as int,
      startAt: DateTime.parse(j['startAt'] as String),
      endAt: DateTime.parse(j['endAt'] as String),
      isActive: j['isActive'] as bool? ?? true,
      deliveredImpressions: j['deliveredImpressions'] as int? ?? 0,
      spendPaise: j['spendPaise'] as int? ?? 0,
      spendTodayPaise: j['spendTodayPaise'] as int? ?? 0,
      pausedReason: j['pausedReason'] as String?,
    );
  }
}
