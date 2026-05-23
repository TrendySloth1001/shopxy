import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/router/app_shell.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/add_edit_product_page.dart';
import 'package:shopxy/features/products/presentation/pages/product_detail_page.dart';
import 'package:shopxy/features/products/presentation/pages/qr_scanner_page.dart';
import 'package:shopxy/features/products/presentation/providers/products_provider.dart';
import 'package:shopxy/features/products/presentation/widgets/product_list_tile.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/widgets/app_button.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_filter_pill.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

/// Products listing — same chassis as the Parties and Vendors pages
/// (AppBar `+` action, [AppSearchBar] header, [ListView.separated]
/// with [AppDivider] rows). Extras specific to inventory: a scan
/// trailing in the search field, a filter strip for low-stock and
/// categories, and section headers grouping by category when the
/// user hasn't narrowed the list.
class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  final _searchController = TextEditingController();

  // Picker returns the chosen category's name so the chip can display
  // it without us having to fetch the full category list up-front
  // (which doesn't scale past a few hundred entries).
  String? _selectedCategoryName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ProductsProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openScanner() async {
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

  Future<void> _openAddProduct() async {
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

  void _scheduleLoadMore() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<ProductsProvider>();
      if (!provider.isLoading && provider.hasMore) {
        provider.loadProducts(loadMore: true);
      }
    });
  }

  Future<void> _openCategoryPicker(ProductsProvider provider) async {
    final result = await CategoryPickerSheet.show(
      context,
      currentSelectionId: provider.categoryFilter,
    );
    if (result == null || !mounted) return;
    setState(() => _selectedCategoryName = result.categoryName);
    provider.setCategoryFilter(result.categoryId);
  }

  /// Compose (`section header`, `product rows...`) entries.
  ///
  /// Section headers are only meaningful when the *full* result set is
  /// already on-screen (small shop, single page). Once the list is
  /// paginated, a category's products can span pages and the header
  /// would repeat (or worse, mislead). Same when a single category is
  /// already selected: the header is just redundant noise.
  ///
  /// In the no-grouping case the category lives on each tile, so the
  /// row still tells the user what bucket it belongs to.
  List<_ListItem> _buildItems(ProductsProvider provider) {
    final items = <_ListItem>[];
    final canGroup = provider.categoryFilter == null &&
        provider.search.isEmpty &&
        !provider.hasMore;

    if (!canGroup) {
      for (final p in provider.products) {
        items.add(_ListItem.product(p));
      }
      return items;
    }

    final buckets = <String, List<Product>>{};
    for (final p in provider.products) {
      final group = p.category?.name ?? AppStrings.uncategorised;
      buckets.putIfAbsent(group, () => []).add(p);
    }
    final groupNames = buckets.keys.toList()
      ..sort((a, b) {
        if (a == AppStrings.uncategorised) return 1;
        if (b == AppStrings.uncategorised) return -1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });

    for (final name in groupNames) {
      items.add(_ListItem.header(name));
      for (final p in buckets[name]!) {
        items.add(_ListItem.product(p));
      }
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProductsProvider>();
    final hasFilter = provider.categoryFilter != null ||
        provider.lowStockOnly ||
        provider.outOfStockOnly;
    final isSearching = provider.search.isNotEmpty;
    final items = _buildItems(provider);
    // Hoisted out of the itemBuilder so we don't re-scan the whole
    // list for every row.
    final hasHeaders = items.any((e) => e.isHeader);
    final showCategoryOnRow =
        !hasHeaders && provider.categoryFilter == null;

    return Scaffold(
      appBar: AppBar(
        leading: const ShellMenuButton(),
        title: const Text(AppStrings.navProducts),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: AppStrings.addProduct,
            onPressed: _openAddProduct,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              AppSizes.md,
              AppSizes.lg,
              0,
            ),
            child: AppSearchBar(
              hint: AppStrings.searchProducts,
              controller: _searchController,
              onChanged: provider.setSearch,
              trailing: _ScanAction(onTap: _openScanner),
            ),
          ),
          AppFilterStrip(
            children: [
              AppFilterPill(
                label: AppStrings.filterAll,
                selected: !hasFilter,
                onTap: () {
                  if (provider.lowStockOnly) {
                    provider.setLowStockOnly(false);
                  }
                  if (provider.outOfStockOnly) {
                    provider.setOutOfStockOnly(false);
                  }
                  if (provider.categoryFilter != null) {
                    setState(() => _selectedCategoryName = null);
                    provider.setCategoryFilter(null);
                  }
                },
              ),
              AppFilterPill(
                label: AppStrings.lowStock,
                icon: Icons.warning_amber_rounded,
                selected: provider.lowStockOnly,
                accent: AppColors.warning,
                onTap: () => provider.setLowStockOnly(!provider.lowStockOnly),
              ),
              AppFilterPill(
                label: AppStrings.outOfStock,
                icon: Icons.remove_circle_outline_rounded,
                selected: provider.outOfStockOnly,
                accent: AppColors.error,
                onTap: () =>
                    provider.setOutOfStockOnly(!provider.outOfStockOnly),
              ),
              // One picker chip replaces the per-category pill list.
              // Stays a single fixed-width affordance regardless of
              // how many categories the shop has — the searchable
              // bottom sheet handles 10 or 10,000 the same way.
              AppFilterPill(
                label: provider.categoryFilter == null
                    ? AppStrings.categoryPickerLabel
                    : (_selectedCategoryName ?? AppStrings.categoryPickerLabel),
                icon: Icons.folder_outlined,
                trailingIcon: Icons.expand_more_rounded,
                selected: provider.categoryFilter != null,
                onTap: () => _openCategoryPicker(provider),
              ),
            ],
          ),
          Expanded(
            child: provider.isLoading && provider.products.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && provider.products.isEmpty
                    ? EmptyState.line(
                        kind: LineArt.warning,
                        title: AppStrings.error,
                        action: AppButton.secondary(
                          label: AppStrings.retry,
                          onPressed: () => provider.loadProducts(),
                        ),
                      )
                    : provider.products.isEmpty
                        ? () {
                            // Low-stock or out-of-stock with zero
                            // results is good news, not "no matches" —
                            // show a positive confirmation instead of
                            // the generic empty-search state.
                            final isAllStockedUp =
                                (provider.lowStockOnly ||
                                        provider.outOfStockOnly) &&
                                    provider.categoryFilter == null &&
                                    !isSearching;
                            return EmptyState.line(
                              kind: LineArt.boxes,
                              title: isAllStockedUp
                                  ? AppStrings.allStockedUpTitle
                                  : (hasFilter || isSearching)
                                      ? AppStrings.noMatches
                                      : AppStrings.noProducts,
                              subtitle: isAllStockedUp
                                  ? AppStrings.allStockedUpHint
                                  : (hasFilter || isSearching)
                                      ? AppStrings.noMatchesHint
                                      : AppStrings.noProductsHint,
                              action: (hasFilter || isSearching)
                                  ? null
                                  : AppButton.primary(
                                      label: AppStrings.addProduct,
                                      icon: Icons.add_rounded,
                                      onPressed: _openAddProduct,
                                    ),
                            );
                          }()
                        : RefreshIndicator(
                            onRefresh: () => provider.loadProducts(),
                            color: AppColors.black,
                            backgroundColor: AppColors.white,
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSizes.sm,
                              ),
                              itemCount: items.length +
                                  (provider.hasMore ? 1 : 0),
                              separatorBuilder: (context, index) {
                                // No divider before a section header
                                // (the header carries enough vertical
                                // space on its own).
                                if (index + 1 >= items.length) {
                                  return const AppDivider();
                                }
                                final next = items[index + 1];
                                if (next.isHeader) {
                                  return const SizedBox.shrink();
                                }
                                return const AppDivider();
                              },
                              itemBuilder: (context, index) {
                                if (index >= items.length) {
                                  _scheduleLoadMore();
                                  return const Padding(
                                    padding: EdgeInsets.all(AppSizes.lg),
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final item = items[index];
                                return item.map(
                                  header: (label) => _CategoryHeader(
                                    label: label,
                                    first: index == 0,
                                  ),
                                  product: (p) => ProductListTile(
                                    product: p,
                                    showCategory: showCategoryOnRow,
                                    onTap: () => _openProductDetail(p),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Discriminated union for items rendered in the products list.
class _ListItem {
  const _ListItem._(this._label, this._product);
  factory _ListItem.header(String label) => _ListItem._(label, null);
  factory _ListItem.product(Product p) => _ListItem._(null, p);

  final String? _label;
  final Product? _product;

  bool get isHeader => _label != null;

  T map<T>({
    required T Function(String label) header,
    required T Function(Product product) product,
  }) {
    if (_label != null) return header(_label);
    return product(_product!);
  }
}

/// Subtle section divider between groups of products. Echoes the
/// section-header eyebrows used elsewhere in the app (dashboard,
/// settings) so the visual language stays consistent.
class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label, required this.first});
  final String label;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSizes.lg,
        first ? AppSizes.sm : AppSizes.lg,
        AppSizes.lg,
        AppSizes.xs,
      ),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

/// Trailing scan icon for the search bar. Compact, hairline-divided
/// from the input so it reads as a peer affordance without breaking
/// the search bar's silhouette.
class _ScanAction extends StatelessWidget {
  const _ScanAction({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 1,
          height: AppSizes.iconLg,
          color: AppColors.hairline,
        ),
        const SizedBox(width: AppSizes.xs),
        InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.all(AppSizes.xs),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: AppSizes.iconMd,
              color: AppColors.black,
            ),
          ),
        ),
      ],
    );
  }
}
