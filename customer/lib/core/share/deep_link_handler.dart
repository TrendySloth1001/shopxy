import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/config/app_config.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';

class DeepLinkHandler {
  DeepLinkHandler(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  String? _lastKey;
  int _lastNavigatedAtMs = 0;
  static const _dedupeWindowMs = 1500;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initial));
    }

    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _handle(Uri uri) {
    final key = _extractTarget(uri);
    if (key == null) return;
    _route(key);
  }

  void _route(String key) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastKey == key && now - _lastNavigatedAtMs < _dedupeWindowMs) {
      return;
    }
    _lastKey = key;
    _lastNavigatedAtMs = now;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    if (key.startsWith('p:')) {
      final productId = key.substring(2);
      if (productId.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: productId),
        ),
      );
    } else if (key.startsWith('s:')) {
      final slug = key.substring(2);
      if (slug.isEmpty) return;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ShopProfilePage(slug: slug),
        ),
      );
    }
  }

  String? _extractTarget(Uri uri) {
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final expectedHost = Uri.parse(AppConfig.webBaseUrl).host;
      if (uri.host != expectedHost) return null;
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'p') {
        final id = int.tryParse(segs[1]);
        return id == null ? null : 'p:$id';
      }
      if (segs.length >= 2 && segs[0] == 's') {
        final slug = segs[1].trim();
        return slug.isEmpty ? null : 's:$slug';
      }
      return null;
    }
    if (uri.scheme == AppConfig.appScheme) {
      if (uri.host == 'product' && uri.pathSegments.isNotEmpty) {
        final id = int.tryParse(uri.pathSegments.first);
        return id == null ? null : 'p:$id';
      }
      if (uri.host == 'shop' && uri.pathSegments.isNotEmpty) {
        final slug = uri.pathSegments.first.trim();
        return slug.isEmpty ? null : 's:$slug';
      }
    }
    return null;
  }
}
