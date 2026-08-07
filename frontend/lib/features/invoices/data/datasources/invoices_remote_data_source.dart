import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/invoices/data/models/invoice_dto.dart';
import 'package:shopxy/features/invoices/domain/entities/invoice.dart';
import 'package:shopxy/features/invoices/domain/entities/recipient_details.dart';

/// Outcome of POST /invoices when the caller asked for a one-shot
/// create + confirm. The invoice always exists (we never roll the
/// create back on a confirm failure); the confirm bits tell the UI
/// whether stock posted or the merchant needs to resolve a shortfall.
class CreateInvoiceResult {
  const CreateInvoiceResult({
    required this.invoice,
    required this.confirmed,
    this.confirmError,
    this.shortfallProductId,
  });
  final Invoice invoice;
  final bool confirmed;
  final String? confirmError;
  final String? shortfallProductId;
}

/// One page of the invoice list plus enough pagination context for the
/// caller to know whether to fetch the next page. `hasMore` is derived
/// from the server's `pagination.page < pagination.totalPages`.
class InvoicesPage {
  const InvoicesPage({required this.items, required this.hasMore});
  final List<Invoice> items;
  final bool hasMore;
}

class InvoicesRemoteDataSource {
  const InvoicesRemoteDataSource(this._client);
  final ApiClient _client;

  /// Paginated fetch. Returns the page's items plus `hasMore` so the
  /// provider can drive infinite scroll. The backend caps `limit` at 100.
  Future<InvoicesPage> getInvoicesPage({
    String? type,
    String? status,
    String? documentType,
    String? vendorId,
    String? productId,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    /// The "Archived" view. Archived documents are out of every other list —
    /// that's the point of archiving.
    bool archived = false,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{'page': '$page', 'limit': '$limit'};
    if (archived) params['archived'] = 'true';
    if (type != null) params['type'] = type;
    if (status != null) params['status'] = status;
    if (documentType != null) params['documentType'] = documentType;
    if (vendorId != null) params['vendorId'] = vendorId;
    if (productId != null) params['productId'] = productId;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (dateFrom != null) params['dateFrom'] = dateFrom.toUtc().toIso8601String();
    if (dateTo != null) params['dateTo'] = dateTo.toUtc().toIso8601String();
    final res = await _client.get('/invoices', queryParameters: params);
    if (res.statusCode != 200) {
      throw Exception('Failed to load invoices: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>;
    final items = data
        .map((e) => InvoiceDto.fromJson(e as Map<String, dynamic>))
        .toList();
    final pagination = json['pagination'] as Map<String, dynamic>?;
    final currentPage = (pagination?['page'] as num?)?.toInt() ?? page;
    final totalPages = (pagination?['totalPages'] as num?)?.toInt() ?? 1;
    return InvoicesPage(items: items, hasMore: currentPage < totalPages);
  }

  /// Convenience wrapper that returns just the items of a single page.
  /// Used by callers that only want a bounded slice (e.g. the product
  /// page's open-drafts callout) and don't paginate.
  Future<List<Invoice>> getInvoices({
    String? type,
    String? status,
    String? documentType,
    String? vendorId,
    String? productId,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final result = await getInvoicesPage(
      type: type,
      status: status,
      documentType: documentType,
      vendorId: vendorId,
      productId: productId,
      search: search,
      page: page,
      limit: limit,
    );
    return result.items;
  }

  Future<Invoice> getInvoiceById(String id) async {
    final res = await _client.get('/invoices/$id');
    if (res.statusCode != 200) throw Exception('Invoice not found');
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Returns the freshly-created invoice plus the result of the
  /// optional auto-confirm. `confirmed` is true when the server ran
  /// updateStatus inline successfully; `confirmError` carries the
  /// server-side reason (e.g. insufficient stock) when the create
  /// landed as a draft but the confirm step failed.
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
    RecipientDetails? recipient,
    required List<Map<String, dynamic>> items,
    bool confirm = false,
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
        recipient: recipient,
        items: items,
        confirm: confirm,
      ),
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to create invoice');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final invoice = InvoiceDto.fromJson(body);
    final confirmed = (body['confirmed'] as bool?) ?? false;
    final errMap = body['confirmError'] as Map<String, dynamic>?;
    return CreateInvoiceResult(
      invoice: invoice,
      confirmed: confirmed,
      confirmError: errMap?['error'] as String?,
      shortfallProductId: errMap?['productId']?.toString(),
    );
  }

  /// Replace the contents of a DRAFT invoice. Backend rejects non-draft
  /// invoices; reuses the create payload shape so the only call-site
  /// difference is the HTTP verb.
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
    RecipientDetails? recipient,
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
        recipient: recipient,
        items: items,
      ),
    );
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to update invoice');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<Invoice> updateStatus(String id, String status) async {
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
  Future<Invoice> convertEstimate(String id) async {
    final res = await _client.post('/invoices/$id/convert');
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to convert estimate');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Raise a credit or debit note against a CONFIRMED sale invoice
  /// (POST /invoices/:id/notes). [lines] carry `{productId, quantity}` and,
  /// for debit notes, `unitPrice` (the supplementary amount per unit). A
  /// credit note reverses the original price and — unless [restock] is false —
  /// puts the goods back on the shelf; a debit note adds value only. Returns
  /// the freshly-minted note's id / number / total for the confirmation toast.
  Future<({String id, String invoiceNo, double total})> issueNote(
    String originalInvoiceId, {
    required String documentType,
    String? reason,
    bool? restock,
    required List<Map<String, dynamic>> lines,
  }) async {
    final res = await _client.post(
      '/invoices/$originalInvoiceId/notes',
      body: {
        'documentType': documentType,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
        'restock': ?restock,
        'lines': lines,
      },
    );
    if (res.statusCode != 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to issue note');
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      id: j['id'].toString(),
      invoiceNo: j['invoiceNo'] as String,
      total: double.tryParse('${j['total']}') ?? 0,
    );
  }

  /// File a DRAFT or CANCELLED document out of the working list, or bring it
  /// back. Replaces `deleteInvoice`, which could never succeed: a draft
  /// already owns its legal serial and Rule 46(b) needs the run consecutive,
  /// so the row can't go away. Archiving keeps the number allocated.
  Future<Invoice> setArchived(String id, bool archived) async {
    final path = archived ? 'archive' : 'unarchive';
    final res = await _client.post('/invoices/$id/$path');
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      throw Exception(body['error'] ?? 'Failed to archive invoice');
    }
    return InvoiceDto.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Returns the raw HTTP response so the caller can read [bodyBytes]
  /// (PDF binary). Goes through [ApiClient.get] so the auth header is
  /// attached — calling [http.get] directly here hit the `ownerOnly`
  /// middleware and returned 401, which surfaced as "Failed to generate
  /// PDF" in the UI.
  Future<http.Response> downloadPdf(String id) {
    return _client.get('/invoices/$id/pdf');
  }
}
