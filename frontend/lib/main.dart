import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/app.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/custom_fields/data/datasources/custom_fields_remote_data_source.dart';
import 'package:shopxy/features/custom_fields/presentation/providers/custom_fields_provider.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:shopxy/features/reports/presentation/providers/reports_provider.dart';
import 'package:shopxy/features/shop/data/datasources/shop_remote_data_source.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/features/admin/data/datasources/admin_bank_offers_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_banners_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_shops_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_collections_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_spotlight_remote_data_source.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_bank_offers_provider.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_banners_provider.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_spotlight_provider.dart';
import 'package:shopxy/features/carousel/data/datasources/carousels_remote_data_source.dart';
import 'package:shopxy/features/carousel/data/datasources/merchant_carousel_remote_data_source.dart';
import 'package:shopxy/features/carousel/presentation/providers/carousels_provider.dart';
import 'package:shopxy/features/carousel/presentation/providers/merchant_carousel_provider.dart';
import 'package:shopxy/features/flash_deals/data/datasources/flash_deals_remote_data_source.dart';
import 'package:shopxy/features/flash_deals/presentation/providers/flash_deals_provider.dart';
import 'package:shopxy/features/spotlight/data/datasources/spotlight_remote_data_source.dart';
import 'package:shopxy/features/spotlight/presentation/providers/spotlight_provider.dart';
import 'package:shopxy/features/analytics/data/datasources/analytics_remote_data_source.dart';
import 'package:shopxy/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:shopxy/features/promotions/data/datasources/promotions_remote_data_source.dart';
import 'package:shopxy/features/promotions/presentation/providers/promotions_provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/presentation/providers/parties_provider.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/presentation/providers/payments_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/presentation/providers/vendors_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail-fast in release if API_BASE_URL was missed or points at a dev host.
  AppConfig.assertSafeForRelease();

  // Load tokens from secure storage before rendering anything
  final tokenManager = TokenManager();
  await tokenManager.init();

  // Reuse the same secure-storage container we already use for tokens
  // for tiny user prefs (currently just nav style). Awaited so the
  // first frame already reflects the saved choice.
  final navPrefs = NavigationPrefsProvider(const FlutterSecureStorage());
  await navPrefs.load();

  final apiClient = ApiClient(tokenManager);

  // Data sources
  final authDs = AuthRemoteDataSource(apiClient);
  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final customFieldsDs = CustomFieldsRemoteDataSource(apiClient);
  final productsDs = ProductsRemoteDataSource(apiClient);
  final stockDs = StockRemoteDataSource(apiClient);
  final dashboardDs = DashboardRemoteDataSource(apiClient);
  final invoicesDs = InvoicesRemoteDataSource(apiClient);
  final vendorsDs = VendorsRemoteDataSource(apiClient);
  final partiesDs = PartiesRemoteDataSource(apiClient);
  final challansDs = ChallansRemoteDataSource(apiClient);
  final stockAdjustmentsDs = StockAdjustmentsRemoteDataSource(apiClient);
  final notificationsDs = NotificationsRemoteDataSource(apiClient);
  final invitationsDs = InvitationsRemoteDataSource(apiClient);
  final reportsDs = ReportsRemoteDataSource(apiClient);
  final ordersDs = OrdersRemoteDataSource(apiClient);
  final ordersProvider = OrdersProvider(ordersDs);
  final paymentsDs = PaymentsRemoteDataSource(apiClient);
  final shopDs = ShopRemoteDataSource(apiClient);
  final adminBannersDs = AdminBannersRemoteDataSource(apiClient);
  final merchantCarouselDs = MerchantCarouselRemoteDataSource(apiClient);
  final carouselsDs = CarouselsRemoteDataSource(apiClient);
  final carouselsProvider = CarouselsProvider(carouselsDs);
  final adminSpotlightDs = AdminSpotlightRemoteDataSource(apiClient);
  final adminCollectionsDs = AdminCollectionsRemoteDataSource(apiClient);
  final adminBankOffersDs = AdminBankOffersRemoteDataSource(apiClient);
  final adminShopsDs = AdminShopsRemoteDataSource(apiClient);
  final flashDealsDs = FlashDealsRemoteDataSource(apiClient);
  final spotlightDs = SpotlightRemoteDataSource(apiClient);
  final analyticsDs = AnalyticsRemoteDataSource(apiClient);
  final promotionsDs = PromotionsRemoteDataSource(apiClient);

  final notificationsProvider = NotificationsProvider(notificationsDs, invitationsDs);

  // Auth provider (created before runApp so we can wire the callback)
  final authProvider = AuthProvider(authDs, tokenManager);

  // Eagerly-created user-scoped providers — registered with
  // AuthProvider.registerOnClear so logout / 401-refresh drops the
  // previous user's cached lists. Without these, user B sees A's
  // products/invoices/etc. flash on screen for a frame.
  final productsProvider = ProductsProvider(productsDs);
  final invoicesProvider = InvoicesProvider(invoicesDs);
  final vendorsProvider = VendorsProvider(vendorsDs);
  final partiesProvider = PartiesProvider(partiesDs);
  final challansProvider = ChallansProvider(challansDs);
  final shopProvider = ShopProvider(shopDs);

  authProvider.registerOnClear(notificationsProvider.reset);
  authProvider.registerOnClear(productsProvider.reset);
  authProvider.registerOnClear(invoicesProvider.reset);
  authProvider.registerOnClear(vendorsProvider.reset);
  authProvider.registerOnClear(partiesProvider.reset);
  authProvider.registerOnClear(challansProvider.reset);
  authProvider.registerOnClear(shopProvider.reset);
  authProvider.registerOnClear(ordersProvider.reset);
  authProvider.registerOnClear(carouselsProvider.reset);

  // When ApiClient can't recover a 401 (refresh failed), force re-login
  // — the registered callbacks fan out via clearAuth().
  tokenManager.onUnauthorized = () {
    authProvider.clearAuth();
  };

  // Keep the pending-orders badge fresh on session change.
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      ordersProvider.refreshPendingCount();
    }
  });

  // Whenever the session changes (login or logout), refresh the bell
  // badge so it reflects the new user immediately. Single listener for
  // the app lifetime; doesn't leak.
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      notificationsProvider.refreshUnreadCount();
      notificationsProvider.loadIncoming(status: 'PENDING');
    } else {
      notificationsProvider.reset();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        // Auth first — _AuthGate reads this
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NavigationPrefsProvider>.value(value: navPrefs),

        // Raw HTTP client — surfaced for widgets that hit small endpoints
        // (e.g. ContactChangesSection) without their own data-source layer.
        Provider<ApiClient>.value(value: apiClient),

        // Data sources available for direct injection (e.g. detail pages)
        Provider<ProductsRemoteDataSource>.value(value: productsDs),
        Provider<StockRemoteDataSource>.value(value: stockDs),
        Provider<InvoicesRemoteDataSource>.value(value: invoicesDs),
        Provider<VendorsRemoteDataSource>.value(value: vendorsDs),
        Provider<PartiesRemoteDataSource>.value(value: partiesDs),
        Provider<PaymentsRemoteDataSource>.value(value: paymentsDs),
        Provider<ChallansRemoteDataSource>.value(value: challansDs),
        Provider<StockAdjustmentsRemoteDataSource>.value(value: stockAdjustmentsDs),
        Provider<CategoriesRemoteDataSource>.value(value: categoriesDs),
        Provider<CustomFieldsRemoteDataSource>.value(value: customFieldsDs),

        // Feature state providers
        ChangeNotifierProvider(create: (_) => DashboardProvider(dashboardDs)),
        ChangeNotifierProvider(create: (_) => CategoriesProvider(categoriesDs)),
        ChangeNotifierProvider(
          create: (_) => CustomFieldsProvider(customFieldsDs),
        ),
        ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
        ChangeNotifierProvider(create: (_) => StockProvider(stockDs)),
        ChangeNotifierProvider<InvoicesProvider>.value(value: invoicesProvider),
        ChangeNotifierProvider<VendorsProvider>.value(value: vendorsProvider),
        ChangeNotifierProvider<PartiesProvider>.value(value: partiesProvider),
        ChangeNotifierProvider(create: (_) => PaymentsProvider(paymentsDs)),
        ChangeNotifierProvider<ChallansProvider>.value(value: challansProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(value: notificationsProvider),
        ChangeNotifierProvider(create: (_) => ReportsProvider(reportsDs)),
        ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
        ChangeNotifierProvider(create: (_) => AdminBannersProvider(adminBannersDs)),
        ChangeNotifierProvider(
          create: (_) => MerchantCarouselProvider(merchantCarouselDs),
        ),
        ChangeNotifierProvider<CarouselsProvider>.value(value: carouselsProvider),
        ChangeNotifierProvider(create: (_) => AdminSpotlightProvider(adminSpotlightDs)),
        ChangeNotifierProvider(create: (_) => AdminCollectionsProvider(adminCollectionsDs)),
        ChangeNotifierProvider(create: (_) => AdminBankOffersProvider(adminBankOffersDs)),
        Provider<AdminShopsRemoteDataSource>.value(value: adminShopsDs),
        ChangeNotifierProvider(create: (_) => FlashDealsProvider(flashDealsDs)),
        ChangeNotifierProvider(create: (_) => SpotlightProvider(spotlightDs)),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider(analyticsDs)),
        ChangeNotifierProvider(create: (_) => PromotionsProvider(promotionsDs)),
        ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
      ],
      child: const ShopxyApp(),
    ),
  );

  // Restore session after runApp so the splash screen shows during init
  authProvider.init();
}
