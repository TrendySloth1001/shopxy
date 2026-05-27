import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy_customer/core/config/app_config.dart';

/// Builds shareable URLs + invokes the platform share sheet.
///
/// The URL format mirrors what the Android intent-filter and iOS
/// Associated Domains config expect:
///   `<webBaseUrl>/p/<id>`    for products
///   `<webBaseUrl>/s/<slug>`  for shops
/// The web host renders a public page at each path so taps from
/// devices without the app installed still land somewhere useful.
class ShareService {
  const ShareService();

  /// Returns the canonical shareable URL for a product.
  String productUrl(int productId) =>
      '${AppConfig.webBaseUrl}/p/$productId';

  /// Returns the canonical shareable URL for a shop.
  String shopUrl(String slug) => '${AppConfig.webBaseUrl}/s/$slug';

  /// Opens the platform share sheet with a short message + the product
  /// URL. `originBox` is the global rect the iPad popover anchors to;
  /// pass `context.findRenderObject()`'s paint bounds when invoking
  /// from a specific button so the popover doesn't appear in the
  /// corner of the screen.
  Future<void> shareProduct({
    required int productId,
    required String name,
    Rect? originBox,
  }) async {
    final url = productUrl(productId);
    final message = name.isEmpty
        ? 'Check this out: $url'
        : 'Check out "$name" on Shopxy — $url';
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: name,
        sharePositionOrigin: originBox,
      ),
    );
  }

  /// Opens the platform share sheet for a shop landing page.
  Future<void> shareShop({
    required String slug,
    required String name,
    Rect? originBox,
  }) async {
    final url = shopUrl(slug);
    final message = name.isEmpty
        ? 'Browse this shop on Shopxy: $url'
        : 'Browse "$name" on Shopxy — $url';
    await SharePlus.instance.share(
      ShareParams(
        text: message,
        subject: name,
        sharePositionOrigin: originBox,
      ),
    );
  }
}
