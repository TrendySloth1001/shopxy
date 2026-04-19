import 'package:flutter/material.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/data/models/stock_transaction_dto.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';

class StockProvider extends ChangeNotifier {
  StockProvider(this._dataSource);
  final StockRemoteDataSource _dataSource;

  List<StockTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<StockTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadTransactions({int? productId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await _dataSource.getTransactions(productId: productId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<StockTransaction> addStock({
    required int productId,
    required String type,
    required double quantity,
    double? unitPrice,
    String? supplierName,
    int? vendorId,
    String? purchasePriceMode,
    String? note,
  }) async {
    final data = StockTransactionDto.toCreateJson(
      productId: productId,
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      supplierName: supplierName,
      vendorId: vendorId,
      purchasePriceMode: purchasePriceMode,
      note: note,
    );
    final transaction = await _dataSource.createTransaction(data);
    await loadTransactions(productId: productId);
    return transaction;
  }
}
