import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/config/app_config.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_v2_page.dart';

/// Listens for incoming app links + the launching URL and routes the
/// supported paths to in-app pages. Lives at app boot (instantiated in
/// main.dart) so a tap on a shared product URL opens the PDP whether
/// the app was already running (uriLinkStream) or just cold-started
/// (getInitialAppLink).
///
/// Supported URL shapes:
///   `https://<webBaseUrl>/p/<id>`       universal / app link
///   `shopxy://product/<id>`             custom scheme fallback
class DeepLinkHandler {
  DeepLinkHandler(this._navigatorKey);

  final GlobalKey<NavigatorState> _navigatorKey;
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    // Cold-start URL — the app was launched by a tap on a link. Drain
    // first so the eventual push lands on top of the root route the
    // navigator builds, not below it.
    final initial = await _appLinks.getInitialLink();
    if (initial != null) {
      // Defer to the next frame so the navigator has been built before
      // we push onto it.
      WidgetsBinding.instance.addPostFrameCallback((_) => _handle(initial));
    }

    _sub = _appLinks.uriLinkStream.listen(
      _handle,
      // Errors during link parsing shouldn't crash the app; the user
      // just lands on whatever page they would have without the link.
      onError: (_) {},
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }

  void _handle(Uri uri) {
    final productId = _extractProductId(uri);
    if (productId == null) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute(
        builder: (_) => ProductDetailV2Page(productId: productId),
      ),
    );
  }

  /// Extracts a product id from a supported URL. Tolerant of trailing
  /// slashes and query strings; returns null for anything else so the
  /// listener can safely ignore unrelated links the OS might deliver
  /// (e.g. a future deeplink for shop, collection, etc).
  int? _extractProductId(Uri uri) {
    // https://shopxy.app/p/<id>
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final expectedHost = Uri.parse(AppConfig.webBaseUrl).host;
      if (uri.host != expectedHost) return null;
      final segs = uri.pathSegments;
      if (segs.length >= 2 && segs[0] == 'p') {
        return int.tryParse(segs[1]);
      }
      return null;
    }
    // shopxy://product/<id>
    if (uri.scheme == AppConfig.appScheme) {
      // Custom schemes put the "host" before the path, so
      //   shopxy://product/12  → host=product, pathSegments=[12]
      if (uri.host == 'product' && uri.pathSegments.isNotEmpty) {
        return int.tryParse(uri.pathSegments.first);
      }
    }
    return null;
  }
}
