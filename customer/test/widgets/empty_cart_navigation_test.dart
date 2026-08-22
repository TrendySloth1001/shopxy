import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/core/router/app_shell.dart';
import 'package:shopxy_customer/features/cart/presentation/pages/cart_page.dart';
import 'package:shopxy_customer/features/catalog/data/datasources/cart_remote_data_source.dart';
import 'package:shopxy_customer/features/catalog/presentation/providers/cart_provider.dart';
import 'package:shopxy_customer/features/orders/data/datasources/orders_remote_data_source.dart';
import 'package:shopxy_customer/shared/theme/app_theme.dart';

CartProvider _emptyCart() {
  final api = ApiClient(TokenManager());
  return CartProvider(OrdersRemoteDataSource(api), CartRemoteDataSource(api));
}

void main() {
  testWidgets('embedded empty cart sends Continue shopping to the Home tab', (
    tester,
  ) async {
    final selected = <int>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<CartProvider>.value(
        value: _emptyCart(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: CustomerShellScope(
            index: 2,
            select: selected.add,
            child: const CartPage(embedded: true),
          ),
        ),
      ),
    );

    expect(find.text('Your cart is empty'), findsOneWidget);
    await tester.tap(find.text('Continue shopping'));
    await tester.pumpAndSettle();

    expect(selected, [0]);
  });

  testWidgets('pushed empty cart pops instead', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<CartProvider>.value(
        value: _emptyCart(),
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const CartPage()),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);

    await tester.tap(find.text('Continue shopping'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
