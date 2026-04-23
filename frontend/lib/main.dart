import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/app.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/challans/data/datasources/challans_remote_data_source.dart';
import 'package:shopxy/features/challans/presentation/providers/challans_provider.dart';
import 'package:shopxy/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/features/invoices/data/datasources/invoices_remote_data_source.dart';
import 'package:shopxy/features/invoices/presentation/providers/invoices_provider.dart';
import 'package:shopxy/features/parties/data/datasources/parties_remote_data_source.dart';
import 'package:shopxy/features/parties/presentation/providers/parties_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';
import 'package:shopxy/features/vendors/data/datasources/vendors_remote_data_source.dart';
import 'package:shopxy/features/vendors/presentation/providers/vendors_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load tokens from secure storage before rendering anything
  final tokenManager = TokenManager();
  await tokenManager.init();

  final apiClient = ApiClient(tokenManager);

  // Data sources
  final authDs = AuthRemoteDataSource(apiClient);
  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final productsDs = ProductsRemoteDataSource(apiClient);
  final stockDs = StockRemoteDataSource(apiClient);
  final dashboardDs = DashboardRemoteDataSource(apiClient);
  final invoicesDs = InvoicesRemoteDataSource(apiClient);
  final vendorsDs = VendorsRemoteDataSource(apiClient);
  final partiesDs = PartiesRemoteDataSource(apiClient);
  final challansDs = ChallansRemoteDataSource(apiClient);

  // Auth provider (created before runApp so we can wire the callback)
  final authProvider = AuthProvider(authDs, tokenManager);

  // When ApiClient can't recover a 401 (refresh failed), force re-login
  tokenManager.onUnauthorized = authProvider.clearAuth;

  runApp(
    MultiProvider(
      providers: [
        // Auth first — _AuthGate reads this
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),

        // Data sources available for direct injection (e.g. detail pages)
        Provider<ProductsRemoteDataSource>.value(value: productsDs),
        Provider<StockRemoteDataSource>.value(value: stockDs),
        Provider<InvoicesRemoteDataSource>.value(value: invoicesDs),
        Provider<VendorsRemoteDataSource>.value(value: vendorsDs),
        Provider<PartiesRemoteDataSource>.value(value: partiesDs),
        Provider<ChallansRemoteDataSource>.value(value: challansDs),

        // Feature state providers
        ChangeNotifierProvider(create: (_) => DashboardProvider(dashboardDs)),
        ChangeNotifierProvider(create: (_) => CategoriesProvider(categoriesDs)),
        ChangeNotifierProvider(create: (_) => ProductsProvider(productsDs)),
        ChangeNotifierProvider(create: (_) => StockProvider(stockDs)),
        ChangeNotifierProvider(create: (_) => InvoicesProvider(invoicesDs)),
        ChangeNotifierProvider(create: (_) => VendorsProvider(vendorsDs)),
        ChangeNotifierProvider(create: (_) => PartiesProvider(partiesDs)),
        ChangeNotifierProvider(create: (_) => ChallansProvider(challansDs)),
      ],
      child: const ShopxyApp(),
    ),
  );

  // Restore session after runApp so the splash screen shows during init
  authProvider.init();
}
