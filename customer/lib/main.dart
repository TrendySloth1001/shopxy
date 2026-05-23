import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/app.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/catalog_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/search/presentation/providers/search_provider.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'package:shopxy_customer/features/wishlist/presentation/providers/wishlist_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenManager = TokenManager();
  await tokenManager.init();

  final apiClient = ApiClient(tokenManager);

  final authDs = AuthRemoteDataSource(apiClient);
  final notificationsDs = NotificationsRemoteDataSource(apiClient);
  final invitationsDs = InvitationsRemoteDataSource(apiClient);
  final meDs = MeRemoteDataSource(apiClient);
  final catalogDs = CatalogRemoteDataSource(apiClient);
  final ordersDs = OrdersRemoteDataSource(apiClient);
  final wishlistDs = WishlistRemoteDataSource(apiClient);

  final authProvider = AuthProvider(authDs, tokenManager);
  final notificationsProvider =
      NotificationsProvider(notificationsDs, invitationsDs);
  final shopsProvider = ShopsProvider(meDs);
  final catalogProvider = CatalogProvider(catalogDs);
  final cartProvider = CartProvider(ordersDs);
  final ordersProvider = OrdersProvider(ordersDs);
  final wishlistProvider = WishlistProvider(wishlistDs);

  // Force re-login if the refresh fails and clear cached state.
  tokenManager.onUnauthorized = () {
    authProvider.clearAuth();
    notificationsProvider.reset();
    shopsProvider.reset();
    catalogProvider.reset();
    cartProvider.clear();
    ordersProvider.reset();
    wishlistProvider.reset();
  };

  // After login or app boot: prime the bell badge + pending invites so
  // the home screen can immediately surface a "you've been invited"
  // callout. Single listener for the app lifetime — doesn't leak.
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      notificationsProvider.refreshUnreadCount();
      notificationsProvider.loadIncoming(status: 'PENDING');
      shopsProvider.loadShops();
      catalogProvider.load();
      catalogProvider.loadCategories();
      ordersProvider.load();
      wishlistProvider.load();
    } else {
      notificationsProvider.reset();
      shopsProvider.reset();
      catalogProvider.reset();
      cartProvider.clear();
      ordersProvider.reset();
      wishlistProvider.reset();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        // Data sources — needed by detail pages that construct their own
        // loads (product detail, order detail) without a parent provider.
        Provider<CatalogRemoteDataSource>.value(value: catalogDs),
        Provider<OrdersRemoteDataSource>.value(value: ordersDs),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: notificationsProvider),
        ChangeNotifierProvider<ShopsProvider>.value(value: shopsProvider),
        ChangeNotifierProvider<CatalogProvider>.value(value: catalogProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
        ChangeNotifierProvider<WishlistProvider>.value(value: wishlistProvider),
        // Search has no provider-level boot work; create lazily on first
        // open so we don't pay for it on every cold start.
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(catalogDs),
        ),
      ],
      child: const ShopxyCustomerApp(),
    ),
  );

  authProvider.init();
}
