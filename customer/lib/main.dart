import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/app.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/config/app_config.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/core/share/deep_link_handler.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/cart_remote_data_source.dart';
import 'package:shopxy_customer/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy_customer/features/search/data/datasources/marketplace_search_remote_data_source.dart';
import 'package:shopxy_customer/features/search/presentation/providers/search_provider.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/linked_merchants_provider.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/features/wishlist/data/datasources/wishlist_remote_data_source.dart';
import 'package:shopxy_customer/features/wishlist/presentation/providers/wishlist_provider.dart';
import 'package:shopxy_customer/features/home/data/datasources/home_feed_remote_data_source.dart';
import 'package:shopxy_customer/features/home/presentation/providers/home_feed_provider.dart';
import 'package:shopxy_customer/features/home/presentation/services/tracking_service.dart';
import 'package:shopxy_customer/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:shopxy_customer/features/addresses/data/datasources/addresses_remote_data_source.dart';
import 'package:shopxy_customer/features/addresses/presentation/providers/addresses_provider.dart';
import 'package:shopxy_customer/features/gst/data/datasources/gst_profile_remote_data_source.dart';
import 'package:shopxy_customer/features/gst/presentation/providers/gst_profile_provider.dart';
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/features/banner_detail/data/datasources/banner_detail_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/recently_viewed/data/datasources/recently_viewed_remote_data_source.dart';
import 'package:shopxy_customer/features/returns/data/datasources/returns_remote_data_source.dart';
import 'package:shopxy_customer/features/coupons/data/datasources/coupons_remote_data_source.dart';
import 'package:shopxy_customer/features/profile/data/datasources/avatar_remote_data_source.dart';
import 'package:shopxy_customer/core/startup_failure_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppConfig.assertSafeForRelease();
    await _bootstrap();
  } catch (error, stack) {
    debugPrint('Shopxy failed to start: $error\n$stack');
    runApp(StartupFailureApp(error: error, stack: stack));
  }
}

