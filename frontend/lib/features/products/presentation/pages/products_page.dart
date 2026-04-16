import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/pages/product_detail_page.dart';
import 'package:shopxy/features/products/presentation/pages/qr_scanner_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/products/presentation/widgets/product_list_tile.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<ProductsProvider>().loadProducts(),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openScanner() async {
    final product = await Navigator.push<Product>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (product != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailPage(productId: product.id),
        ),
      );
    }
  }

  void _openAddProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddEditProductPage()),
    );
    if (created == true && mounted) {
      context.read<ProductsProvider>().loadProducts();
    }
  }

  void _openProductDetail(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(productId: product.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.navProducts),
        actions: [
          IconButton(
            onPressed: _openScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: AppStrings.scanQr,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.lg,
              vertical: AppSizes.sm,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchProducts,
              controller: _searchController,
              onChanged: (value) => provider.setSearch(value),
              trailing: IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded, size: AppSizes.iconMd),
                onPressed: _openScanner,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ),
          Expanded(
            child: provider.isLoading && provider.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.products.isEmpty
                    ? EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: AppStrings.noProducts,
                        subtitle: AppStrings.noProductsHint,
                      )
                    : RefreshIndicator(
                        onRefresh: () => provider.loadProducts(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.lg,
                            vertical: AppSizes.sm,
                          ),
                          itemCount: provider.products.length +
                              (provider.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index >= provider.products.length) {
                              provider.loadProducts(loadMore: true);
                              return const Padding(
                                padding: EdgeInsets.all(AppSizes.lg),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            final product = provider.products[index];
                            return ProductListTile(
                              product: product,
                              onTap: () => _openProductDetail(product),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddProduct,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }
}
