import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/app.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/startup_failure_app.dart';
import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:shopxy/core/config/app_config.dart';
import 'package:shopxy/core/config/app_environment.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/core/network/offline/http_cache.dart';
import 'package:shopxy/core/network/offline/network_status.dart';
import 'package:shopxy/core/network/offline/outbox.dart';
import 'package:shopxy/core/network/offline/outbox_processor.dart';
import 'package:shopxy/core/utils/device_info_helper.dart';
import 'package:shopxy/core/prefs/navigation_prefs.dart';
import 'package:shopxy/core/prefs/prefs_storage.dart';
import 'package:shopxy/core/prefs/theme_prefs.dart';
import 'package:shopxy/core/haptics/app_haptics.dart';
import 'package:shopxy/core/haptics/haptics_prefs.dart';
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
import 'package:shopxy/features/invoice_numbering/data/datasources/invoice_numbering_remote_data_source.dart';
import 'package:shopxy/features/invoice_numbering/presentation/providers/invoice_numbering_provider.dart';
import 'package:shopxy/features/pdf_templates/data/datasources/pdf_templates_remote_data_source.dart';
import 'package:shopxy/features/pdf_templates/presentation/providers/pdf_templates_provider.dart';
import 'package:shopxy/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy/features/orders/presentation/providers/orders_provider.dart';
import 'package:shopxy/features/reports/data/datasources/reports_remote_data_source.dart';
import 'package:shopxy/features/reports/presentation/providers/reports_provider.dart';
import 'package:shopxy/features/shop/data/datasources/shop_remote_data_source.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/features/admin/data/datasources/admin_banners_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_shops_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_collections_remote_data_source.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_banners_provider.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/features/banners/data/datasources/merchant_banners_remote_data_source.dart';
import 'package:shopxy/features/banners/presentation/providers/merchant_banners_provider.dart';
import 'package:shopxy/features/reviews/data/datasources/reviews_remote_data_source.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/presentation/providers/parties_provider.dart';
import 'package:shopxy/features/payments/data/datasources/payments_remote_data_source.dart';
import 'package:shopxy/features/payments/presentation/providers/payments_provider.dart';
import 'package:shopxy/features/quotations/data/datasources/quotations_remote_data_source.dart';
import 'package:shopxy/features/quotations/presentation/providers/quotations_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/presentation/providers/product_catalogue.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';
import 'package:shopxy/features/stock_adjustments/data/datasources/stock_adjustments_remote_data_source.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/presentation/providers/vendors_provider.dart';
import 'package:shopxy/features/coupons/data/datasources/merchant_coupons_remote_data_source.dart';
import 'package:shopxy/features/returns/data/datasources/merchant_returns_remote_data_source.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    AppConfig.assertSafeForRelease();

    await AppEnvironments.load();

    await bootstrapShopxy();
  } catch (error, stack) {
    debugPrint('ShopXY failed to start: $error\n$stack');
    runApp(StartupFailureApp(error: error, stack: stack));
  }
}

final List<void Function()> _graphDisposers = [];

