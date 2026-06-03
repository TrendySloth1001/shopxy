// Smoke tests for the merchant pages added in P4–P9.
//
// Each test mounts a page wrapped in MaterialApp + its provider and
// asserts the static chrome (app bar title, FAB label) renders on the
// first frame. The provider's `load()` fires a network call that will
// fail in the test environment (no server) — that's fine; providers
// catch the error and the page still renders.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/admin/data/datasources/admin_collections_remote_data_source.dart';
import 'package:shopxy/features/admin/data/datasources/admin_spotlight_remote_data_source.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_collections_page.dart';
import 'package:shopxy/features/admin/presentation/pages/admin_spotlight_approval_page.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_spotlight_provider.dart';
import 'package:shopxy/features/analytics/data/datasources/analytics_remote_data_source.dart';
import 'package:shopxy/features/analytics/presentation/pages/merchant_analytics_page.dart';
import 'package:shopxy/features/analytics/presentation/providers/analytics_provider.dart';
import 'package:shopxy/features/promotions/data/datasources/promotions_remote_data_source.dart';
import 'package:shopxy/features/promotions/presentation/pages/promotion_manager_page.dart';
import 'package:shopxy/features/promotions/presentation/providers/promotions_provider.dart';
import 'package:shopxy/features/spotlight/data/datasources/spotlight_remote_data_source.dart';
import 'package:shopxy/features/spotlight/presentation/pages/spotlight_request_page.dart';
import 'package:shopxy/features/spotlight/presentation/providers/spotlight_provider.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/features/shop/data/datasources/shop_remote_data_source.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_operations_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_payouts_page.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';

ApiClient _api() => ApiClient(TokenManager());

void main() {
  testWidgets('SpotlightRequestPage renders chrome', (tester) async {
    final ds = SpotlightRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SpotlightProvider(ds),
        child: const MaterialApp(home: SpotlightRequestPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Brand spotlight'), findsOneWidget);
    expect(find.text('Request slot'), findsOneWidget);
  });

  testWidgets('PromotionManagerPage renders chrome', (tester) async {
    final ds = PromotionsRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PromotionsProvider(ds),
        child: const MaterialApp(home: PromotionManagerPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Promotions'), findsOneWidget);
    expect(find.text('New promo'), findsOneWidget);
  });

  testWidgets('MerchantAnalyticsPage renders the app bar', (tester) async {
    final ds = AnalyticsRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AnalyticsProvider(ds),
        child: const MaterialApp(home: MerchantAnalyticsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Analytics'), findsOneWidget);
  });

  testWidgets('AdminSpotlightApprovalPage renders filter chips',
      (tester) async {
    final ds = AdminSpotlightRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AdminSpotlightProvider(ds),
        child: const MaterialApp(home: AdminSpotlightApprovalPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Spotlight approvals'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
    expect(find.text('Rejected'), findsOneWidget);
  });

  testWidgets('AdminCollectionsPage renders chrome', (tester) async {
    final ds = AdminCollectionsRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AdminCollectionsProvider(ds),
        child: const MaterialApp(home: AdminCollectionsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('New collection'), findsOneWidget);
  });

  // Payout onboarding surfaces — guard the provider wiring (ShopProvider +
  // LinkedAccountProvider for operations; ApiClient + LinkedAccountProvider
  // for the payouts form). A missing provider would throw on first pump.
  testWidgets('ShopOperationsPage renders its tiles', (tester) async {
    final api = _api();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ShopProvider(ShopRemoteDataSource(api)),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                LinkedAccountProvider(LinkedAccountRemoteDataSource(api)),
          ),
        ],
        child: const MaterialApp(home: ShopOperationsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Shop operations'), findsOneWidget);
    expect(find.text('Payouts & settlement'), findsOneWidget);
    expect(find.text('KYC documents'), findsOneWidget);
  });

  testWidgets('ShopPayoutsPage renders chrome', (tester) async {
    final api = _api();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ApiClient>.value(value: api),
          ChangeNotifierProvider(
            create: (_) =>
                LinkedAccountProvider(LinkedAccountRemoteDataSource(api)),
          ),
        ],
        child: const MaterialApp(home: ShopPayoutsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Payouts & settlement'), findsOneWidget);
  });
}
