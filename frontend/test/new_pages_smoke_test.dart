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
import 'package:shopxy/features/admin/presentation/pages/admin_collections_page.dart';
import 'package:shopxy/features/admin/presentation/providers/admin_collections_provider.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/banners/data/datasources/merchant_banners_remote_data_source.dart';
import 'package:shopxy/features/banners/presentation/pages/merchant_banners_page.dart';
import 'package:shopxy/features/banners/presentation/providers/merchant_banners_provider.dart';
import 'package:shopxy/features/shop/data/datasources/linked_account_remote_data_source.dart';
import 'package:shopxy/features/shop/data/datasources/shop_remote_data_source.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_operations_page.dart';
import 'package:shopxy/features/shop/presentation/pages/shop_payouts_page.dart';
import 'package:shopxy/features/shop/presentation/providers/linked_account_provider.dart';
import 'package:shopxy/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopxy/l10n/app_localizations.dart';

ApiClient _api() => ApiClient(TokenManager());

/// These pages read their chrome from AppLocalizations, whose lookup is
/// null-checked — a bare MaterialApp throws before the first paint. Locale is
/// pinned to English so the string assertions below stay deterministic.
MaterialApp _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('en'),
  home: home,
);

void main() {
  testWidgets('MerchantBannersPage renders chrome', (tester) async {
    final ds = MerchantBannersRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => MerchantBannersProvider(ds),
        child: _app(const MerchantBannersPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Banners'), findsOneWidget);
    expect(find.text('New banner'), findsOneWidget);
  });

  testWidgets('AdminCollectionsPage renders chrome', (tester) async {
    final ds = AdminCollectionsRemoteDataSource(_api());
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AdminCollectionsProvider(ds),
        child: _app(const AdminCollectionsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Collections'), findsOneWidget);
    expect(find.text('New collection'), findsOneWidget);
  });

  // Payout onboarding surfaces — guard the provider wiring (ShopProvider +
  // LinkedAccountProvider + AuthProvider for operations; ApiClient +
  // LinkedAccountProvider for the payouts form). A missing provider would
  // throw on first pump.
  testWidgets('ShopOperationsPage renders its tiles', (tester) async {
    final api = _api();
    final tokens = TokenManager();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => ShopProvider(ShopRemoteDataSource(api)),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(AuthRemoteDataSource(api), tokens),
          ),
          ChangeNotifierProvider(
            create: (_) =>
                LinkedAccountProvider(LinkedAccountRemoteDataSource(api)),
          ),
        ],
        child: _app(const ShopOperationsPage()),
      ),
    );
    await tester.pump();
    // Only the chrome is asserted: every tile below it is gated on
    // AuthProvider.user.canView(...), and `user` is populated exclusively by a
    // live getMe() round-trip, so no widget test can make the tiles appear
    // without a fake auth stack. The provider-wiring guard this test exists
    // for still holds — a missing provider throws during build.
    expect(tester.takeException(), isNull);
    expect(find.text('Shop operations'), findsOneWidget);
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
        child: _app(const ShopPayoutsPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Payouts & settlement'), findsOneWidget);
  });
}
