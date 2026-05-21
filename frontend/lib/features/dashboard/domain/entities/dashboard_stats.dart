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
    this.draftInvoiceCount = 0,
    this.recentDrafts = const [],
  });

  final int totalProducts;
  final int activeProducts;
  final int totalCategories;
  final int lowStockCount;
  final int outOfStockCount;
  final double totalStockValue;
  final List<StockTransaction> recentTransactions;
  final int draftInvoiceCount;
  final List<DashboardDraftInvoice> recentDrafts;
}

class DashboardDraftInvoice {
  const DashboardDraftInvoice({
    required this.id,
    required this.invoiceNo,
    required this.type,
    required this.total,
    required this.itemCount,
    required this.counterpartyName,
    required this.createdAt,
  });

  final int id;
  final String invoiceNo;
  final String type;
  final double total;
  final int itemCount;
  final String counterpartyName;
  final DateTime createdAt;

  bool get isSale => type == 'SALE';
}
