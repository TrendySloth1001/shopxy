import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/app.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/search/data/datasources/marketplace_search_remote_data_source.dart';
import 'package:shopxy_customer/features/search/presentation/providers/search_provider.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/linked_merchants_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'package:shopxy_customer/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:shopxy_customer/features/home_v2/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home_v2/presentation/providers/tracking_service.dart';
import 'package:shopxy_customer/features/addresses/data/datasources/addresses_remote_data_source.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/features/banner_slide/data/datasources/banner_slide_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenManager = TokenManager();
  await tokenManager.init();

  final apiClient = ApiClient(tokenManager);

  final authDs = AuthRemoteDataSource(apiClient);
  final notificationsDs = NotificationsRemoteDataSource(apiClient);
  final invitationsDs = InvitationsRemoteDataSource(apiClient);
  final meDs = MeRemoteDataSource(apiClient);
  final ordersDs = OrdersRemoteDataSource(apiClient);
  final wishlistDs = WishlistRemoteDataSource(apiClient);
  final homeFeedDs = HomeFeedRemoteDataSource(apiClient);
  final marketplaceDs = MarketplaceRemoteDataSource(apiClient);
  final marketplaceSearchDs = MarketplaceSearchRemoteDataSource(apiClient);
  final addressesDs = AddressesRemoteDataSource(apiClient);
  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final bannerSlideDs = BannerSlideRemoteDataSource(apiClient);
  final trackingService = TrackingService(apiClient);

  final authProvider = AuthProvider(authDs, tokenManager);
  final homeFeedProvider = HomeFeedProvider(homeFeedDs);
  final notificationsProvider =
      NotificationsProvider(notificationsDs, invitationsDs);
  final shopsProvider = ShopsProvider(meDs);
  final linkedMerchantsProvider = LinkedMerchantsProvider(meDs);
  final cartProvider = CartProvider(ordersDs);
  final ordersProvider = OrdersProvider(ordersDs);
  final wishlistProvider = WishlistProvider(wishlistDs);
  final addressesProvider = AddressesProvider(addressesDs);
  final categoriesProvider = CategoriesProvider(categoriesDs);

  // Force re-login if the refresh fails and clear cached state.
  tokenManager.onUnauthorized = () {
    authProvider.clearAuth();
    notificationsProvider.reset();
    shopsProvider.reset();
    cartProvider.clear();
    ordersProvider.reset();
    wishlistProvider.reset();
    addressesProvider.reset();
    linkedMerchantsProvider.reset();
    homeFeedProvider.clearPersonalized();
  };

  // After login or app boot: prime the bell badge + pending invites so
  // the home screen can immediately surface a "you've been invited"
  // callout. Single listener for the app lifetime — doesn't leak.
  //
  // Loads are staggered into two waves so the network isn't saturated
  // on first authenticated paint:
  //  • Wave A (immediate): everything Home V2 reads above the fold
  //    (personalized rail, unread badge, pending invites).
  //  • Wave B (microtask): tab-scoped data the user may never open in
  //    a session (orders list, wishlist, addresses, shops list).
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      notificationsProvider.refreshUnreadCount();
      notificationsProvider.loadIncoming(status: 'PENDING');
      // Personalized rail is part of the Home tab's first paint.
      homeFeedProvider.refreshPersonalized();

      Future.microtask(() {
        shopsProvider.loadShops();
        linkedMerchantsProvider.load();
        ordersProvider.load();
        wishlistProvider.load();
        addressesProvider.load();
      });
    } else {
      notificationsProvider.reset();
      shopsProvider.reset();
      linkedMerchantsProvider.reset();
      cartProvider.clear();
      ordersProvider.reset();
      wishlistProvider.reset();
      addressesProvider.reset();
      homeFeedProvider.clearPersonalized();
    }
  });

  // Kick the public home feed straight away — first paint of the home
  // tab shouldn't wait for auth.
  homeFeedProvider.load();
  // Categories are public — load now so the home rail renders without
  // waiting for sign-in. Cached for the app's lifetime.
  categoriesProvider.load();
  // Restore the cart from disk so a relaunch keeps the user's basket.
  // Independent from auth — anonymous carts survive sign-in.
  cartProvider.restore();

  runApp(
    MultiProvider(
      providers: [
        // Data sources — needed by detail pages that construct their own
        // loads (order detail) without a parent provider.
        Provider<OrdersRemoteDataSource>.value(value: ordersDs),
        // Public marketplace reads — PDP V2 + ShopProfilePage construct
        // their own loads from this DS rather than via a parent provider
        // so the data follows the productId/slug in the route arguments.
        Provider<MarketplaceRemoteDataSource>.value(value: marketplaceDs),
        // Categories DS: the category-products page hits it directly so
        // route-scoped pages can load without a parent provider.
        Provider<CategoriesRemoteDataSource>.value(value: categoriesDs),
        // Banner slide-detail page loads its own payload from the
        // /banners/:id/slide endpoint via this DS — provided so the
        // route-scoped page doesn't need a parent provider.
        Provider<BannerSlideRemoteDataSource>.value(value: bannerSlideDs),
        ChangeNotifierProvider<CategoriesProvider>.value(
            value: categoriesProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: notificationsProvider),
        ChangeNotifierProvider<ShopsProvider>.value(value: shopsProvider),
        ChangeNotifierProvider<LinkedMerchantsProvider>.value(value: linkedMerchantsProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
        ChangeNotifierProvider<WishlistProvider>.value(value: wishlistProvider),
        ChangeNotifierProvider<AddressesProvider>.value(value: addressesProvider),
        // Search has no provider-level boot work; create lazily on first
        // open so we don't pay for it on every cold start.
        ChangeNotifierProvider<SearchProvider>(
          // Public marketplace search (hybrid semantic + FTS on the
          // backend). Lazy so we don't pay the hints prefetch until
          // the user actually opens the search screen.
          create: (_) => SearchProvider(marketplaceSearchDs),
        ),
        ChangeNotifierProvider<HomeFeedProvider>.value(value: homeFeedProvider),
        Provider<TrackingService>.value(value: trackingService),
      ],
      child: const ShopxyCustomerApp(),
    ),
  );

  authProvider.init();
}
