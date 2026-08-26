import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shopxy_customer/core/config/app_config.dart';

class ShareService {
  const ShareService();

  String productUrl(int productId) =>
      '${AppConfig.webBaseUrl}/p/$productId';

  String shopUrl(String slug) => '${AppConfig.webBaseUrl}/s/$slug';

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
