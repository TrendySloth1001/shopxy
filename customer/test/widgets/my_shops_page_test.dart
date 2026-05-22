import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/domain/entities/linked_shop.dart';
import 'package:shopxy_customer/features/shops/presentation/pages/my_shops_page.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';
import 'package:shopxy_customer/shared/theme/app_theme.dart';

import '../fakes/fake_providers.dart';

Widget _wrap({required ShopsProvider shops, required NotificationsProvider notifs}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ShopsProvider>.value(value: shops),
      ChangeNotifierProvider<NotificationsProvider>.value(value: notifs),
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const MyShopsPage(),
    ),
  );
}

void main() {
  testWidgets('renders empty-state copy when no shops are linked', (tester) async {
    await tester.pumpWidget(_wrap(
      shops: FakeShopsProvider(),
      notifs: FakeNotificationsProvider(),
    ));
    await tester.pump();

    expect(find.text('No shops yet'), findsOneWidget);
    expect(
      find.textContaining('When a shop invites you'),
      findsOneWidget,
    );
  });

  testWidgets('renders party shop with role chip and invoice count',
      (tester) async {
    final shop = fakeShop(
      id: 7,
      name: 'Bharat Traders',
      role: ShopRole.party,
      invoiceCount: 4,
    );
    await tester.pumpWidget(_wrap(
      shops: FakeShopsProvider(seedShops: [shop]),
      notifs: FakeNotificationsProvider(),
    ));
    await tester.pump();

    expect(find.text('Bharat Traders'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('4 invoices'), findsOneWidget);
  });

  testWidgets('vendor role displays the Supplier chip', (tester) async {
    final shop = fakeShop(
      id: 12,
      name: 'Mehta Industries',
      role: ShopRole.vendor,
      invoiceCount: 1,
    );
    await tester.pumpWidget(_wrap(
      shops: FakeShopsProvider(seedShops: [shop]),
      notifs: FakeNotificationsProvider(),
    ));
    await tester.pump();

    expect(find.text('Mehta Industries'), findsOneWidget);
    expect(find.text('Supplier'), findsOneWidget);
    expect(find.text('1 invoice'), findsOneWidget);
  });

  testWidgets('shows pending-invite banner when invitations are waiting',
      (tester) async {
    await tester.pumpWidget(_wrap(
      shops: FakeShopsProvider(),
      notifs: FakeNotificationsProvider(
        seedPending: [fakePendingInvitation(fromShopName: 'Acme Stores')],
      ),
    ));
    await tester.pump();

    expect(find.text('You have a pending invitation'), findsOneWidget);
    expect(find.textContaining('Acme Stores'), findsOneWidget);
  });

  testWidgets('pluralises the pending callout when there are several',
      (tester) async {
    await tester.pumpWidget(_wrap(
      shops: FakeShopsProvider(),
      notifs: FakeNotificationsProvider(
        seedPending: [
          fakePendingInvitation(id: 1, fromShopName: 'Acme Stores'),
          fakePendingInvitation(id: 2, fromShopName: 'Bharat Traders'),
          fakePendingInvitation(id: 3, fromShopName: 'Mehta Industries'),
        ],
      ),
    ));
    await tester.pump();

    expect(
      find.textContaining('Acme Stores and 2 others are waiting'),
      findsOneWidget,
    );
  });
}
