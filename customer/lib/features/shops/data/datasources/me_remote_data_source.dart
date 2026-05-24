import 'dart:convert';
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
    int invoiceId,
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
}