Future<void> bootstrapShopxy() async {
  final outgoing = List.of(_graphDisposers);
  _graphDisposers.clear();

  final tokenManager = TokenManager();
  await tokenManager.init();

  final navPrefs = NavigationPrefsProvider(appPrefsStorage);
  await navPrefs.load();

  final themePrefs = ThemePrefsProvider(appPrefsStorage);
  await themePrefs.load();

  final hapticsPrefs = HapticsPrefsProvider(appPrefsStorage);
  await hapticsPrefs.load();
  AppHaptics.attach(hapticsPrefs);

  final networkStatus = NetworkStatus(
    probe: () async {
      try {
        final res = await http
            .get(Uri.parse('${AppConfig.apiBaseUrl}health'))
            .timeout(const Duration(seconds: 5));
        return res.statusCode > 0;
      } catch (_) {
        return false;
      }
    },
  );
  final lifecycle = AppLifecycleListener(
    onResume: networkStatus.probeNow,
  );
  _graphDisposers.add(lifecycle.dispose);
  _graphDisposers.add(networkStatus.dispose);

  final httpCache = HttpCache();
  final outbox = Outbox();
  await httpCache.init();
  await outbox.init();

  final apiClient = ApiClient(
    tokenManager,
    cache: httpCache,
    networkStatus: networkStatus,
    outbox: outbox,
  );
  unawaited(
    DeviceInfoHelper.deviceName().then((n) => apiClient.deviceName = n),
  );

  final authDs = AuthRemoteDataSource(apiClient);
  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final customFieldsDs = CustomFieldsRemoteDataSource(apiClient);
  final productsDs = ProductsRemoteDataSource(apiClient);
  final stockDs = StockRemoteDataSource(apiClient);
  final dashboardDs = DashboardRemoteDataSource(apiClient);
  final invoicesDs = InvoicesRemoteDataSource(apiClient);
  final invoiceNumberingDs = InvoiceNumberingRemoteDataSource(apiClient);
  final pdfTemplatesDs = PdfTemplatesRemoteDataSource(apiClient);
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
  final quotationsDs = QuotationsRemoteDataSource(apiClient);
  final shopDs = ShopRemoteDataSource(apiClient);
  final adminBannersDs = AdminBannersRemoteDataSource(apiClient);
  final merchantBannersDs = MerchantBannersRemoteDataSource(apiClient);
  final merchantBannersProvider = MerchantBannersProvider(merchantBannersDs);
  final adminCollectionsDs = AdminCollectionsRemoteDataSource(apiClient);
  final adminShopsDs = AdminShopsRemoteDataSource(apiClient);
  final reviewsDs = ReviewsRemoteDataSource(apiClient);
  final couponsDs = MerchantCouponsRemoteDataSource(apiClient);
  final returnsDs = MerchantReturnsRemoteDataSource(apiClient);

  final notificationsProvider = NotificationsProvider(
    notificationsDs,
    invitationsDs,
  );

  final authProvider = AuthProvider(authDs, tokenManager);

  final productsProvider = ProductsProvider(productsDs);
  final productCatalogue = ProductCatalogue(productsDs);
  final invoicesProvider = InvoicesProvider(invoicesDs);
  final invoiceNumberingProvider = InvoiceNumberingProvider(invoiceNumberingDs);
  final pdfTemplatesProvider = PdfTemplatesProvider(pdfTemplatesDs);
  final vendorsProvider = VendorsProvider(vendorsDs);
  final partiesProvider = PartiesProvider(partiesDs);
  final challansProvider = ChallansProvider(challansDs);
  final shopProvider = ShopProvider(shopDs);
  final linkedAccountProvider = LinkedAccountProvider(
    LinkedAccountRemoteDataSource(apiClient),
  );
  final dashboardProvider = DashboardProvider(dashboardDs);
  final customFieldsProvider = CustomFieldsProvider(customFieldsDs);
  final stockProvider = StockProvider(stockDs);
  final quotationsProvider = QuotationsProvider(quotationsDs);
  final reportsProvider = ReportsProvider(reportsDs);

  authProvider.registerOnClear(notificationsProvider.reset);
  authProvider.registerOnClear(productsProvider.reset);
  authProvider.registerOnClear(productCatalogue.reset);
  authProvider.registerOnClear(invoicesProvider.reset);
  authProvider.registerOnClear(invoiceNumberingProvider.reset);
  authProvider.registerOnClear(pdfTemplatesProvider.reset);
  authProvider.registerOnClear(vendorsProvider.reset);
  authProvider.registerOnClear(partiesProvider.reset);
  authProvider.registerOnClear(challansProvider.reset);
  authProvider.registerOnClear(shopProvider.reset);
  authProvider.registerOnClear(linkedAccountProvider.reset);
  authProvider.registerOnClear(ordersProvider.reset);
  authProvider.registerOnClear(merchantBannersProvider.reset);
  authProvider.registerOnClear(customFieldsProvider.reset);
  authProvider.registerOnClear(stockProvider.reset);
  authProvider.registerOnClear(quotationsProvider.reset);
  authProvider.registerOnClear(reportsProvider.reset);
  authProvider.registerOnClear(httpCache.wipe);
  authProvider.registerOnClear(outbox.wipe);

  final outboxProcessor = OutboxProcessor(
    outbox: outbox,
    networkStatus: networkStatus,
    currentUserId: () => tokenManager.currentUserId,
    replay: (e) =>
        apiClient.sendRaw(e.method, e.path, body: e.body, headers: e.headers),
  )..start();
  _graphDisposers.add(outboxProcessor.dispose);

  tokenManager.onUnauthorized = () {
    authProvider.clearAuth();
  };

  apiClient.onPermsVersion = authProvider.notePermsVersion;

  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      ordersProvider.refreshPendingCount();
    }
  });

  final cacheEventsSub = apiClient.cacheEvents.listen((tag) {
    final Future<void>? reload = switch (tag) {
      'products' => Future.wait<void>([
        productsProvider.loadProducts(),
        productCatalogue.refresh(),
      ]).then<void>((_) {}),
      'invoices' => invoicesProvider.loadInvoices(refresh: true),
      'parties' => partiesProvider.loadParties(refresh: true),
      'vendors' => vendorsProvider.loadVendors(refresh: true),
      'challans' => challansProvider.loadChallans(refresh: true),
      'orders' => ordersProvider.load(),
      'dashboard' => dashboardProvider.loadStats(),
      'notifications' => notificationsProvider.loadInbox(),
      _ => null,
    };
    if (reload != null) unawaited(reload.catchError((_) {}));
  });
  _graphDisposers.add(() => unawaited(cacheEventsSub.cancel()));

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
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NavigationPrefsProvider>.value(value: navPrefs),
        ChangeNotifierProvider<ThemePrefsProvider>.value(value: themePrefs),
        ChangeNotifierProvider<HapticsPrefsProvider>.value(value: hapticsPrefs),
        ChangeNotifierProvider<NetworkStatus>.value(value: networkStatus),
        Provider<Outbox?>.value(value: outbox),

        Provider<ApiClient>.value(value: apiClient),

        Provider<ProductsRemoteDataSource>.value(value: productsDs),
        Provider<StockRemoteDataSource>.value(value: stockDs),
        Provider<InvoicesRemoteDataSource>.value(value: invoicesDs),
        Provider<InvoiceNumberingRemoteDataSource>.value(
          value: invoiceNumberingDs,
        ),
        Provider<PdfTemplatesRemoteDataSource>.value(value: pdfTemplatesDs),
        Provider<VendorsRemoteDataSource>.value(value: vendorsDs),
        Provider<PartiesRemoteDataSource>.value(value: partiesDs),
        Provider<PaymentsRemoteDataSource>.value(value: paymentsDs),
        Provider<QuotationsRemoteDataSource>.value(value: quotationsDs),
        Provider<ReportsRemoteDataSource>.value(value: reportsDs),
        Provider<ChallansRemoteDataSource>.value(value: challansDs),
        Provider<StockAdjustmentsRemoteDataSource>.value(
          value: stockAdjustmentsDs,
        ),
        Provider<CategoriesRemoteDataSource>.value(value: categoriesDs),
        Provider<CustomFieldsRemoteDataSource>.value(value: customFieldsDs),
        Provider<ReviewsRemoteDataSource>.value(value: reviewsDs),
        Provider<MerchantCouponsRemoteDataSource>.value(value: couponsDs),
        Provider<MerchantReturnsRemoteDataSource>.value(value: returnsDs),

        ChangeNotifierProvider<DashboardProvider>.value(
          value: dashboardProvider,
        ),
        ChangeNotifierProvider(create: (_) => CategoriesProvider(categoriesDs)),
        ChangeNotifierProvider<CustomFieldsProvider>.value(
          value: customFieldsProvider,
        ),
        ChangeNotifierProvider<ProductsProvider>.value(value: productsProvider),
        ChangeNotifierProvider<ProductCatalogue>.value(value: productCatalogue),
        ChangeNotifierProvider<StockProvider>.value(value: stockProvider),
        ChangeNotifierProvider<InvoicesProvider>.value(value: invoicesProvider),
        ChangeNotifierProvider<InvoiceNumberingProvider>.value(
          value: invoiceNumberingProvider,
        ),
        ChangeNotifierProvider<PdfTemplatesProvider>.value(
          value: pdfTemplatesProvider,
        ),
        ChangeNotifierProvider<VendorsProvider>.value(value: vendorsProvider),
        ChangeNotifierProvider<PartiesProvider>.value(value: partiesProvider),
        ChangeNotifierProvider(create: (_) => PaymentsProvider(paymentsDs)),
        ChangeNotifierProvider<QuotationsProvider>.value(
          value: quotationsProvider,
        ),
        ChangeNotifierProvider<ChallansProvider>.value(value: challansProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
          value: notificationsProvider,
        ),
        ChangeNotifierProvider<ReportsProvider>.value(value: reportsProvider),
        ChangeNotifierProvider<ShopProvider>.value(value: shopProvider),
        ChangeNotifierProvider<LinkedAccountProvider>.value(
          value: linkedAccountProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => AdminBannersProvider(adminBannersDs),
        ),
        ChangeNotifierProvider<MerchantBannersProvider>.value(
          value: merchantBannersProvider,
        ),
        ChangeNotifierProvider(
          create: (_) => AdminCollectionsProvider(adminCollectionsDs),
        ),
        Provider<AdminShopsRemoteDataSource>.value(value: adminShopsDs),
        ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
      ],
      child: const ShopxyApp(),
    ),
  );

  for (final dispose in outgoing.reversed) {
    try {
      dispose();
    } catch (_) {
    }
  }

  authProvider.init();
}
