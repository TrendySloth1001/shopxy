import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class DashboardStats {
  const DashboardStats({
    required this.totalProducts,
    required this.activeProducts,
    required this.totalCategories,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalStockValue,
    required this.recentTransactions,
  });

  final int totalProducts;
  final int activeProducts;
  final int totalCategories;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalStockValue;
  final List<StockTransaction> recentTransactions;
}
