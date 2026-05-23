import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/invoices/data/models/invoice_dto.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';

class InvoicesRemoteDataSource {
  const InvoicesRemoteDataSource(this._client);
  final ApiClient _client;

  Future<List<Invoice>> getInvoices({
    String? type,
    String? status,
    String? documentType,
    int? vendorId,
    int? productId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (documentType != null) params['documentType'] = documentType;
    if (vendorId != null) params['vendorId'] = '$vendorId';
    if (productId != null) params['productId'] = '$productId';
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _client.get('/invoices', queryParameters: params);
    if (res.statusCode != 200) {
      throw Exception('Failed to load invoices: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    return data
        .map((e) => InvoiceDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Invoice> getInvoiceById(int id) async {
    final res = await _client.get('/invoices/$id');
    if (res.statusCode != 200) throw Exception('Invoice not found');
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Invoice> createInvoice({
    required String type,
    int? vendorId,
    int? partyId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    String? documentType,
    String? placeOfSupplyStateCode,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _client.post(
      '/invoices',
      body: InvoiceDto.toCreateJson(
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
      ),
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to create invoice');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Replace the contents of a DRAFT invoice. Backend rejects non-draft
  /// invoices; reuses the create payload shape so the only call-site
  /// difference is the HTTP verb.
  Future<Invoice> updateInvoice({
    required int id,
    required String type,
    int? vendorId,
    int? partyId,
    String? customerName,
    String? customerPhone,
    String? customerGstin,
    double? discount,
    String? note,
    String? documentType,
    String? placeOfSupplyStateCode,
    required List<Map<String, dynamic>> items,
  }) async {
    final res = await _client.patch(
      '/invoices/$id',
      body: InvoiceDto.toCreateJson(
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
      ),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to update invoice');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Invoice> updateStatus(int id, String status) async {
    final res = await _client.patch(
      '/invoices/$id/status',
      body: {'status': status},
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to update status');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Convert an ESTIMATE / PROFORMA quotation into a real TAX_INVOICE.
  /// Backend mints a brand new invoice (new number, new id) from the
  /// source's items; the source row is left untouched.
  Future<Invoice> convertEstimate(int id) async {
    final res = await _client.post('/invoices/$id/convert');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to convert estimate');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<void> deleteInvoice(int id) async {
    final res = await _client.delete('/invoices/$id');
    if (res.statusCode != 204) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to delete invoice');
    }
  }

  /// Returns the raw HTTP response so the caller can read [bodyBytes]
  /// (PDF binary). Goes through [ApiClient.get] so the auth header is
  /// attached — calling [http.get] directly here hit the `ownerOnly`
  /// middleware and returned 401, which surfaced as "Failed to generate
  /// PDF" in the UI.
  Future<http.Response> downloadPdf(int id) {
    return _client.get('/invoices/$id/pdf');
  }
}
