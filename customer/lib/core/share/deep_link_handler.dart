import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:shopxy_customer/core/config/app_config.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/product_detail_page.dart';
import 'package:shopxy_customer/features/marketplace/presentation/pages/shop_profile_page.dart';

/// Listens for incoming app links + the launching URL and routes the
/// supported paths to in-app pages. Lives at app boot (instantiated in
/// main.dart) so a tap on a shared product URL opens the PDP whether
/// the app was already running (uriLinkStream) or just cold-started
/// (getInitialAppLink).
///
/// Supported URL shapes:
///   `https://<webBaseUrl>/p/<id>`       product (universal / app link)
///   `shopxy://product/<id>`             product (custom scheme)
///   `https://<webBaseUrl>/s/<slug>`     shop (universal / app link)
///   `shopxy://shop/<slug>`              shop (custom scheme)
class DeepLinkHandler {
  DeepLinkHandler(
    this._navigatorKey, {
    this.isAuthenticated,
  });

  final GlobalKey<NavigatorState> _navigatorKey;
  /// When supplied, a link arriving while the user is signed-out is
  /// stashed in [_pendingLink] until [replayPendingOnLogin] is invoked
  /// (wired to AuthProvider's auth-state listener). Without this guard
  /// a logged-out user gets pushed into a PDP underneath the LoginPage.
  final bool Function()? isAuthenticated;

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Tracks the most recent destination we navigated to plus the
  /// millisecond timestamp, so consecutive identical Uri events from
  /// the OS (which happens often on Android cold-starts) don't stack
  /// duplicate pages. The key is `"p:<id>"` for products and
  /// `"s:<slug>"` for shops.
  String? _lastKey;
  int _lastNavigatedAtMs = 0;
  static const _dedupeWindowMs = 1500;

  /// Pending destination the user wants to see, deferred until they
  /// sign in. Tagged with the same `p:` / `s:` prefix as `_lastKey`.
  String? _pendingLink;

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
    final key = _extractTarget(uri);
    if (key == null) return;
    _route(key);
  }

  void _route(String key) {
    // Auth gate: defer the navigation until the user signs in. The
    // AuthProvider listener in main.dart calls [replayPendingOnLogin]
    // once auth flips true.
    if (isAuthenticated != null && !isAuthenticated!()) {
      _pendingLink = key;
      return;
    }

    // Dedupe consecutive identical taps. The OS fires the uri stream
    // more than once on some platforms, and the AppLinks plugin
    // re-delivers the cold-start URI alongside the live stream.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_lastKey == key && now - _lastNavigatedAtMs < _dedupeWindowMs) {
      return;
    }
    _lastKey = key;
    _lastNavigatedAtMs = now;

    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;

    if (key.startsWith('p:')) {
      final productId = int.tryParse(key.substring(2));
      if (productId == null) return;
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

  /// Invoked by main.dart on the false→true auth-state transition.
  /// Drains any link the user tapped while signed out.
  void replayPendingOnLogin() {
    final pending = _pendingLink;
    if (pending == null) return;
    _pendingLink = null;
    _route(pending);
  }

  /// Extracts a `"p:<id>"` (product) or `"s:<slug>"` (shop) target
  /// from a supported URL. Tolerant of trailing slashes and query
  /// strings; returns null for anything else so the listener can
  /// safely ignore unrelated links the OS might deliver.
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
      // Custom schemes put the "host" before the path, so
      //   shopxy://product/12  → host=product, pathSegments=[12]
      //   shopxy://shop/foo    → host=shop,    pathSegments=[foo]
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
