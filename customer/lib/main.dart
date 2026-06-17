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
import 'package:shopxy_customer/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy_customer/features/banner_detail/data/datasources/banner_detail_remote_data_source.dart';
import 'package:shopxy_customer/features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy_customer/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy_customer/features/recently_viewed/data/datasources/recently_viewed_remote_data_source.dart';
import 'package:shopxy_customer/features/returns/data/datasources/returns_remote_data_source.dart';
import 'package:shopxy_customer/features/wallet/data/datasources/wallet_remote_data_source.dart';
import 'package:shopxy_customer/features/coupons/data/datasources/coupons_remote_data_source.dart';
import 'package:shopxy_customer/features/profile/data/datasources/avatar_remote_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail-fast in release if API_BASE_URL was missed or points at a dev host.
  AppConfig.assertSafeForRelease();

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
  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final reviewsDs = ReviewsRemoteDataSource(apiClient);
  final recentlyViewedDs = RecentlyViewedRemoteDataSource(apiClient);
  final returnsDs = ReturnsRemoteDataSource(apiClient);
  final walletDs = WalletRemoteDataSource(apiClient);
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
  final categoriesProvider = CategoriesProvider(categoriesDs);
  // First-run onboarding gate. Read the persisted flag now so the root
  // view can decide onboarding-vs-shell on the very first frame.
  final onboardingController = OnboardingController();

  // Wire user-scoped resets into AuthProvider.clearAuth() so the
  // refresh-failure path and any future caller (e.g. an explicit
  // "force logout" button) drop the same state. The cart's
  // `onLoggedOut` keeps the local items but flips the server-sync
  // flag off — see CartProvider for why we deliberately keep the
  // basket.
  authProvider.registerOnClear(notificationsProvider.reset);
  authProvider.registerOnClear(shopsProvider.reset);
  authProvider.registerOnClear(cartProvider.onLoggedOut);
  authProvider.registerOnClear(ordersProvider.reset);
  authProvider.registerOnClear(wishlistProvider.reset);
  authProvider.registerOnClear(addressesProvider.reset);
  authProvider.registerOnClear(linkedMerchantsProvider.reset);
  authProvider.registerOnClear(homeFeedProvider.clearPersonalized);

  // Explicit-logout-only: dump the local basket. We deliberately keep
  // it on transient 401-refresh failures (same user about to log back
  // in) but a user who taps "Log out" then someone else signs in on
  // the same device should NOT inherit the prior person's items.
  authProvider.registerOnExplicitLogout(cartProvider.clear);

  // Force re-login if the refresh fails.
  tokenManager.onUnauthorized = authProvider.clearAuth;

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
      // Server-side cart sync — merge any guest items into /me/cart
      // and pull the merged result back as the new authoritative state.
      cartProvider.syncFromServer(mergeLocal: true);

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
      // Don't clear the local cart on logout — the items survive as a
      // guest cart and will be re-merged on the next sign-in. Just
      // flip the server-sync flag off so mutations stop hitting /me/cart
      // (it would 401 with no token).
      cartProvider.onLoggedOut();
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
  // Restore the "was-linked-to-a-merchant" hint from disk so the
  // bottom-nav layout decision is right on the first paint. Without
  // this, the shell would render the unlinked layout (Home/Cart/
  // Orders/Profile), then flip to (Home/Merchant/Cart/Orders) the
  // moment /me/links resolves — a visible flicker.
  // ignore: unawaited_futures
  shopsProvider.restoreHint();

  // Read the onboarding-seen flag from disk. Fire-and-forget — the root
  // view shows the splash until `loaded` flips, so there's no flash of
  // onboarding for returning users.
  // ignore: unawaited_futures
  onboardingController.load();

  // Single navigator key so the deep-link handler can push routes
  // (PDP for /p/<id>) regardless of the active tab in the shell.
  // Both supported destinations are public, so no auth deferral is
  // needed — guests can open a shared product link straight away.
  final navigatorKey = GlobalKey<NavigatorState>();
  final deepLinks = DeepLinkHandler(navigatorKey);
  // Fire-and-forget: getInitialLink is awaited internally before the
  // first frame's postFrameCallback runs, and the stream subscription
  // survives the app lifetime.
  unawaited(deepLinks.start());

  runApp(
    MultiProvider(
      providers: [
        // Data sources — needed by detail pages that construct their own
        // loads (order detail) without a parent provider.
        Provider<OrdersRemoteDataSource>.value(value: ordersDs),
        // Token manager — needed by features (like invoice download)
        // that build authed requests outside of ApiClient.
        Provider<TokenManager>.value(value: tokenManager),
        // Public marketplace reads — PDP V2 + ShopProfilePage construct
        // their own loads from this DS rather than via a parent provider
        // so the data follows the productId/slug in the route arguments.
        Provider<MarketplaceRemoteDataSource>.value(value: marketplaceDs),
        Provider<BannerDetailRemoteDataSource>.value(value: bannerDetailDs),
        // Categories DS: the category-products page hits it directly so
        // route-scoped pages can load without a parent provider.
        Provider<CategoriesRemoteDataSource>.value(value: categoriesDs),
        // Reviews API — PDP section + all-reviews page + write sheet
        // all read this DS directly (no parent provider) so the page
        // can be opened by id from anywhere.
        Provider<ReviewsRemoteDataSource>.value(value: reviewsDs),
        // Recently-viewed list. Page is route-scoped (opened from Profile)
        // so it reads the DS directly instead of through a parent provider.
        Provider<RecentlyViewedRemoteDataSource>.value(value: recentlyViewedDs),
        // Returns + wallet — both used by route-scoped pages, so no
        // parent ChangeNotifier provider; the pages read the DS directly.
        Provider<ReturnsRemoteDataSource>.value(value: returnsDs),
        Provider<WalletRemoteDataSource>.value(value: walletDs),
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
      child: ShopxyCustomerApp(navigatorKey: navigatorKey),
    ),
  );

  authProvider.init();
}
