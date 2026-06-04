import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/product_detail_page.dart';
import 'package:shopxy/features/products/presentation/widgets/product_list_tile.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/constants/app_strings.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';

/// Drill-down view from CategoriesPage. Loads the products for a single
/// category directly (own state — not coupled to the global
/// ProductsProvider) so the merchant tab's filter state isn't mutated
/// when the user just wants to browse a bucket.
class CategoryProductsPage extends StatefulWidget {
  const CategoryProductsPage({super.key, required this.category});

  final Category category;

  @override
  State<CategoryProductsPage> createState() => _CategoryProductsPageState();
}

class _CategoryProductsPageState extends State<CategoryProductsPage> {
  List<Product> _products = const [];
  int _total = 0;
  bool _isLoading = true;
  String? _error;

  // Pagination — load more on scroll-to-end.
  static const _pageSize = 20;
  int _page = 1;
  bool _hasMore = true;
  bool _loadingMore = false;

  // Local search inside the category.
  final _searchCtrl = TextEditingController();
  String _search = '';

  final ScrollController _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _load({bool loadMore = false}) async {
    if (loadMore) {
      if (_loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
      });
    }

    try {
      final ds = context.read<ProductsRemoteDataSource>();
      final result = await ds.getProducts(
        categoryId: widget.category.id,
        search: _search.isEmpty ? null : _search,
        page: loadMore ? _page + 1 : 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        if (loadMore) {
          _products = [..._products, ...result.products];
          _page += 1;
        } else {
          _products = result.products;
          _page = 1;
        }
        _total = result.total;
        _hasMore = _products.length < result.total;
        _isLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
        _loadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _load(loadMore: true);
    }
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value.trim());
    // Debounce-light: rely on user pausing — kick a load on every change
    // but the network call is cheap and the user expects responsiveness.
    _load();
  }

  void _openProduct(Product p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailPage(productId: p.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(widget.category.name),
      ),
      body: _isLoading && _products.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _products.isEmpty
              ? AppErrorView(onRetry: _load)
              : RefreshIndicator(
                  onRefresh: () => _load(),
                  color: AppColors.black,
                  backgroundColor: AppColors.white,
                  child: CustomScrollView(
                    controller: _scrollCtrl,
                    slivers: [
                      SliverToBoxAdapter(
                        child: _Header(
                          category: widget.category,
                          totalProducts: _total,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            AppSizes.lg,
                            0,
                            AppSizes.lg,
                            AppSizes.md,
                          ),
                          child: _SearchField(
                            controller: _searchCtrl,
                            onChanged: _onSearchChanged,
                          ),
                        ),
                      ),
                      if (_products.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: EmptyState.line(
                            kind: LineArt.productTag,
                            title: _search.isEmpty
                                ? 'No products in this category'
                                : 'No products match "$_search"',
                            subtitle: _search.isEmpty
                                ? 'Assign products to "${widget.category.name}" from the product editor.'
                                : 'Try a shorter or different search.',
                          ),
                        )
                      else
                        SliverList.separated(
                          itemCount: _products.length,
                          separatorBuilder: (_, _) => const AppDivider.flush(),
                          itemBuilder: (_, i) => ProductListTile(
                            product: _products[i],
                            onTap: () => _openProduct(_products[i]),
                          ),
                        ),
                      if (_loadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                        ),
                      const SliverToBoxAdapter(
                        child: SizedBox(height: AppSizes.huge),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.category, required this.totalProducts});
  final Category category;
  final int totalProducts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = NumberFormat.decimalPattern('en_IN');
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        shape: AppShapes.squircle(AppSizes.radiusMd),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.accentTealSoft, AppColors.heroPanel],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: AppSizes.fabSize,
            height: AppSizes.fabSize,
            decoration: ShapeDecoration(
              color: AppColors.white,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: Icon(
              resolveCategoryIcon(category.iconName),
              color: AppColors.accentTeal,
              size: AppSizes.iconLg,
            ),
          ),
          const SizedBox(width: AppSizes.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (category.description != null &&
                    category.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    category.description!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.muted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: AppSizes.sm),
                Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: AppSizes.iconSm,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      '${fmt.format(totalProducts)} '
                      '${totalProducts == 1 ? 'product' : 'products'}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: AppShapes.squircle(
        AppSizes.radiusFull,
        side: const BorderSide(color: AppColors.hairline),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search ${AppStrings.navProducts.toLowerCase()}',
          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.subtle),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.subtle,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSizes.md,
            horizontal: AppSizes.md,
          ),
        ),
      ),
    );
  }
}
