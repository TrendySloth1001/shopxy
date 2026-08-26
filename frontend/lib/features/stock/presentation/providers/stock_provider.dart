import 'package:flutter/material.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/data/models/stock_transaction_dto.dart';
import 'package:shopxy/features/stock/domain/entities/stock_transaction.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class StockProvider extends ChangeNotifier {
  StockProvider(this._dataSource);
  final StockRemoteDataSource _dataSource;

  List<StockTransaction> _transactions = [];
  bool _isLoading = false;
  String? _error;

  List<StockTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void reset() {
    _transactions = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  Future<void> loadTransactions({String? productId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await _dataSource.getTransactions(productId: productId);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String> addStock({
    required String productId,
    required String type,
    required double quantity,
    double? unitPrice,
    String? vendorId,
    String? partyId,
    String? note,
  }) async {
    final data = StockTransactionDto.toCreateJson(
      productId: productId,
      type: type,
      quantity: quantity,
      unitPrice: unitPrice,
      vendorId: vendorId,
      partyId: partyId,
      note: note,
    );
    final draftId = await _dataSource.createTransaction(data);
    return draftId;
  }
}