Future<void> _bootstrap() async {
  final tokenManager = TokenManager();
  await tokenManager.init();

  final apiClient = ApiClient(tokenManager);

  final authDs = AuthRemoteDataSource(apiClient);
  final notificationsDs = NotificationsRemoteDataSource(apiClient);
  final invitationsDs = InvitationsRemoteDataSource(apiClient);
  final meDs = MeRemoteDataSource(apiClient);
  final ordersDs = OrdersRemoteDataSource(apiClient);
  final cartDs = CartRemoteDataSource(apiClient);
  final wishlistDs = WishlistRemoteDataSource(apiClient);
  final homeFeedDs = HomeFeedRemoteDataSource(apiClient);
  final marketplaceDs = MarketplaceRemoteDataSource(apiClient);
  final bannerDetailDs = BannerDetailRemoteDataSource(apiClient);
  final marketplaceSearchDs = MarketplaceSearchRemoteDataSource(apiClient);
  final addressesDs = AddressesRemoteDataSource(apiClient);
  final gstProfileDs = GstProfileRemoteDataSource(apiClient);
  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final reviewsDs = ReviewsRemoteDataSource(apiClient);
  final recentlyViewedDs = RecentlyViewedRemoteDataSource(apiClient);
  final returnsDs = ReturnsRemoteDataSource(apiClient);
  final couponsDs = CouponsRemoteDataSource(apiClient);
  final avatarDs = AvatarRemoteDataSource(apiClient);
  final trackingService = TrackingService(apiClient);

  final authProvider = AuthProvider(authDs, tokenManager);
  final homeFeedProvider = HomeFeedProvider(homeFeedDs);
  final notificationsProvider =
      NotificationsProvider(notificationsDs, invitationsDs);
  final shopsProvider = ShopsProvider(meDs);
  final linkedMerchantsProvider = LinkedMerchantsProvider(meDs);
  final cartProvider = CartProvider(ordersDs, cartDs);
  final ordersProvider = OrdersProvider(ordersDs);
  final wishlistProvider = WishlistProvider(wishlistDs);
  final addressesProvider = AddressesProvider(addressesDs);
  final gstProfileProvider = GstProfileProvider(gstProfileDs);
  final categoriesProvider = CategoriesProvider(categoriesDs);
  final onboardingController = OnboardingController();

  authProvider.registerOnClear(notificationsProvider.reset);
  authProvider.registerOnClear(shopsProvider.reset);
  authProvider.registerOnClear(cartProvider.onLoggedOut);
  authProvider.registerOnClear(ordersProvider.reset);
  authProvider.registerOnClear(wishlistProvider.reset);
  authProvider.registerOnClear(addressesProvider.reset);
  authProvider.registerOnClear(gstProfileProvider.clear);
  authProvider.registerOnClear(linkedMerchantsProvider.reset);
  authProvider.registerOnClear(homeFeedProvider.clearPersonalized);

  authProvider.registerOnExplicitLogout(cartProvider.clear);

  tokenManager.onUnauthorized = authProvider.clearAuth;

  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      notificationsProvider.refreshUnreadCount();
      notificationsProvider.loadIncoming(status: 'PENDING');
      homeFeedProvider.refreshPersonalized();
      cartProvider.syncFromServer(mergeLocal: true);

      Future.microtask(() {
        shopsProvider.loadShops();
        linkedMerchantsProvider.load();
        ordersProvider.load();
        wishlistProvider.load();
        addressesProvider.load();
        gstProfileProvider.load();
      });
    } else {
      notificationsProvider.reset();
      shopsProvider.reset();
      linkedMerchantsProvider.reset();
      cartProvider.onLoggedOut();
      ordersProvider.reset();
      wishlistProvider.reset();
      addressesProvider.reset();
      homeFeedProvider.clearPersonalized();
    }
  });

  homeFeedProvider.load();
  categoriesProvider.load();
  cartProvider.restore();
  // ignore: unawaited_futures
  shopsProvider.restoreHint();

  // ignore: unawaited_futures
  onboardingController.load();

  final navigatorKey = GlobalKey<NavigatorState>();
  final deepLinks = DeepLinkHandler(navigatorKey);
  unawaited(deepLinks.start());

  runApp(
    MultiProvider(
      providers: [
        Provider<OrdersRemoteDataSource>.value(value: ordersDs),
        Provider<TokenManager>.value(value: tokenManager),
        Provider<MarketplaceRemoteDataSource>.value(value: marketplaceDs),
        Provider<BannerDetailRemoteDataSource>.value(value: bannerDetailDs),
        Provider<CategoriesRemoteDataSource>.value(value: categoriesDs),
        Provider<ReviewsRemoteDataSource>.value(value: reviewsDs),
        Provider<RecentlyViewedRemoteDataSource>.value(value: recentlyViewedDs),
        Provider<ReturnsRemoteDataSource>.value(value: returnsDs),
        Provider<CouponsRemoteDataSource>.value(value: couponsDs),
        Provider<AvatarRemoteDataSource>.value(value: avatarDs),
        ChangeNotifierProvider<CategoriesProvider>.value(
            value: categoriesProvider),
        ChangeNotifierProvider<OnboardingController>.value(
            value: onboardingController),
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: notificationsProvider),
        ChangeNotifierProvider<ShopsProvider>.value(value: shopsProvider),
        ChangeNotifierProvider<LinkedMerchantsProvider>.value(value: linkedMerchantsProvider),
        ChangeNotifierProvider<CartProvider>.value(value: cartProvider),
        ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
        ChangeNotifierProvider<WishlistProvider>.value(value: wishlistProvider),
        ChangeNotifierProvider<AddressesProvider>.value(value: addressesProvider),
        ChangeNotifierProvider<GstProfileProvider>.value(value: gstProfileProvider),
        ChangeNotifierProvider<SearchProvider>(
          create: (_) => SearchProvider(marketplaceSearchDs),
        ),
        ChangeNotifierProvider<HomeFeedProvider>.value(value: homeFeedProvider),
        Provider<TrackingService>.value(value: trackingService),
      ],
      child: ShopxyCustomerApp(navigatorKey: navigatorKey),
    ),
  );

  authProvider.init();
}
