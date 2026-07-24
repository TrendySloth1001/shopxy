import 'dart:convert';
import 'dart:typed_data';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_merchant.dart';

class MeRemoteDataSource {
  const MeRemoteDataSource(this._client);
  final ApiClient _client;

  /// New marketplace-shaped endpoint: returns the distinct *shops* (not
  /// Party/Vendor rows) the user has at least one active link to, with
  /// marketplace metadata (logo, slug, rating) so the customer app can
  /// render a clickable rail of merchant cards.
  Future<List<LinkedMerchant>> linkedShops() async {
    final res = await _client.get('/me/linked-shops');
    if (res.statusCode != 200) {
      throw Exception('Failed to load linked shops: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => LinkedMerchant.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns both lists in one round-trip. Customers may simultaneously
  /// be a party at one shop and a vendor at another.
  Future<List<LinkedShop>> links() async {
    final res = await _client.get('/me/links');
    if (res.statusCode != 200) {
      throw Exception('Failed to load your shops: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final parties = (json['parties'] as List)
        .map((e) =>
            LinkedShop.fromJson(e as Map<String, dynamic>, ShopRole.party))
        .toList();
    final vendors = (json['vendors'] as List)
        .map((e) =>
            LinkedShop.fromJson(e as Map<String, dynamic>, ShopRole.vendor))
        .toList();
    return [...parties, ...vendors];
  }

  Future<List<ShopInvoice>> invoices(LinkedShop shop,
      {int page = 1, int limit = 30}) async {
    final base = shop.role == ShopRole.party
        ? '/me/parties/${shop.id}/invoices'
        : '/me/vendors/${shop.id}/invoices';
    final res = await _client.get(base, queryParameters: {
      'page': '$page',
      'limit': '$limit',
    });
    if (res.statusCode != 200) {
      throw Exception('Failed to load invoices: ${res.statusCode}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => ShopInvoice.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ShopInvoiceDetail> invoiceDetail(
    LinkedShop shop,
    String invoiceId,
  ) async {
    final path = shop.role == ShopRole.party
        ? '/me/parties/${shop.id}/invoices/$invoiceId'
        : '/me/vendors/${shop.id}/invoices/$invoiceId';
    final res = await _client.get(path);
    if (res.statusCode != 200) {
      throw Exception('Failed to load invoice: ${res.statusCode}');
    }
    return ShopInvoiceDetail.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  String _err(String body, String fallback) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return (m['message'] ?? m['error'] ?? fallback) as String;
    } catch (_) {
      return fallback;
    }
  }

  /// Quotations the shop sent this customer.
  Future<List<ShopQuotation>> quotations(LinkedShop shop) async {
    final res = await _client.get('/me/parties/${shop.id}/quotations');
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to load quotations: ${res.statusCode}'));
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['data'] as List)
        .map((e) => ShopQuotation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Accept a quotation → the shop turns it into a confirmed invoice.
  Future<ShopQuotation> acceptQuotation(LinkedShop shop, String quotationId) async {
    final res = await _client.post(
      '/me/parties/${shop.id}/quotations/$quotationId/accept',
    );
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to accept: ${res.statusCode}'));
    }
    return ShopQuotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<ShopQuotation> declineQuotation(
    LinkedShop shop,
    String quotationId, {
    String? declineNote,
  }) async {
    final res = await _client.post(
      '/me/parties/${shop.id}/quotations/$quotationId/decline',
      body: {
        if (declineNote != null && declineNote.isNotEmpty)
          'declineNote': declineNote,
      },
    );
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to decline: ${res.statusCode}'));
    }
    return ShopQuotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Customer builds a basket and asks the shop for a quote (lands REQUESTED).
  Future<ShopQuotation> requestQuotation(
    LinkedShop shop, {
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final res = await _client.post(
      '/me/parties/${shop.id}/quotations',
      body: {
        'items': items,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    if (res.statusCode != 201 && res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to send request: ${res.statusCode}'));
    }
    return ShopQuotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Download a quotation as PDF bytes (shop-sent or customer-requested).
  Future<Uint8List> downloadQuotationPdf(LinkedShop shop, String quotationId) async {
    final res = await _client
        .get('/me/parties/${shop.id}/quotations/$quotationId/pdf');
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Could not download PDF: ${res.statusCode}'));
    }
    return res.bodyBytes;
  }

  /// Withdraw a quote request that's still awaiting the shop.
  Future<ShopQuotation> cancelQuotation(LinkedShop shop, String quotationId) async {
    final res = await _client.post(
      '/me/parties/${shop.id}/quotations/$quotationId/cancel',
    );
    if (res.statusCode != 200) {
      throw Exception(_err(res.body, 'Failed to cancel: ${res.statusCode}'));
    }
    return ShopQuotation.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }
}
