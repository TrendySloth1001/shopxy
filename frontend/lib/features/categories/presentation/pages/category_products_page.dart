import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/haptics/scroll_boundary_haptics.dart';
import 'package:shopxy/features/categories/domain/entities/category.dart';
import 'package:shopxy/features/categories/presentation/widgets/category_icon_catalog.dart';
import 'package:shopxy/features/products/data/datasources/products_remote_data_source.dart';
import 'package:shopxy/features/products/domain/entities/product.dart';
import 'package:shopxy/features/products/presentation/pages/product_detail_page.dart';
import 'package:shopxy/features/products/presentation/widgets/product_list_tile.dart';
import 'package:shopxy/l10n/app_localizations.dart';
import 'package:shopxy/shared/constants/app_sizes.dart';
import 'package:shopxy/shared/illustrations/line_illustrations.dart';
import 'package:shopxy/shared/theme/app_colors.dart';
import 'package:shopxy/shared/theme/app_shapes.dart';
import 'package:shopxy/shared/widgets/app_divider.dart';
import 'package:shopxy/shared/widgets/app_error_view.dart';
import 'package:shopxy/shared/widgets/app_shimmer.dart';
import 'package:shopxy/shared/widgets/empty_state.dart';
import 'package:shopxy/shared/widgets/floating_app_bar.dart';
import 'package:shopxy/shared/utils/error_text.dart';
import 'package:shopxy/shared/constants/app_durations.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/shared/widgets/app_search_bar.dart';

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
  Timer? _searchDebounce;

  final ScrollController _scrollCtrl = ScrollController();
  late final ScrollBoundaryHaptics _scrollHaptics;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _scrollHaptics = ScrollBoundaryHaptics(_scrollCtrl);
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _scrollHaptics.dispose();
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
        _error = friendlyError(e);
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
    // Debounce the reload — same pattern as OrdersInboxPage, so typing
    // "sol" hits the backend once instead of once per keystroke.
    _searchDebounce?.cancel();
    _searchDebounce = Timer(AppDurations.searchDebounce, () {
      if (!mounted) return;
      _load();
    });
  }

  void _openProduct(Product p) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductDetailPage(productId: p.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: AppColors.canvas,
      appBar: FloatingAppBar(title: widget.category.name),
      body: _isLoading && _products.isEmpty
          ? const _CategoryProductsSkeleton()
          : _error != null && _products.isEmpty
          ? AppErrorView(onRetry: _load)
          : RefreshIndicator(
              onRefresh: () => _load(),
              color: AppColors.black,
              backgroundColor: AppColors.surface,
              child: CustomScrollView(
                controller: _scrollCtrl,
                slivers: [
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: FloatingAppBar.contentTopInset(context),
                    ),
                  ),
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
                            ? l10n.categoriesProductsEmptyTitle
                            : l10n.categoriesProductsNoMatchTitle(_search),
                        subtitle: _search.isEmpty
                            ? l10n.categoriesProductsEmptySubtitle(
                                widget.category.name,
                              )
                            : l10n.categoriesProductsNoMatchSubtitle,
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
    final l10n = AppLocalizations.of(context);
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
        gradient: LinearGradient(
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
              color: AppColors.inverseSurface,
              shape: AppShapes.squircle(AppSizes.radiusMd),
            ),
            alignment: Alignment.center,
            child: AppIcon(
              resolveCategoryIcon(category.iconName),
              color: AppColors.onInverse,
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
                    AppIcon(
                      AppIcons.inventory2Outlined,
                      size: AppSizes.iconSm,
                      color: AppColors.muted,
                    ),
                    const SizedBox(width: AppSizes.xs),
                    Text(
                      '${fmt.format(totalProducts)} '
                      '${totalProducts == 1 ? l10n.categoriesProductUnit : l10n.categoriesProductsUnit}',
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

// ---------------------------------------------------------------------------
// Skeleton widgets
// ---------------------------------------------------------------------------

/// Full-page skeleton that mirrors the real layout while [_isLoading] is true.
class _CategoryProductsSkeleton extends StatelessWidget {
  const _CategoryProductsSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        // Header card skeleton
        const SliverToBoxAdapter(child: _HeaderSkeleton()),
        // Search bar placeholder
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.lg,
              0,
              AppSizes.lg,
              AppSizes.md,
            ),
            child: AppShimmerBox(
              width: double.infinity,
              height: 44,
              radius: AppSizes.radiusFull,
            ),
          ),
        ),
        // Product list tile skeletons
        SliverList.separated(
          itemCount: 6,
          separatorBuilder: (context, index) => const AppDivider.flush(),
          itemBuilder: (context, index) => const _ProductTileSkeleton(),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSizes.huge)),
      ],
    );
  }
}

/// Mirrors the [_Header] card: icon box + three text lines.
class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSizes.lg,
        AppSizes.md,
        AppSizes.lg,
        AppSizes.md,
      ),
      padding: const EdgeInsets.all(AppSizes.lg),
      decoration: ShapeDecoration(
        color: AppColors.canvas,
        shape: AppShapes.squircle(AppSizes.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon box
          AppShimmerBox(
            width: AppSizes.fabSize,
            height: AppSizes.fabSize,
            radius: AppSizes.radiusMd,
          ),
          const SizedBox(width: AppSizes.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category name
                const AppShimmerLine(widthFactor: 0.55, height: 18),
                const SizedBox(height: AppSizes.sm),
                // Description line 1
                const AppShimmerLine(widthFactor: 0.9, height: 13),
                const SizedBox(height: AppSizes.xs),
                // Description line 2
                const AppShimmerLine(widthFactor: 0.7, height: 13),
                const SizedBox(height: AppSizes.sm),
                // Product count chip
                const AppShimmerLine(widthFactor: 0.35, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors one [ProductListTile]: image thumbnail + name/shop/rating/price lines.
class _ProductTileSkeleton extends StatelessWidget {
  const _ProductTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.lg,
        vertical: AppSizes.md,
      ),
      child: Row(
        children: [
          // Product thumbnail
          AppShimmerBox(width: 56, height: 56, radius: AppSizes.radiusSm),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product name
                const AppShimmerLine(widthFactor: 0.65, height: 14),
                const SizedBox(height: AppSizes.xs),
                // Shop / subtitle
                const AppShimmerLine(widthFactor: 0.45, height: 12),
                const SizedBox(height: AppSizes.xs),
                // Rating + price row
                Row(
                  children: [
                    const AppShimmerLine(widthFactor: 0.25, height: 12),
                    const SizedBox(width: AppSizes.sm),
                    const AppShimmerLine(widthFactor: 0.2, height: 12),
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

// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AppSearchBar(
      hint: l10n.categoriesSearchProductsHint,
      controller: controller,
      onChanged: onChanged,
      // The page debounces its own reload (_searchDebounce).
      debounce: Duration.zero,
    );
  }
}
