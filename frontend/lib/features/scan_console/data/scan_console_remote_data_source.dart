import 'dart:convert';
import 'package:shopxy/core/network/api_client.dart';

/// A product resolved from a scanned code by the backend.
class ScannedProduct {
  const ScannedProduct({
    required this.productId,
    required this.name,
    required this.sku,
    required this.sellingPrice,
  });

  final int productId;
  final String name;
  final String sku;

  /// Selling price as a decimal string (backend serialises Decimal as text).
  final String? sellingPrice;
}

/// Talks to the merchant scan-console endpoints. The phone is a pure publisher:
/// each scan is a discrete POST; the live list lives on the web console, which
/// receives the broadcast over a WebSocket. No socket is held on the device.
class ScanConsoleRemoteDataSource {
  const ScanConsoleRemoteDataSource(this._client);
  final ApiClient _client;

  /// Publish a scanned code. Returns the resolved product, or null when no
  /// product in this shop matches the code (HTTP 404). Throws otherwise.
  Future<ScannedProduct?> pushScan(String code) async {
    final response = await _client.post('/me/scan-console/scan', body: {'code': code});
    if (response.statusCode == 404) return null;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Scan failed (${response.statusCode}): ${response.body}');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final scan = body['scan'] as Map<String, dynamic>;
    return ScannedProduct(
      productId: scan['productId'] as int,
      name: scan['name'] as String,
      sku: scan['sku'] as String,
      sellingPrice: scan['sellingPrice'] as String?,
    );
  }

  /// Reset every live console for this shop.
  Future<void> clearConsole() async {
    final response = await _client.post('/me/scan-console/clear');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Clear failed (${response.statusCode}): ${response.body}');
    }
  }
}
