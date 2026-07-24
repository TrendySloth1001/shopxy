import 'package:flutter/material.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/shared/utils/error_text.dart';

class InvoicesProvider extends ChangeNotifier {
  InvoicesProvider(this._ds);
  final InvoicesRemoteDataSource _ds;

  static const int _pageSize = 20;

  List<Invoice> _invoices = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;
  String? _typeFilter;
  String? _statusFilter;
  String? _documentTypeFilter;
  String _search = '';

  List<Invoice> get invoices => _invoices;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  String? get typeFilter => _typeFilter;
  String? get statusFilter => _statusFilter;
  String? get documentTypeFilter => _documentTypeFilter;

  /// Returns the provider to its post-construction state. Wired to
  /// AuthProvider.clearAuth so logout / 401-refresh failure drops the
  /// previous user's invoices instead of flashing them at the next user.
  void reset() {
    _invoices = [];
    _isLoading = false;
    _isLoadingMore = false;
    _hasMore = true;
    _page = 1;
    _error = null;
    _typeFilter = null;
    _statusFilter = null;
    _documentTypeFilter = null;
    _search = '';
    notifyListeners();
  }

  /// Loads the first page for the current filters, replacing the list.
  /// Filter/search changes and pull-to-refresh route through here.
  Future<void> loadInvoices({bool refresh = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    _page = 1;
    if (refresh) notifyListeners();
    try {
      final result = await _ds.getInvoicesPage(
        type: _typeFilter,
        status: _statusFilter,
        documentType: _documentTypeFilter,
        search: _search.isNotEmpty ? _search : null,
        page: _page,
        limit: _pageSize,
      );
      _invoices = result.items;
      _hasMore = result.hasMore;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Appends the next page. No-op while a load is in flight or when the
  /// server has signalled there are no more pages for the current filters.
  Future<void> loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      final next = _page + 1;
      final result = await _ds.getInvoicesPage(
        type: _typeFilter,
        status: _statusFilter,
        documentType: _documentTypeFilter,
        search: _search.isNotEmpty ? _search : null,
        page: next,
        limit: _pageSize,
      );
      _page = next;
      _invoices = [..._invoices, ...result.items];
      _hasMore = result.hasMore;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _isLoadingMore = false;
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

  void setDocumentTypeFilter(String? documentType) {
    _documentTypeFilter = documentType;
    loadInvoices(refresh: true);
  }

  void updateSearch(String value) {
    _search = value;
    loadInvoices(refresh: true);
  }

  Future<CreateInvoiceResult> createInvoice({
    required String type,
    String? vendorId,
    String? partyId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    String? documentType,
    String? placeOfSupplyStateCode,
    required List<Map<String, dynamic>> items,
    bool confirm = false,
  }) async {
    final result = await _ds.createInvoice(
      type: type,
      vendorId: vendorId,
      partyId: partyId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerGstin: customerGstin,
      discount: discount,
      note: note,
      documentType: documentType,
      placeOfSupplyStateCode: placeOfSupplyStateCode,
      items: items,
      confirm: confirm,
    );
    _invoices = [result.invoice, ..._invoices];
    notifyListeners();
    return result;
  }

  Future<Invoice> updateInvoice({
    required String id,
    required String type,
    String? vendorId,
    String? partyId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    String? documentType,
    String? placeOfSupplyStateCode,
    required List<Map<String, dynamic>> items,
  }) async {
    final invoice = await _ds.updateInvoice(
      id: id,
      type: type,
      vendorId: vendorId,
      partyId: partyId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerGstin: customerGstin,
      discount: discount,
      note: note,
      documentType: documentType,
      placeOfSupplyStateCode: placeOfSupplyStateCode,
      items: items,
    );
    _invoices = _invoices.map((i) => i.id == id ? invoice : i).toList();
    notifyListeners();
    return invoice;
  }

  Future<Invoice> updateStatus(String id, String status) async {
    final invoice = await _ds.updateStatus(id, status);
    _invoices = _invoices.map((i) => i.id == id ? invoice : i).toList();
    notifyListeners();
    return invoice;
  }

  Future<void> deleteInvoice(String id) async {
    await _ds.deleteInvoice(id);
    _invoices = _invoices.where((i) => i.id != id).toList();
    notifyListeners();
  }
}
