import 'package:flutter/material.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';

class InvoicesProvider extends ChangeNotifier {
  InvoicesProvider(this._ds);
  final InvoicesRemoteDataSource _ds;

  List<Invoice> _invoices = [];
  bool _isLoading = false;
  String? _error;
  String? _typeFilter;
  String? _statusFilter;
  String _search = '';

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get typeFilter => _typeFilter;
  String? get statusFilter => _statusFilter;

  Future<void> loadInvoices({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (refresh) notifyListeners();
    try {
      _invoices = await _ds.getInvoices(
        type: _typeFilter,
        status: _statusFilter,
        search: _search.isNotEmpty ? _search : null,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setTypeFilter(String? type) {
    _typeFilter = type;
    loadInvoices(refresh: true);
  }

  void setStatusFilter(String? status) {
    _statusFilter = status;
    loadInvoices(refresh: true);
  }

  void updateSearch(String value) {
    _search = value;
    loadInvoices(refresh: true);
  }

  Future<Invoice> createInvoice({
    required String type,
    int? vendorId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    required List<Map<String, dynamic>> items,
  }) async {
    final invoice = await _ds.createInvoice(
      type: type,
      vendorId: vendorId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerGstin: customerGstin,
      discount: discount,
      note: note,
      items: items,
    );
    _invoices = [invoice, ..._invoices];
    notifyListeners();
    return invoice;
  }

  Future<Invoice> updateStatus(int id, String status) async {
    final invoice = await _ds.updateStatus(id, status);
    _invoices = _invoices.map((i) => i.id == id ? invoice : i).toList();
    notifyListeners();
    return invoice;
  }

  Future<void> deleteInvoice(int id) async {
    await _ds.deleteInvoice(id);
    _invoices = _invoices.where((i) => i.id != id).toList();
    notifyListeners();
  }
}
