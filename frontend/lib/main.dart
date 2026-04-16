import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/app.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/categories/data/datasources/categories_remote_data_source.dart';
import 'package:shopxy/features/categories/presentation/providers/categories_provider.dart';
import 'package:shopxy/features/dashboard/data/datasources/dashboard_remote_data_source.dart';
import 'package:shopxy/features/dashboard/presentation/providers/dashboard_provider.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/stock/data/datasources/stock_remote_data_source.dart';
import 'package:shopxy/features/stock/presentation/providers/stock_provider.dart';

void main() {
  const apiClient = ApiClient();

  final categoriesDs = CategoriesRemoteDataSource(apiClient);
  final productsDs = ProductsRemoteDataSource(apiClient);
  final stockDs = StockRemoteDataSource(apiClient);
  final dashboardDs = DashboardRemoteDataSource(apiClient);

  runApp(
    MultiProvider(
      providers: [
        // Data sources (available for direct injection where needed)
        Provider<ProductsRemoteDataSource>.value(value: productsDs),

        // State providers
        ChangeNotifierProvider(create: (_) => DashboardProvider(dashboardDs)),
        ChangeNotifierProvider(create: (_) => CategoriesProvider(categoriesDs)),
        ChangeNotifierProvider(create: (_) => ProductsProvider(productsDs)),
        ChangeNotifierProvider(create: (_) => StockProvider(stockDs)),
      ],
      child: const ShopxyApp(),
    ),
  );
}
