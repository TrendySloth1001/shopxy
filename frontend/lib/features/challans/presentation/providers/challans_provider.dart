import 'package:flutter/material.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/data/models/challan_dto.dart';
import 'package:shopxy/features/challans/domain/entities/challan.dart';

class ChallansProvider extends ChangeNotifier {
  ChallansProvider(this._dataSource);
  final ChallansRemoteDataSource _dataSource;

  List<Challan> _challans = [];
  bool _isLoading = false;
  String? _error;
  int _total = 0;
  String? _statusFilter;
  String _search = '';

  List<Challan> get challans => _challans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get total => _total;
  String? get statusFilter => _statusFilter;
  String get search => _search;

  void setStatus(String? status) {
    _statusFilter = status;
    loadChallans();
  }

  void setSearch(String value) {
    _search = value;
    loadChallans();
  }

  Future<void> loadChallans({bool refresh = true}) async {
    _isLoading = true;
    _error = null;
    if (refresh) notifyListeners();

    try {
      final result = await _dataSource.listChallans(
        status: _statusFilter,
        search: _search.isNotEmpty ? _search : null,
      );
      _challans = result.challans;
      _total = result.total;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Challan> createChallan({
    required String partyName,
    String? partyPhone,
    String? note,
    required List<ChallanItemDraft> items,
  }) async {
    final data = ChallanDto.toCreateJson(
      partyName: partyName,
      partyPhone: partyPhone,
      note: note,
      items: items,
    );
    final challan = await _dataSource.createChallan(data);
    await loadChallans();
    return challan;
  }

  Future<void> cancelChallan(int id) async {
    await _dataSource.cancelChallan(id);
    await loadChallans();
  }

  Future<Map<String, dynamic>> convertToInvoice(
    int id, {
    String? customerName,
    String? customerGstin,
    double? discount,
    String? note,
  }) async {
    final data = ChallanDto.toConvertJson(
      customerName: customerName,
      customerGstin: customerGstin,
      discount: discount,
      note: note,
    );
    final invoice = await _dataSource.convertToInvoice(id, data);
    await loadChallans();
    return invoice;
  }
}
