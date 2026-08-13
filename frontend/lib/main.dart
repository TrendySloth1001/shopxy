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
import 'package:shopxy/features/admin/data/datasources/admin_bank_offers_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_banners_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_shops_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_collections_remote_data_source.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_bank_offers_provider.dart';
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

  // A throw before `runApp` would leave the launch window up forever.
  try {
    AppConfig.assertSafeForRelease();

    // Read the developer environment choice BEFORE anything resolves a URL,
    // otherwise the first requests of the run go to the previous backend.
    await AppEnvironments.load();

    await bootstrapShopxy();
  } catch (error, stack) {
    debugPrint('ShopXY failed to start: $error
$stack');
    runApp(StartupFailureApp(error: error, stack: stack));
  }
}

/// Teardown hooks for the long-lived listeners the current object graph
/// leaves running. Populated by [bootstrapShopxy] and drained by it on the
/// next call — without this, switching environments would leave the previous
/// graph's outbox processor and connectivity prober alive alongside the new
/// one.
final List<void Function()> _graphDisposers = [];

/// Builds the entire object graph and hands it to `runApp`.
///
/// Extracted from [main] so the developer environment switcher
/// ([AppEnvironments]) can tear the app down and build it again against a
/// different backend. Everything stateful is a fresh instance — the token
/// store, the offline response cache, the outbox and every provider — so no
/// data from the previous environment's database can survive the switch. A
/// key-swap style "restart" would not do: the providers live above `runApp`,
/// so rebuilding the widget tree alone would re-attach the very state we're
/// trying to discard.
Future<void> bootstrapShopxy() async {
  // Snapshot the outgoing graph's teardown hooks and run them only once the
  // replacement root is mounted (bottom of this function). Disposing them here
  // would kill ChangeNotifiers — NetworkStatus above all — that the still-live
  // old widget tree is listening to, and the several awaits below give it
  // plenty of frames to rebuild and throw "used after dispose".
  final outgoing = List.of(_graphDisposers);
  _graphDisposers.clear();

  // Load tokens from secure storage before rendering anything
  final tokenManager = TokenManager();
  await tokenManager.init();

  // Reuse the same secure-storage container we already use for tokens
  // for tiny user prefs (currently just nav style). Awaited so the
  // first frame already reflects the saved choice.
  final navPrefs = NavigationPrefsProvider(appPrefsStorage);
  await navPrefs.load();

  // Theme choice (light / dark / OLED) — loaded before the first frame so the
  // app opens in the saved theme with no flash. Also primes AppPalette.active.
  final themePrefs = ThemePrefsProvider(appPrefsStorage);
  await themePrefs.load();

  // Haptics on/off — loaded before the first frame and attached to the
  // static AppHaptics gate so every tap-site call (nav, menu, scroll edges)
  // respects the saved choice from the very first interaction.
  final hapticsPrefs = HapticsPrefsProvider(appPrefsStorage);
  await hapticsPrefs.load();
  AppHaptics.attach(hapticsPrefs);

  // Offline layer (SSOT): one connectivity signal + one device response cache,
  // both injected into the single ApiClient so every read gets offline support
  // without touching data sources. Cache init is awaited so the first request
  // can already hit it.
  // The probe is what lets the app *recover* on its own. Every other signal
  // comes from a completed request, and while offline nothing issues one — the
  // outbox won't drain and screens serve cache — so without this the app can
  // sit behind the offline banner long after the network is back.
  //
  // `/health` is unauthenticated on purpose: probing an authed route while a
  // token has expired would answer 401 and start a refresh storm during exactly
  // the moment the network is flaky. And ANY completed response counts,
  // including 503 (`{status: 'degraded', db: 'down'}`) — the question here is
  // whether we can reach the network at all, not whether the server is well.
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
  // Coming back to the foreground is the strongest hint the answer changed —
  // a phone that slept through a network change wakes with the backoff already
  // at its 30s ceiling, and making someone watch a stale banner for half a
  // minute after they've opened the app is the visible half of this bug.
  // Retained for the graph's lifetime and torn down when the environment
  // switcher rebuilds it (see [_graphDisposers]).
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
  // Resolve the device name once (async, non-blocking) so requests carry
  // `X-Device-Name` for the sessions list. Auth calls are user-triggered
  // seconds later, well after this fast native lookup resolves.
  unawaited(
    DeviceInfoHelper.deviceName().then((n) => apiClient.deviceName = n),
  );

  // Data sources
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
  final adminBankOffersDs = AdminBankOffersRemoteDataSource(apiClient);
  final adminShopsDs = AdminShopsRemoteDataSource(apiClient);
  final reviewsDs = ReviewsRemoteDataSource(apiClient);
  final couponsDs = MerchantCouponsRemoteDataSource(apiClient);
  final returnsDs = MerchantReturnsRemoteDataSource(apiClient);

  final notificationsProvider = NotificationsProvider(
    notificationsDs,
    invitationsDs,
  );

  // Auth provider (created before runApp so we can wire the callback)
  final authProvider = AuthProvider(authDs, tokenManager);

  // Eagerly-created user-scoped providers — registered with
  // AuthProvider.registerOnClear so logout / 401-refresh drops the
  // previous user's cached lists. Without these, user B sees A's
  // products/invoices/etc. flash on screen for a frame.
  final productsProvider = ProductsProvider(productsDs);
  // The in-memory catalogue behind local product search in the invoice,
  // challan and quotation pickers. Loaded lazily by whichever picker opens
  // first; refreshed by the cache listener below when products change.
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
  // Hoisted to a local (was inline in the MultiProvider) so the cache-
  // revalidation listener below can reload it when the dashboard changes.
  final dashboardProvider = DashboardProvider(dashboardDs);
  // These five were previously created inline in the MultiProvider below
  // (`create: (_) => X(...)`), which meant nothing outside the widget tree
  // held a reference to register a clear-on-logout callback — the previous
  // shop's custom fields, stock history, quotations, reports and analytics
  // could all flash on screen for the next account on a shared device.
  // Hoisted here so they can be wired into the same fan-out as everything
  // else.
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
  // Purge the device response cache on logout / 401 / account-delete so the
  // next account can't see the previous user's cached business data.
  authProvider.registerOnClear(httpCache.wipe);
  // Drop any un-synced offline writes on logout too (they belong to the account
  // that's leaving).
  authProvider.registerOnClear(outbox.wipe);

  // Replays queued offline writes when the network returns (and once now, for
  // anything left from a previous offline session). `currentUserId` comes from
  // the same source as the cache/outbox namespace (TokenManager), so they can't
  // disagree, and it's available at boot — before AuthProvider loads the user.
  // Lives as long as the object graph does: its NetworkStatus listener keeps
  // it alive, and `dispose()` is called when the environment switcher rebuilds
  // the graph — a leaked processor from the previous environment would replay
  // its queued writes against the new backend.
  final outboxProcessor = OutboxProcessor(
    outbox: outbox,
    networkStatus: networkStatus,
    currentUserId: () => tokenManager.currentUserId,
    replay: (e) =>
        apiClient.sendRaw(e.method, e.path, body: e.body, headers: e.headers),
  )..start();
  _graphDisposers.add(outboxProcessor.dispose);

  // When ApiClient can't recover a 401 (refresh failed), force re-login
  // — the registered callbacks fan out via clearAuth().
  tokenManager.onUnauthorized = () {
    authProvider.clearAuth();
  };

  // Live permission sync: every authenticated response carries the
  // caller's perms version; when it changes (an owner edited this
  // staffer's access elsewhere) AuthProvider refetches /auth/me and the
  // gated UI rebuilds — on the next request, no re-login.
  apiClient.onPermsVersion = authProvider.notePermsVersion;

  // Keep the pending-orders badge fresh on session change.
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      ordersProvider.refreshPendingCount();
    }
  });

  // Stale-while-revalidate repaint: a cache-first GET paints instantly, then a
  // background revalidation fires this event if the server copy changed (incl.
  // a change made in another session, e.g. web). We reload the matching
  // provider so the screen refreshes in place. Single central listener → no
  // per-provider wiring. Errors are swallowed (background refresh).
  final cacheEventsSub = apiClient.cacheEvents.listen((tag) {
    final Future<void>? reload = switch (tag) {
      // Both: the grid reloads its current page, and the in-memory catalogue
      // refetches so a product created on web is findable in the pickers here
      // without a restart.
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
        ChangeNotifierProvider<ThemePrefsProvider>.value(value: themePrefs),
        ChangeNotifierProvider<HapticsPrefsProvider>.value(value: hapticsPrefs),
        // Offline connectivity signal — watched by the app-wide offline banner.
        ChangeNotifierProvider<NetworkStatus>.value(value: networkStatus),
        // Outbox exposed so the banner can show "syncing N changes" from its
        // pendingCount. Provided as nullable so a lookup never throws.
        Provider<Outbox?>.value(value: outbox),

        // Raw HTTP client — surfaced for widgets that hit small endpoints
        // (e.g. ContactChangesSection) without their own data-source layer.
        Provider<ApiClient>.value(value: apiClient),

        // Data sources available for direct injection (e.g. detail pages)
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

        // Feature state providers
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
        ChangeNotifierProvider(
          create: (_) => AdminBankOffersProvider(adminBankOffersDs),
        ),
        Provider<AdminShopsRemoteDataSource>.value(value: adminShopsDs),
        ChangeNotifierProvider<OrdersProvider>.value(value: ordersProvider),
      ],
      child: const ShopxyApp(),
    ),
  );

  // The replacement root is mounted — the previous graph is now detached and
  // safe to tear down. Best-effort: a throwing disposer must not stop the app
  // coming back up.
  for (final dispose in outgoing.reversed) {
    try {
      dispose();
    } catch (_) {
      // already torn down, or never fully started
    }
  }

  // Restore session after runApp so the splash screen shows during init
  authProvider.init();
}
